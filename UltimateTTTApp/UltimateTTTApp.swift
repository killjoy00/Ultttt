import SwiftUI

@main
struct UltimateTTTApp: App {
    @StateObject private var session = GameSession()

    var body: some Scene {
        WindowGroup {
            ContentView(session: session)
        }
    }
}
