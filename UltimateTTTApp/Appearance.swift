import SwiftUI
import UIKit
import UltimateTTTCore

/// The app follows the device appearance until the player chooses otherwise.
enum AppearancePreference: String, CaseIterable {
    case system, light, dark

    static let storageKey = "ultttt.appearance"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Dynamic colors keep the game readable in both appearances, including sheets
/// and the 9x9 board, without maintaining a separate layout for each mode.
enum GameStyle {
    private static func adaptive(
        light: UInt32,
        dark: UInt32,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            let opacity = traits.userInterfaceStyle == .dark ? darkAlpha : lightAlpha
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: opacity
            )
        })
    }

    // Light: softly tinted off-white and darker teal/coral for contrast.
    // Dark: preserve the existing deep-navy and bright teal/coral identity.
    static let background = adaptive(light: 0xF5F8F9, dark: 0x0B121D)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x172132)
    static let board = adaptive(light: 0xDEE7E9, dark: 0x1A2638)
    static let tile = adaptive(light: 0xFCFDFD, dark: 0x253144)
    static let cell = adaptive(light: 0xE5EDEF, dark: 0x2E394A)
    static let text = adaptive(light: 0x172B34, dark: 0xF2F7FC)
    static let muted = adaptive(light: 0x526771, dark: 0xAABCCA)
    static let x = adaptive(light: 0x06716D, dark: 0x6EDFD8)
    static let o = adaptive(light: 0xAB482B, dark: 0xFFAE86)
    static let outline = adaptive(light: 0x163441, dark: 0xFFFFFF, lightAlpha: 0.15, darkAlpha: 0.105)
    static let shadow = adaptive(light: 0x1A2B33, dark: 0x000000, lightAlpha: 0.07, darkAlpha: 0.20)

    // Accent buttons use white type in light mode and navy type in dark mode.
    static let onAccent = adaptive(light: 0xFFFFFF, dark: 0x0B121D)

    static func color(for mark: Mark) -> Color { mark == .x ? x : o }
}
