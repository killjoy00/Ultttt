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
    }
}
