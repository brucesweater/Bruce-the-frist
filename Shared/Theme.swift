import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Unhook's color tokens. Everything sits on a deep night sky; warm dawn colors mark progress and actions.
/// Shared with the widget extension, so keep this file to plain SwiftUI.
enum Palette {
    // Night: backgrounds and surfaces
    static let ink = Color(hex: 0x05061A)
    static let night = Color(hex: 0x0B0E2C)
    static let dusk = Color(hex: 0x1B1650)
    static let plum = Color(hex: 0x2C1B57)
    static let surface = Color(hex: 0x161A42)
    static let surfaceRaised = Color(hex: 0x1F2456)
    static let hairline = Color.white.opacity(0.09)

    // Dawn: accents
    static let sun = Color(hex: 0xFFE08A)
    static let amber = Color(hex: 0xFFB547)
    static let ember = Color(hex: 0xFF7A45)
    static let rose = Color(hex: 0xFF5C8A)
    static let violet = Color(hex: 0x9B7BFF)
    static let sky = Color(hex: 0x7CB8FF)
    static let mint = Color(hex: 0x5EE3B8)

    // Text on the night background
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.45)
    /// Dark text for bright gold buttons and chips.
    static let inkText = Color(hex: 0x1B1206)

    // One color per meaning, used everywhere the same number appears
    static let money = mint
    static let time = sky
    static let units = amber
    static let cravings = violet
    static let streak = ember
    static let celebrate = sun

    /// Three sky colors (top, middle, horizon) that move from deep night at 0 to a golden sunrise at 1.
    static func skyColors(progress: Double) -> [Color] {
        let p = min(max(progress, 0), 1)
        let stops: [(Double, [UInt32])] = [
            (0.0, [0x0B0E2C, 0x221C5E, 0x3B2670]),
            (0.45, [0x18205E, 0x5B3A9C, 0xE0607E]),
            (0.75, [0x26357F, 0xC2588A, 0xFF9A5C]),
            (1.0, [0x35509C, 0xFF8A5C, 0xFFE29A]),
        ]
        var lower = stops[0]
        var upper = stops[stops.count - 1]
        for index in 0..<(stops.count - 1) where p >= stops[index].0 && p <= stops[index + 1].0 {
            lower = stops[index]
            upper = stops[index + 1]
            break
        }
        let span = upper.0 - lower.0
        let t = span > 0 ? (p - lower.0) / span : 0
        return (0..<3).map { mix(lower.1[$0], upper.1[$0], t) }
    }

    /// Blends two hex colors (works on iOS 17, unlike Color.mix).
    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> Color {
        func channel(_ value: UInt32, _ shift: UInt32) -> Double { Double((value >> shift) & 0xFF) / 255 }
        let t = min(max(t, 0), 1)
        return Color(
            .sRGB,
            red: channel(a, 16) + (channel(b, 16) - channel(a, 16)) * t,
            green: channel(a, 8) + (channel(b, 8) - channel(a, 8)) * t,
            blue: channel(a, 0) + (channel(b, 0) - channel(a, 0)) * t,
            opacity: 1
        )
    }
}

enum Brand {
    /// The warm dawn pair: primary actions and highlights.
    static let colors = [Palette.amber, Palette.ember]
    static let gradient = LinearGradient(
        colors: [Palette.sun, Palette.amber, Palette.ember],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Headline gradient that matches the App Store art: pale gold on top, warm orange below.
    static let dawn = LinearGradient(
        colors: [Palette.sun, Palette.amber, Palette.ember],
        startPoint: .top,
        endPoint: .bottom
    )
    /// Urgent but warm, for SOS.
    static let sos = LinearGradient(colors: [Palette.rose, Palette.ember], startPoint: .leading, endPoint: .trailing)
    /// The deep night sky behind every screen.
    static let night = LinearGradient(
        colors: [Palette.ink, Palette.night, Palette.dusk, Palette.plum],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// The color personality of a habit. Stored on the model by raw value.
enum HabitTheme: String, CaseIterable, Identifiable {
    case ocean, sunset, forest, grape, fire, candy, mint, gold, midnight

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var colors: [Color] {
        switch self {
        case .ocean: [Color(hex: 0x5AB4FF), Color(hex: 0x3B5BFF)]
        case .sunset: [Color(hex: 0xFFC15E), Color(hex: 0xFF6A4D)]
        case .forest: [Color(hex: 0x5EE3B8), Color(hex: 0x1C9E86)]
        case .grape: [Color(hex: 0xB59BFF), Color(hex: 0x6B4BEA)]
        case .fire: [Color(hex: 0xFF8A4C), Color(hex: 0xF23A5E)]
        case .candy: [Color(hex: 0xFF86C0), Color(hex: 0x9A6BFF)]
        case .mint: [Color(hex: 0x8AF2D2), Color(hex: 0x27B395)]
        case .gold: [Color(hex: 0xFFE08A), Color(hex: 0xF5A524)]
        case .midnight: [Color(hex: 0x8E9BFF), Color(hex: 0x3D44A8)]
        }
    }

    var accent: Color { colors[0] }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
