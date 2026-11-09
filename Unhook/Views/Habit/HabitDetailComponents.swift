import SwiftUI

// Small building blocks shared by the views on a habit's page (hero, recovery timeline, milestones).

/// A slim progress bar lit with the dawn gradient, brightest at its leading tip.
struct HabitDetailProgressBar: View {
    var fraction: Double
    var height: CGFloat = 6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let fill = LinearGradient(
        colors: [Palette.ember, Palette.amber, Palette.sun],
        startPoint: .leading,
        endPoint: .trailing
    )

    private var clampedFraction: CGFloat {
        guard fraction.isFinite else { return 0 }
        return CGFloat(min(max(fraction, 0), 1))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(Self.fill)
                    // Never narrower than a dot, so a fresh start still shows a spark of light.
                    .frame(width: max(height, proxy.size.width * clampedFraction))
                    .shadow(color: Palette.amber.opacity(0.5), radius: 6)
            }
        }
        .frame(height: height)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: clampedFraction)
        .accessibilityHidden(true)
    }
}

/// The round marker for a step on a habit's timelines: glowing dawn gold once reached, outlined in amber
/// while it's up next, and dim until then.
struct HabitDetailNode: View {
    enum Status {
        case reached, next, upcoming
    }

    let systemImage: String
    let status: Status
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
            Circle()
                .strokeBorder(strokeColor, lineWidth: status == .next ? 1.5 : 1)
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(symbolColor)
        }
        .frame(width: size, height: size)
        .shadow(color: status == .reached ? Palette.amber.opacity(0.55) : .clear, radius: 9)
        .accessibilityHidden(true)
    }

    private var fill: AnyShapeStyle {
        switch status {
        case .reached: AnyShapeStyle(Brand.gradient)
        case .next: AnyShapeStyle(Palette.amber.opacity(0.16))
        case .upcoming: AnyShapeStyle(Color.white.opacity(0.05))
        }
    }

    private var strokeColor: Color {
        switch status {
        case .reached: Color.white.opacity(0.35)
        case .next: Palette.amber
        case .upcoming: Palette.hairline
        }
    }

    private var symbolColor: Color {
        switch status {
        case .reached: Palette.inkText
        case .next: Palette.amber
        case .upcoming: Palette.textTertiary
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        HabitDetailProgressBar(fraction: 0.62)
        HStack(spacing: 16) {
            HabitDetailNode(systemImage: "heart.fill", status: .reached)
            HabitDetailNode(systemImage: "lungs.fill", status: .next)
            HabitDetailNode(systemImage: "lock.fill", status: .upcoming)
        }
    }
    .padding(24)
    .background(DawnBackground())
}
