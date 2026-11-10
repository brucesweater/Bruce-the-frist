import SwiftUI

extension Rank {
    /// How far along the night-to-day path this rank is, from 0 (Midnight) to 1 (Legend).
    var skyProgress: Double {
        let top = max(Rank.all.count - 1, 1)
        return min(max(Double(level - 1) / Double(top), 0), 1)
    }
}

/// The rank's symbol on a small sky that brightens from night to sunrise as the rank grows, ringed in dawn gold,
/// with a soft glow that breathes unless Reduce Motion is on.
struct RankMedallion: View {
    let rank: Rank
    var size: CGFloat = 64
    var glows = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = Palette.skyColors(progress: rank.skyProgress)
        ZStack {
            Circle()
                .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            Circle()
                .fill(RadialGradient(
                    colors: [Color.white.opacity(0.28), .clear],
                    center: UnitPoint(x: 0.3, y: 0.22),
                    startRadius: 0,
                    endRadius: size * 0.6
                ))
            Image(systemName: rank.symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [Color.white, Palette.sun], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            Circle()
                .strokeBorder(Brand.gradient, lineWidth: max(1.5, size * 0.035))
        }
        .frame(width: size, height: size)
        // The halo is wider than the medallion. It sits behind it, so it can't stretch the circles to its own size.
        .background {
            if glows {
                halo
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var halo: some View {
        let glow = Circle()
            .fill(RadialGradient(
                colors: [Palette.amber.opacity(0.55), .clear],
                center: .center,
                startRadius: size * 0.3,
                endRadius: size * 0.85
            ))
            .frame(width: size * 1.7, height: size * 1.7)
            .allowsHitTesting(false)
        if reduceMotion {
            glow
        } else {
            glow.phaseAnimator([false, true]) { view, phase in
                view
                    .scaleEffect(phase ? 1.06 : 0.92)
                    .opacity(phase ? 1 : 0.65)
            } animation: { _ in
                .easeInOut(duration: 2.8)
            }
        }
    }
}

/// A dawn-gold progress bar on a faint track.
struct XPProgressBar: View {
    var progress: Double
    var height: CGFloat = 8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)
            let width = clamped > 0 ? max(height, proxy.size.width * clamped) : 0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(Brand.gradient)
                    .frame(width: width)
                    .shadow(color: Palette.amber.opacity(0.5), radius: height * 0.6)
            }
        }
        .frame(height: height)
        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8), value: progress)
        .accessibilityHidden(true)
    }
}

/// A round check that fills with dawn gold when done. Animate changes with `withAnimation` at the call site.
struct EngagementCheckmark: View {
    let isDone: Bool
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Palette.textTertiary, lineWidth: 2)
                .opacity(isDone ? 0 : 1)
            Circle()
                .fill(Brand.gradient)
                .scaleEffect(isDone ? 1 : 0.4)
                .opacity(isDone ? 1 : 0)
                .shadow(color: Palette.amber.opacity(isDone ? 0.5 : 0), radius: 6)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.45, weight: .heavy))
                .foregroundStyle(Palette.inkText)
                .scaleEffect(isDone ? 1 : 0.2)
                .opacity(isDone ? 1 : 0)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A small filled capsule for compact actions inside cards ("Start", "SOS", "Mark done").
struct EngagementCapsuleLabel: View {
    let text: Text
    var gradient: LinearGradient = Brand.gradient
    var foreground: Color = Palette.inkText
    var font: Font = .subheadline.weight(.bold)

    var body: some View {
        text
            .font(font)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(gradient, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
    }
}
