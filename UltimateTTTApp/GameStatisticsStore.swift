import Foundation
import GameKit
import SwiftUI
import UltimateTTTCore

@MainActor
final class GameStatisticsStore: ObservableObject {
    @Published private(set) var history: MatchHistory

    private let storageKey = "ultttt.match-history.v1"
    static let onlineWinsLeaderboardID = "com.killjoy00.ultttt.online_wins"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(MatchHistory.self, from: data) {
            history = saved
        } else {
            history = MatchHistory()
        }
    }

    func recordSolo(id: UUID, result: GameResult, difficulty: Difficulty, moves: Int) {
        let outcome: PlayedOutcome
        switch result {
        case .won(.x): outcome = .win
        case .won(.o): outcome = .loss
        case .drawn: outcome = .draw
        case .ongoing: return
        }
        record(FinishedMatch(
            id: "solo:\(id.uuidString)", mode: .solo,
            difficulty: difficulty, outcome: outcome, moves: moves
        ))
    }

    func reopenSolo(id: UUID) {
        var next = history
        guard next.remove(id: "solo:\(id.uuidString)") else { return }
        history = next
        save()
    }

    func hasOnlineResult(matchID: String) -> Bool {
        history.contains(id: "online:\(matchID)")
    }

    func recordOnline(matchID: String, outcome: PlayedOutcome, moves: Int) {
        record(FinishedMatch(
            id: "online:\(matchID)", mode: .online,
            difficulty: nil, outcome: outcome, moves: moves
        ))
    }

    private func record(_ match: FinishedMatch) {
        var next = history
        guard next.record(match) else { return }
        history = next
        save()
        if match.mode == .online && match.outcome == .win {
            syncOnlineLeaderboard()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// The App Store Connect leaderboard is cumulative and uses the player's
    /// local total. Failed submissions remain pending for future sync.
    func syncOnlineLeaderboard() {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let wins = history.summary(for: .online).wins
        guard wins > 0 else { return }
        let syncKey = "ultttt.leaderboard.online-wins.\(GKLocalPlayer.local.gamePlayerID)"
        guard UserDefaults.standard.integer(forKey: syncKey) < wins else { return }

        Task {
            do {
                try await GKLeaderboard.submitScore(
                    wins, context: 0, player: GKLocalPlayer.local,
                    leaderboardIDs: [Self.onlineWinsLeaderboardID]
                )
                UserDefaults.standard.set(wins, forKey: syncKey)
            } catch {
                // The leaderboard may not yet be configured in App Store Connect,
                // or the user may be offline. Keep the total for a later retry.
                print("Leaderboard sync deferred: \(error.localizedDescription)")
            }
        }
    }
}
