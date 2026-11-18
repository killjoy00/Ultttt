import SwiftUI

@main
struct UltimateTTTApp: App {
    @StateObject private var session = GameSession()
    @StateObject private var gameCenter = GameCenterManager()
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var ads = AdManager()
    @StateObject private var statistics = GameStatisticsStore()
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.system.rawValue
    @AppStorage("ultttt.first-launch-tutorial.acknowledged.v1")
    private var hasChosenOnboarding = false
    @State private var showingFirstLaunchTutorial = false
    @State private var servicesStarted = false

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
            .fullScreenCover(isPresented: $showingFirstLaunchTutorial) {
                TutorialSheet(isFirstLaunch: true) {
                    // Skip and completion are equally valid choices.
                    // The game underneath is untouched by practice moves.
                    hasChosenOnboarding = true
                    showingFirstLaunchTutorial = false
                    Task { await startServicesIfNeeded() }
                }
            }
            .task {
                if !hasChosenOnboarding {
                    // Offer the tour before Game Center sign-in or ad consent
                    // can interrupt the player's first impression.
                    showingFirstLaunchTutorial = true
                } else {
                    await startServicesIfNeeded()
                }
            }
    }

    @MainActor
    private func startServicesIfNeeded() async {
        guard !servicesStarted else { return }
        servicesStarted = true
        gameCenter.configureAuthentication()
        // StoreKit must be checked before any ad SDK or consent prompt.
        await purchases.prepare()
        if !purchases.adsRemoved {
            await ads.prepare()
        }
    }

    #if DEBUG
    private static var storeScreenshotScenario: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-UltimateStoreScreenshot"),
              args.indices.contains(index + 1) else { return nil }
        let option = args[index + 1]
        return ["board", "contrast", "setup", "tutorial", "statistics", "settings", "iap"].contains(option)
            ? option : nil
    }
    #endif
}
