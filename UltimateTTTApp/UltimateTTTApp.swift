import SwiftUI

@main
struct UltimateTTTApp: App {
    @StateObject private var session = GameSession()
    @StateObject private var gameCenter = GameCenterManager()
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var ads = AdManager()
    @StateObject private var statistics = GameStatisticsStore()
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.system.rawValue

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let scenario = Self.storeScreenshotScenario {
                AppStoreScreenshotHost(scenario: scenario)
            } else {
                normalGame
            }
            #else
            normalGame
            #endif
        }
    }

    private var normalGame: some View {
        ContentView(
                session: session,
                gameCenter: gameCenter,
                purchases: purchases,
                ads: ads,
                statistics: statistics
            )
            .preferredColorScheme(AppearancePreference(rawValue: appearance)?.colorScheme)
            .task {
                gameCenter.configureAuthentication()
                // Check StoreKit before starting any ad SDK or requesting consent.
                await purchases.prepare()
                if !purchases.adsRemoved {
                    await ads.prepare()
                }
            }
    }

    #if DEBUG
    private static var storeScreenshotScenario: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-UltimateStoreScreenshot"),
              args.indices.contains(index + 1) else { return nil }
        let option = args[index + 1]
        return ["board", "setup", "tutorial", "statistics", "settings"].contains(option)
            ? option : nil
    }
    #endif
}
