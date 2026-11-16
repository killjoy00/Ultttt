import SwiftUI
import UltimateTTTCore

#if DEBUG
/// Actual SwiftUI views rendered by the shipping app. This replaces stylized
/// mockups that show invented online avatars, scores, or nonexistent controls.
/// The launch argument exists only in DEBUG; release builds cannot enter it.
@MainActor
struct AppStoreScreenshotHost: View {
    let scenario: String
    @StateObject private var session: GameSession
    @StateObject private var gameCenter = GameCenterManager()
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var ads = AdManager()
    @StateObject private var statistics: GameStatisticsStore

    init(scenario: String) {
        self.scenario = scenario
        let gameSession = GameSession()
        gameSession.prepareStoreScreenshot()
        _session = StateObject(wrappedValue: gameSession)

        let sampleStats = GameStatisticsStore()
        let sampleOutcomes: [(GameResult, Difficulty, Int)] = [
            (.won(.x), .medium, 37),
            (.won(.o), .hard, 42),
            (.won(.x), .easy, 29),
            (.drawn, .hard, 67),
            (.won(.x), .medium, 43)
        ]
        // The stats screen is a real app view with illustrative test fixtures.
        for (index, item) in sampleOutcomes.enumerated() {
            let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!
            sampleStats.recordSolo(id: id, result: item.0, difficulty: item.1, moves: item.2)
        }
        _statistics = StateObject(wrappedValue: sampleStats)
    }

    var body: some View {
        Group {
            switch scenario {
            case "setup":
                NewGameSheet(mode: .solo, difficulty: .medium) { _, _ in }
            case "tutorial":
                TutorialSheet()
            case "statistics":
                StatisticsSheet(statistics: statistics) {}
            case "settings":
                GameSettingsSheet()
            default:
                ContentView(
                    session: session, gameCenter: gameCenter,
                    purchases: purchases, ads: ads, statistics: statistics
                )
            }
        }
        .preferredColorScheme(scenario == "settings" ? .dark : .light)
    }
}
#endif
