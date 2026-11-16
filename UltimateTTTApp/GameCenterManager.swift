import Foundation
import GameKit
import SwiftUI
import UIKit
import UltimateTTTCore

@MainActor
final class GameCenterManager: NSObject, ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentMatch: GKTurnBasedMatch?
    @Published private(set) var game: UltimateGame?
    @Published private(set) var localMark: Mark?
    @Published private(set) var isMyTurn = false
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private var didConfigureAuthentication = false
    private var showMatchmakerWhenReady = false
    let achievements = AchievementTracker()

    var isOnline: Bool { currentMatch != nil }
    var canPlay: Bool {
        isOnline && isAuthenticated && isMyTurn && !isSubmitting
            && game?.result == .ongoing && currentMatch?.status == .open
    }

    func configureAuthentication() {
        guard !didConfigureAuthentication else { return }
        didConfigureAuthentication = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let controller {
                    Self.visibleController()?.present(controller, animated: true)
                    return
                }
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if self.isAuthenticated {
                    GKLocalPlayer.local.register(self)
                    await self.achievements.reportProgress()
                    if self.showMatchmakerWhenReady {
                        self.showMatchmakerWhenReady = false
                        self.presentMatchmaker()
                    }
                } else if let error {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func playOnline() {
        guard GKLocalPlayer.local.isAuthenticated else {
            showMatchmakerWhenReady = true
            configureAuthentication()
            if didConfigureAuthentication && !isAuthenticated {
                errorMessage = "Sign in to Game Center on this device, then try again."
            }
            return
        }
        presentMatchmaker()
    }

    func showAchievements() {
        guard isAuthenticated else {
            errorMessage = "Sign in to Game Center to see achievements."
            return
        }
        let controller = GKGameCenterViewController(state: .achievements)
        controller.gameCenterDelegate = self
        Self.visibleController()?.present(controller, animated: true)
    }

    func closeOnlineBoard() {
        currentMatch = nil
        game = nil
        localMark = nil
        isMyTurn = false
        // The match stays in Game Center and can be resumed later.
    }

    func refresh() {
        guard let id = currentMatch?.matchID else { return }
        Task { await loadMatch(id: id) }
    }

    func submitMove(board: Int, cell: Int) {
        guard canPlay, let id = currentMatch?.matchID, let visibleGame = game else { return }
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                // Reload immediately before submitting so we never overwrite a newer turn.
                let match = try await GKTurnBasedMatch.load(withID: id)
                let payload = try TurnBasedPayload.decoded(from: try await match.loadMatchData())
                guard payload.game == visibleGame,
                      match.status == .open,
                      match.currentParticipant?.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID else {
                    await loadMatch(id: id)
                    errorMessage = "This match changed. Its latest moves have been loaded."
                    return
                }
                guard let ourIndex = match.participants.firstIndex(where: {
                    $0.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID
                }), payload.game.currentPlayer == (ourIndex == 0 ? Mark.x : Mark.o) else {
                    errorMessage = "It isn't your turn yet."
                    return
                }

                var next = payload.game
                guard next.play(Move(board: board, cell: cell)) else { return }
                let updated = try TurnBasedPayload(game: next).encoded()
                guard updated.count <= match.matchDataMaximumSize else {
                    errorMessage = "The game is too large to send to Game Center."
                    return
                }
                if next.result.isFinished {
                    for (index, participant) in match.participants.enumerated() {
                        switch next.result {
                        case .won(let mark):
                            let participantMark: Mark = index == 0 ? .x : .o
                            participant.matchOutcome = participantMark == mark ? .won : .lost
                        case .drawn:
                            participant.matchOutcome = .tied
                        case .ongoing: break
                        }
                    }
                    try await match.endMatchInTurn(withMatch: updated)
                } else {
                    let opponent = match.participants[1 - ourIndex]
                    match.message = "Your turn in Ultimate Tic Tac Toe!"
                    try await match.endTurn(
                        withNextParticipants: [opponent],
                        turnTimeout: GKTurnTimeoutDefault,
                        match: updated
                    )
                }
                await loadMatch(id: id)
            } catch {
                errorMessage = error.localizedDescription
                await loadMatch(id: id)
            }
        }
    }

    private func presentMatchmaker() {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        guard !GKLocalPlayer.local.isMultiplayerGamingRestricted else {
            errorMessage = "This Game Center account can't join multiplayer games."
            return
        }
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        let controller = GKTurnBasedMatchmakerViewController(matchRequest: request)
        controller.turnBasedMatchmakerDelegate = self
        Self.visibleController()?.present(controller, animated: true)
    }

    private func loadMatch(id: String) async {
        do {
            let match = try await GKTurnBasedMatch.load(withID: id)
            let payload = try TurnBasedPayload.decoded(from: try await match.loadMatchData())
            guard match.participants.count == 2,
                  let index = match.participants.firstIndex(where: {
                      $0.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID
                  }) else {
                errorMessage = "Waiting for Game Center to finish matching players."
                return
            }
            currentMatch = match
            game = payload.game
            localMark = index == 0 ? .x : .o
            isMyTurn = match.status == .open &&
                match.currentParticipant?.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID
            if case .won(let winner) = payload.game.result,
               localMark == winner, match.status == .ended {
                achievements.recordOnlineWin(matchID: match.matchID)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func visibleController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        var controller = windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}

extension GameCenterManager: GKTurnBasedMatchmakerViewControllerDelegate {
    func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController) {
        viewController.dismiss(animated: true)
    }

    func turnBasedMatchmakerViewController(
        _ viewController: GKTurnBasedMatchmakerViewController,
        didFailWithError error: any Error
    ) {
        viewController.dismiss(animated: true)
        errorMessage = error.localizedDescription
    }

    func turnBasedMatchmakerViewController(
        _ viewController: GKTurnBasedMatchmakerViewController,
        didFind match: GKTurnBasedMatch
    ) {
        viewController.dismiss(animated: true)
        Task { await loadMatch(id: match.matchID) }
    }
}

extension GameCenterManager: GKTurnBasedEventListener {
    nonisolated func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if didBecomeActive || self.currentMatch?.matchID == match.matchID {
                await self.loadMatch(id: match.matchID)
            }
        }
    }

    nonisolated func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.currentMatch?.matchID == match.matchID {
                await self.loadMatch(id: match.matchID)
            }
        }
    }
}

extension GameCenterManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
