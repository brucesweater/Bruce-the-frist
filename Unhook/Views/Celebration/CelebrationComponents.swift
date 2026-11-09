import SwiftUI

/// The celebration sky: night, with the dawn already breaking at the horizon.
struct CelebrationBackground: View {
    /// Dark enough for long content to fade into under the buttons.
    static let fadeColor = Palette.ink

    var body: some View {
        DawnBackground(glow: 0.4)
    }
}

/// The habit's emoji on a glowing dawn orb, with the milestone's symbol pinned to the corner and a sunrise
/// bursting behind it. The burst rises and the orb springs in when `isVisible` turns true.
struct CelebrationBadge: View {
    let emoji: String
    let symbol: String
    /// How far the orb has turned to sunrise (0...1): bigger milestones glow warmer.
    let dawn: Double
    let isVisible: Bool

    @ScaledMetric(relativeTo: .largeTitle) private var scaledOrbSize: CGFloat = 148

    init(emoji: String, symbol: String, dawn: Double, isVisible: Bool) {
        self.emoji = emoji
        self.symbol = symbol
        self.dawn = dawn
        self.isVisible = isVisible
    }

    private var orbSize: CGFloat { min(scaledOrbSize, 200) }

    var body: some View {
        ZStack {
            CelebrationSunBurst(size: orbSize * 2.6)
                .offset(y: isVisible ? 0 : orbSize * 0.6)
                .opacity(isVisible ? 1 : 0)
            orb
                .scaleEffect(isVisible ? 1 : 0.3)
                .rotationEffect(.degrees(isVisible ? 0 : -14))
                .opacity(isVisible ? 1 : 0)
        }
        .frame(width: orbSize * 1.3, height: orbSize * 1.3)
        .accessibilityHidden(true)
    }

    private var orb: some View {
        ZStack {
            DawnOrb(progress: dawn, size: orbSize)
            Text(emoji)
                .font(.system(size: orbSize * 0.44))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
            Image(systemName: symbol)
                .font(.system(size: orbSize * 0.15, weight: .bold))
                .foregroundStyle(Palette.inkText)
                .frame(width: orbSize * 0.36, height: orbSize * 0.36)
                .background(Brand.gradient, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 2))
                .shadow(color: Palette.amber.opacity(0.55), radius: 10)
                .offset(x: orbSize * 0.36, y: orbSize * 0.36)
        }
    }
}

/// A sunrise: a warm glow with soft rays that turn slowly (and stay still with Reduce Motion).
struct CelebrationSunBurst: View {
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(size: CGFloat) {
        self.size = size
    }

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                CelebrationRays()
                    .rotationEffect(.degrees(reduceMotion ? 0 : Self.rotation(at: context.date)))
            }
            Circle()
                .fill(RadialGradient(
                    colors: [Palette.sun.opacity(0.5), Palette.amber.opacity(0.26), Palette.ember.opacity(0.1), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.34
                ))
                .frame(width: size * 0.68, height: size * 0.68)
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// One slow turn every two minutes.
    private static func rotation(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 120) / 120 * 360
    }
}

/// Soft sun rays fanning out from the center. Has no inputs, so it's drawn once and then only rotated.
private struct CelebrationRays: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = Double(min(size.width, size.height)) / 2
            let count = 16
            let halfWidth = Double.pi / Double(count) * 0.32
            let shading = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [Palette.sun.opacity(0.26), Palette.amber.opacity(0.1), .clear]),
                center: center,
                startRadius: 0,
                endRadius: CGFloat(radius)
            )
            for index in 0..<count {
                let angle = Double(index) / Double(count) * 2 * Double.pi
                var ray = Path()
                ray.move(to: center)
                ray.addLine(to: Self.point(from: center, angle: angle - halfWidth, distance: radius))
                ray.addLine(to: Self.point(from: center, angle: angle + halfWidth, distance: radius))
                ray.closeSubpath()
                context.fill(ray, with: shading)
            }
        }
    }

    private static func point(from center: CGPoint, angle: Double, distance: Double) -> CGPoint {
        CGPoint(x: Double(center.x) + cos(angle) * distance, y: Double(center.y) + sin(angle) * distance)
    }
}

/// One figure on the celebration screen, e.g. "$84" "Money saved", in its role color.
struct CelebrationStat: Identifiable {
    let id: String
    let value: String
    /// Already localized.
    let title: String
    let systemImage: String
    /// The figure's color everywhere in the app (money is mint, time is sky…).
    let tint: Color
}

/// Figures side by side, stacked instead at accessibility text sizes.
struct CelebrationStatsRow: View {
    let stats: [CelebrationStat]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(stats: [CelebrationStat]) {
        self.stats = stats
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            ForEach(stats) { stat in
                CelebrationStatTile(stat: stat)
            }
        }
    }
}

private struct CelebrationStatTile: View {
    let stat: CelebrationStat

    var body: some View {
        VStack(spacing: 8) {
            IconBadge(systemImage: stat.systemImage, tint: stat.tint, size: 34)
            Text(stat.value)
                .font(.display(26))
                .foregroundStyle(stat.tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(stat.title)
                .microLabel(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .glassSurface(cornerRadius: 22, tint: stat.tint)
        .accessibilityElement(children: .combine)
    }
}
