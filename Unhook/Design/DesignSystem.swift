import SwiftUI

// Unhook's design system: a night sky that warms toward dawn, frosted glass surfaces, rounded display numerals,
// and one warm call-to-action color. Colors live in Shared/Theme.swift (`Palette`, `Brand`).

// MARK: - Typography

extension Font {
    /// Big rounded numerals for streaks, money and time.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Large screen titles drawn in the app's own header (not the navigation bar).
    static let screenTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    /// Section headings inside a screen.
    static let sectionTitle = Font.system(.title3, design: .rounded).weight(.bold)
    /// Card and row titles.
    static let cardTitle = Font.system(.headline, design: .rounded)
}

extension View {
    /// The small uppercase, tracked label that sits above a value ("MONEY SAVED").
    func microLabel(_ color: Color = Palette.textTertiary) -> some View {
        font(.caption2.weight(.bold))
            .tracking(1.1)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

// MARK: - Glass surfaces

/// A frosted, softly lit card surface on the night background.
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 24
    var tint: Color?
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Palette.surface.opacity(0.74))
                    if let tint {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(0.12))
                    }
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.07), .clear], startPoint: .top, endPoint: .center))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(highlighted ? 0.32 : 0.14), Color.white.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
    }
}

extension View {
    /// Frosted glass card styling: use for every container that sits on `DawnBackground`.
    func glassSurface(cornerRadius: CGFloat = 24, tint: Color? = nil, highlighted: Bool = false) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, tint: tint, highlighted: highlighted))
    }

    /// The app background for a scrolling screen or a Form/List (hides the system background).
    func dawnScreenBackground(glow: Double = 0.25) -> some View {
        scrollContentBackground(.hidden)
            .background(DawnBackground(glow: glow))
    }
}

// MARK: - Background

/// The deep night sky behind every screen, with soft aurora light and a few stars. `glow` raises a warm dawn
/// light from the bottom (0 = night, 1 = sunrise). Static, so it costs nothing while scrolling.
struct DawnBackground: View {
    var glow: Double = 0.25
    var showsStars = true

    var body: some View {
        ZStack {
            Brand.night
            RadialGradient(
                colors: [Palette.violet.opacity(0.32), .clear],
                center: UnitPoint(x: 0.08, y: -0.02),
                startRadius: 0,
                endRadius: 440
            )
            RadialGradient(
                colors: [Palette.rose.opacity(0.18 + 0.24 * glow), .clear],
                center: UnitPoint(x: 0.95, y: 1.05),
                startRadius: 0,
                endRadius: 520
            )
            RadialGradient(
                colors: [Palette.amber.opacity(0.08 + 0.3 * glow), .clear],
                center: UnitPoint(x: 0.45, y: 1.18),
                startRadius: 0,
                endRadius: 620
            )
            if showsStars {
                StarField(count: 70, maxHeightFraction: 0.65)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// A fixed scatter of small stars (the same every time, so screens don't flicker between renders).
struct StarField: View {
    var count = 70
    var maxHeightFraction = 0.7
    var seed: UInt64 = 0x5EED

    var body: some View {
        Canvas { context, size in
            var generator = SeededGenerator(seed: seed)
            for _ in 0..<count {
                let x = Double.random(in: 0...1, using: &generator) * size.width
                let y = Double.random(in: 0...maxHeightFraction, using: &generator) * size.height
                let radius = Double.random(in: 0.4...1.5, using: &generator)
                let alpha = Double.random(in: 0.2...0.85, using: &generator)
                let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A small deterministic random number generator (SplitMix64) for decorative layouts.
struct SeededGenerator: RandomNumberGenerator {
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

// MARK: - Headers

/// A section heading on the night background, with an optional tinted symbol and trailing note.
struct SectionHeader: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var tint: Color = Palette.amber
    var trailing: Text?

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.sectionTitle)
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 0)
            if let trailing {
                trailing
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A tinted square behind an SF Symbol, used at the start of cards and rows.
struct IconBadge: View {
    let systemImage: String
    var tint: Color = Palette.amber
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .strokeBorder(tint.opacity(0.25), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

/// A small rounded pill ("+20 XP", "Day 5 of 30").
struct Chip: View {
    let text: Text
    var tint: Color = Palette.amber
    var filled = false

    var body: some View {
        text
            .font(.caption.weight(.bold))
            .foregroundStyle(filled ? Palette.inkText : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.16)), in: Capsule())
    }
}

// MARK: - Dawn orb

/// The signature visual: a glowing sky sphere that turns from starry night to golden sunrise as `progress`
/// goes from 0 to 1. Breathes gently unless Reduce Motion is on.
struct DawnOrb: View {
    var progress: Double
    var size: CGFloat = 220
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        let colors = Palette.skyColors(progress: clamped)
        ZStack {
            glow(colors)
            sphere(colors)
            Circle()
                .strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.5), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.5
                )
                .frame(width: size, height: size)
        }
        .frame(width: size * 1.3, height: size * 1.3)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func glow(_ colors: [Color]) -> some View {
        let halo = Circle()
            .fill(RadialGradient(colors: [colors[2].opacity(0.6), .clear], center: .center, startRadius: size * 0.25, endRadius: size * 0.68))
            .frame(width: size * 1.3, height: size * 1.3)
            .blur(radius: 18)
        if animated && !reduceMotion {
            halo.phaseAnimator([false, true]) { view, phase in
                view
                    .scaleEffect(phase ? 1.06 : 0.96)
                    .opacity(phase ? 1 : 0.75)
            } animation: { _ in
                .easeInOut(duration: 3.2)
            }
        } else {
            halo
        }
    }

    private func sphere(_ colors: [Color]) -> some View {
        Circle()
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .overlay {
                StarField(count: 6 + Int((1 - clamped) * 26), maxHeightFraction: 0.6, seed: 0x0DB)
                    .opacity(1 - clamped * 0.9)
            }
            .overlay {
                // The sun, rising from below the horizon as progress grows.
                Circle()
                    .fill(RadialGradient(
                        colors: [Palette.sun.opacity(0.95), Palette.amber.opacity(0.55), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.4
                    ))
                    .frame(width: size * 0.82, height: size * 0.82)
                    .offset(y: size * (0.64 - 0.36 * clamped))
            }
            .overlay {
                // Soft highlight on the upper left, so it reads as a sphere.
                Circle()
                    .fill(RadialGradient(colors: [Color.white.opacity(0.22), .clear], center: UnitPoint(x: 0.3, y: 0.22), startRadius: 0, endRadius: size * 0.5))
            }
            .clipShape(Circle())
            .frame(width: size, height: size)
    }
}

// MARK: - Press feedback

/// A plain button style that dims and shrinks slightly while pressed. Use for tappable cards.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
