import Foundation
import SwiftUI
import UIKit
import UltimateTTTCore

enum GameMode: String, Codable, CaseIterable, Identifiable {
    case solo, twoPlayer

    var id: String { rawValue }
    var label: String { self == .solo ? "Vs computer" : "Two players" }
}

struct MatchScores: Codable, Equatable {
    var xWins = 0
    var oWins = 0
    var draws = 0
}

@MainActor
final class GameSession: ObservableObject {
    @Published private(set) var game: UltimateGame
    @Published private(set) var mode: GameMode
    @Published private(set) var difficulty: Difficulty
    @Published private(set) var scores: MatchScores
    @Published private(set) var isThinking = false

    private let storageKey = "ultimate-ttt-session-v1"
    private var gameID = UUID()
    private var achievementCreditedForCurrentGame = false
    var onSoloWin: (() -> Void)?

    private struct SavedSession: Codable {
        let game: UltimateGame
        let mode: GameMode
        let difficulty: Difficulty
        let scores: MatchScores
        var creditedSoloWin: Bool? = nil
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(SavedSession.self, from: data) {
            game = saved.game
            mode = saved.mode
            difficulty = saved.difficulty
            scores = saved.scores
            achievementCreditedForCurrentGame = saved.creditedSoloWin ?? false
        } else {
            game = UltimateGame()
            mode = .solo
            difficulty = .medium
            scores = MatchScores()
        }
    }

    func startNewGame(mode: GameMode, difficulty: Difficulty) {
        gameID = UUID()
        isThinking = false
        achievementCreditedForCurrentGame = false
        self.mode = mode
        self.difficulty = difficulty
        game = UltimateGame()
        save()
    }

    func play(board: Int, cell: Int) {
        guard !isThinking, game.result == .ongoing else { return }
        if mode == .solo && game.currentPlayer == .o { return }
        var next = game
        guard next.play(Move(board: board, cell: cell)) else { return }
        game = next
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if game.result.isFinished { record(game.result, change: 1) }
        if mode == .solo, game.result == .won(.x), !achievementCreditedForCurrentGame {
            achievementCreditedForCurrentGame = true
            onSoloWin?()
        }
        save()
        resumeComputerTurn()
    }

    func resumeComputerTurn() {
        guard mode == .solo, !isThinking, game.result == .ongoing,
              game.currentPlayer == .o else { return }
        isThinking = true
        let scheduledID = gameID
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard self.gameID == scheduledID, self.isThinking,
                  self.mode == .solo, self.game.currentPlayer == .o,
                  self.game.result == .ongoing else { return }
            var next = self.game
            if let move = ComputerOpponent.chooseMove(in: next, difficulty: self.difficulty) {
                _ = next.play(move)
                self.game = next
                if next.result.isFinished { self.record(next.result, change: 1) }
            }
            self.isThinking = false
            self.save()
        }
    }

    func undoTurn() {
        guard !game.moves.isEmpty else { return }
        gameID = UUID() // Invalidate any pending computer turn.
        isThinking = false
        if game.result.isFinished { record(game.result, change: -1) }
        var next = game
        // In solo mode, go back to the last human decision.
        if mode == .solo && next.currentPlayer == .x && next.moves.count >= 2 {
            _ = next.undo()
            _ = next.undo()
        } else {
            _ = next.undo()
        }
        game = next
        save()
    }

    private func record(_ result: GameResult, change: Int) {
        switch result {
        case .won(.x): scores.xWins = max(0, scores.xWins + change)
        case .won(.o): scores.oWins = max(0, scores.oWins + change)
        case .drawn: scores.draws = max(0, scores.draws + change)
        case .ongoing: break
        }
    }

    private func save() {
        let saved = SavedSession(game: game, mode: mode, difficulty: difficulty, scores: scores,
                                 creditedSoloWin: achievementCreditedForCurrentGame)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
