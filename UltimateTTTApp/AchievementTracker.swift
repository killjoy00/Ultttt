import Foundation
import GameKit

/// App Store Connect achievement IDs must match these values exactly.
@MainActor
final class AchievementTracker {
    private enum ID {
        static let firstWin = "com.killjoy00.ultttt.first_win"
        static let fiveWins = "com.killjoy00.ultttt.five_wins"
        static let tenWins = "com.killjoy00.ultttt.ten_wins"
        static let firstOnline = "com.killjoy00.ultttt.first_online_win"
        static let online25 = "com.killjoy00.ultttt.twenty_five_online_wins"
    }

    private let soloCountKey = "ultttt-achievement-solo-wins"
    private let onlineMatchIDsKey = "ultttt-achievement-online-won-match-ids"

    func recordSoloWin() {
        UserDefaults.standard.set(
            UserDefaults.standard.integer(forKey: soloCountKey) + 1,
            forKey: soloCountKey
        )
        Task { await reportProgress() }
    }

    func recordOnlineWin(matchID: String) {
        var recorded = Set(UserDefaults.standard.stringArray(forKey: onlineMatchIDsKey) ?? [])
        guard recorded.insert(matchID).inserted else { return }
        UserDefaults.standard.set(Array(recorded).sorted(), forKey: onlineMatchIDsKey)
        Task { await reportProgress() }
    }

    func reportProgress() async {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let solo = UserDefaults.standard.integer(forKey: soloCountKey)
        let online = UserDefaults.standard.stringArray(forKey: onlineMatchIDsKey)?.count ?? 0
        let milestones: [(String, Int, Int)] = [
            (ID.firstWin, solo, 1),
            (ID.fiveWins, solo, 5),
            (ID.tenWins, solo, 10),
            (ID.firstOnline, online, 1),
            (ID.online25, online, 25)
        ]
        let achievements = milestones.compactMap { id, count, goal -> GKAchievement? in
            guard count > 0 else { return nil }
            let value = GKAchievement(identifier: id)
            value.percentComplete = Double(min(100, count * 100 / goal))
            value.showsCompletionBanner = true
            return value
        }
        guard !achievements.isEmpty else { return }
        do {
            try await GKAchievement.report(achievements)
        } catch {
            // Progress remains locally saved and will be retried on next auth.
            print("Game Center achievement sync failed: \(error.localizedDescription)")
        }
    }
}
