import SwiftUI

/// First screen: a dawn orb in a slow orbit of the habits people quit, the promise and one button.
struct OnboardingWelcomeStep: View {
    let onStart: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 40

    init(onStart: @escaping () -> Void) {
        self.onStart = onStart
    }

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 30) {
                        WelcomeHero()
                        headline
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            VStack(spacing: 14) {
                Button("Get started") {
                    Haptics.tap()
                    onStart()
                }
                .buttonStyle(PrimaryButtonStyle())

                Text("Free · Private · No account needed")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .frame(maxWidth: 560)
        }
    }

    private var headline: some View {
        VStack(spacing: 14) {
            Text("Break free from any habit")
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [Palette.textPrimary, Palette.sun], startPoint: .top, endPoint: .bottom)
                )
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Smoking, vaping, drinking, doomscrolling, sugar. Unhook helps you quit anything, one day at a time.")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
    }
}

/// The dawn orb at the center of a slow orbit of the habits people quit with Unhook. Still with Reduce Motion.
private struct WelcomeHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let emojis = ["🚬", "💨", "🍺", "📱", "🍭", "🎮"]
    private static let orbSize: CGFloat = 156
    private static let orbitRadius: Double = 128
    private static let bubbleSize: CGFloat = 50
    /// Seconds per orbit and per gentle bob. The loop is a multiple of both, so wrapping around is seamless.
    private static let orbitPeriod: Double = 80
    private static let bobPeriod: Double = 7
    private static let loopLength: Double = 560

    private static var extent: CGFloat {
        CGFloat(orbitRadius * 2) + bubbleSize + 12
    }

    var body: some View {
        ZStack {
            DawnOrb(progress: 0.15, size: Self.orbSize)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                orbit(time: reduceMotion ? 0 : Self.loopTime(at: context.date))
            }
        }
        .frame(width: Self.extent, height: Self.extent)
        .accessibilityHidden(true)
    }

    private func orbit(time: Double) -> some View {
        ZStack {
            ForEach(Array(Self.emojis.enumerated()), id: \.offset) { index, emoji in
                WelcomeEmojiBubble(emoji: emoji, size: Self.bubbleSize)
                    .offset(Self.position(index: index, time: time))
            }
        }
    }

    private static func loopTime(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: loopLength)
    }

    /// Evenly spaced around the orb, turning slowly, each one bobbing a little out of step with its neighbours.
    private static func position(index: Int, time: Double) -> CGSize {
        let start = Double(index) / Double(emojis.count)
        let angle = (start + time / orbitPeriod) * 2 * Double.pi - Double.pi / 2
        let bob = sin((time / bobPeriod + start) * 2 * Double.pi) * 4
        return CGSize(width: cos(angle) * orbitRadius, height: sin(angle) * orbitRadius + bob)
    }
}

/// One habit emoji in a small frosted bubble.
private struct WelcomeEmojiBubble: View {
    let emoji: String
    let size: CGFloat

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.52))
            .frame(width: size, height: size)
            .background(Palette.surface.opacity(0.78), in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

#Preview {
    ZStack {
        DawnBackground(glow: 0.1)
        OnboardingWelcomeStep {}
    }
    .environment(\.colorScheme, .dark)
    .previewEnvironment()
}
