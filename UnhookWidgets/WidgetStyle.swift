import SwiftUI
import WidgetKit

// The widget extension can't see the app's design system (Unhook/Design is compiled into the app only), so this file
// re-creates the few pieces the widgets need from SwiftUI and Shared/Theme.swift alone: the night sky with its dawn
// glow and stars, the dawn progress bar, rounded display numerals and micro labels.

extension Font {
    /// Big rounded numerals, like the app's display type.
    static func widgetNumeral(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    /// The small uppercase, tracked label that sits with a value ("DAYS FREE", "SAVED").
    func widgetMicroLabel(_ color: Color = Palette.textSecondary) -> some View {
        font(.caption2.weight(.bold))
            .tracking(1.1)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

/// The deep night sky behind the Home Screen widgets: ink fading to dusk, a soft violet aurora, a few tiny stars and a
/// warm glow rising from the bottom. `glow` (0...1) sets how strong the glow is, like the app's sky warming toward
/// sunrise; the stars fade a little as it brightens.
struct WidgetNightSky: View {
    var glow: Double = 0.3
    /// The glow's colors, from its warm core outward.
    var glowColors: [Color] = [Palette.amber, Palette.ember, Palette.rose]
    var starSeed: UInt64 = 0x5EED

    private var strength: Double { min(max(glow, 0), 1) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.ink, Palette.night, Palette.dusk], startPoint: .top, endPoint: .bottom)
            EllipticalGradient(
                colors: [Palette.violet.opacity(0.26), Palette.violet.opacity(0)],
                center: UnitPoint(x: 0.08, y: -0.12),
                startRadiusFraction: 0,
                endRadiusFraction: 0.8
            )
            EllipticalGradient(
                colors: glowStops,
                center: UnitPoint(x: 0.5, y: 1.2),
                startRadiusFraction: 0,
                endRadiusFraction: CGFloat(0.6 + 0.35 * strength)
            )
            WidgetStarField(seed: starSeed)
                .opacity(1 - 0.5 * strength)
        }
        .accessibilityHidden(true)
    }

    /// Each color a little fainter than the one before, fading to nothing at the edge.
    private var glowStops: [Color] {
        let peak = 0.18 + 0.47 * strength
        let count = Double(max(glowColors.count, 1))
        var stops: [Color] = []
        for (index, color) in glowColors.enumerated() {
            stops.append(color.opacity(peak * (1 - Double(index) / count)))
        }
        stops.append((glowColors.last ?? Palette.amber).opacity(0))
        return stops
    }
}

/// A fixed scatter of tiny stars in the upper part of the sky. Seeded, so every render looks the same.
struct WidgetStarField: View {
    var count = 16
    var seed: UInt64 = 0x5EED
    var maxHeightFraction: CGFloat = 0.6

    var body: some View {
        let stars = WidgetStar.scatter(count: count, seed: seed, maxHeightFraction: maxHeightFraction)
        ZStack {
            WidgetStarShape(stars: stars.filter { !$0.isBright })
                .fill(Color.white.opacity(0.35))
            WidgetStarShape(stars: stars.filter { $0.isBright })
                .fill(Color.white.opacity(0.85))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One star: its position as a fraction of the widget, and its radius in points.
private struct WidgetStar {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let isBright: Bool

    static func scatter(count: Int, seed: UInt64, maxHeightFraction: CGFloat) -> [WidgetStar] {
        var generator = WidgetRandom(seed: seed)
        let maxY = min(max(maxHeightFraction, 0.1), 1)
        var stars: [WidgetStar] = []
        for _ in 0..<max(count, 0) {
            let x = CGFloat.random(in: 0.03...0.97, using: &generator)
            let y = CGFloat.random(in: 0.03...maxY, using: &generator)
            let radius = CGFloat.random(in: 0.45...1.25, using: &generator)
            let isBright = Double.random(in: 0...1, using: &generator) > 0.7
            stars.append(WidgetStar(x: x, y: y, radius: radius, isBright: isBright))
        }
        return stars
    }
}

/// Small dots at the stars' positions, scaled to whatever size the widget is.
private struct WidgetStarShape: Shape {
    let stars: [WidgetStar]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for star in stars {
            path.addEllipse(in: CGRect(
                x: rect.minX + star.x * rect.width - star.radius,
                y: rect.minY + star.y * rect.height - star.radius,
                width: star.radius * 2,
                height: star.radius * 2
            ))
        }
        return path
    }
}

/// A small deterministic random number generator (SplitMix64) for the star layout.
private struct WidgetRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A slim progress bar filled with the dawn gradient (pale gold to ember), on a faint track.
struct WidgetDawnBar: View {
    var progress: Double
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            let filled = CGFloat(min(max(progress, 0), 1))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(LinearGradient(colors: [Palette.sun, Palette.amber, Palette.ember], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, proxy.size.width * filled))
                    .shadow(color: Palette.amber.opacity(0.5), radius: 4)
                    .widgetAccentable()
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
