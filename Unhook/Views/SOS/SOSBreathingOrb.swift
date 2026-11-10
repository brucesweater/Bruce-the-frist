import SwiftUI

/// The SOS centerpiece: an orb of dawn light that grows as you breathe in, rests while you hold, and shrinks as you
/// breathe out, with the seconds left in the current step in the middle. With Reduce Motion it keeps its size and
/// brightens and warms instead.
struct SOSBreathingOrb: View {
    /// 0 with empty lungs, 1 at the top of the breath. Change it inside an animation that lasts the whole step.
    var breath: Double
    /// Seconds left in the current step.
    var secondsLeft: Int
    /// The orb's size at the top of the breath.
    var diameter: CGFloat = 280

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The orb's size with empty lungs, relative to a full breath.
    static let restingScale: CGFloat = 0.56

    private var level: Double { min(max(breath, 0), 1) }

    private var sphereScale: CGFloat {
        reduceMotion ? 0.82 : Self.restingScale + (1 - Self.restingScale) * CGFloat(level)
    }

    var body: some View {
        ZStack {
            halo
            if !reduceMotion {
                guideRing
            }
            sphere
                .scaleEffect(sphereScale)
                .opacity(reduceMotion ? 0.55 + 0.45 * level : 1)
            countdown
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }

    /// Soft rose and violet light around the orb that swells with the breath.
    private var halo: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Palette.rose.opacity(0.5), Palette.violet.opacity(0.22), .clear],
                    center: .center,
                    startRadius: diameter * 0.18,
                    endRadius: diameter * 0.72
                )
            )
            .frame(width: diameter * 1.5, height: diameter * 1.5)
            .blur(radius: 24)
            .scaleEffect(reduceMotion ? 1 : 0.8 + 0.3 * CGFloat(level))
            .opacity(0.45 + 0.55 * level)
            .allowsHitTesting(false)
    }

    /// A faint ring that marks how far a full breath goes.
    private var guideRing: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [Palette.rose, Palette.amber, Palette.violet, Palette.rose],
                    center: .center
                ),
                lineWidth: 1.5
            )
            .opacity(0.32)
            .frame(width: diameter, height: diameter)
    }

    private var sphere: some View {
        ZStack {
            // Rose in the middle, violet at the rim.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Palette.rose, Palette.violet],
                        center: UnitPoint(x: 0.5, y: 0.42),
                        startRadius: 0,
                        endRadius: diameter * 0.52
                    )
                )
            // A warm sun core that glows brighter as the breath comes in.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Palette.sun, Palette.amber.opacity(0.85), Palette.amber.opacity(0)],
                        center: UnitPoint(x: 0.5, y: 0.42),
                        startRadius: 0,
                        endRadius: diameter * 0.42
                    )
                )
                .opacity(0.35 + 0.65 * level)
            // Soft highlight on the upper left, so it reads as a sphere.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.28), .clear],
                        center: UnitPoint(x: 0.32, y: 0.24),
                        startRadius: 0,
                        endRadius: diameter * 0.45
                    )
                )
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.5), Color.white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: Palette.rose.opacity(0.5), radius: 30)
    }

    private var countdown: some View {
        Text(secondsLeft, format: .number)
            .font(.display(diameter * 0.22, weight: .semibold))
            .foregroundStyle(Palette.inkText.opacity(0.82))
            .monospacedDigit()
            .contentTransition(reduceMotion ? .opacity : .numericText(countsDown: true))
    }
}

/// One dot per breathing cycle: done, current (long and gold) and still to come.
struct SOSCycleDots: View {
    /// The current cycle, starting at 1.
    let current: Int
    let total: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                Capsule()
                    .fill(color(for: index + 1))
                    .frame(width: index + 1 == current ? 24 : 8, height: 8)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Cycle \(current) of \(total)"))
    }

    private func color(for cycle: Int) -> Color {
        if cycle == current { return Palette.amber }
        return cycle < current ? Palette.amber.opacity(0.55) : Color.white.opacity(0.2)
    }
}

/// "Remember why" with one of the user's reasons, in a glass card. Changing `index` crossfades to the next reason.
struct SOSReasonCard: View {
    let reason: String
    /// Identifies the reason on screen, so a new one fades in instead of replacing the text in place.
    let index: Int

    var body: some View {
        VStack(spacing: 10) {
            Label {
                Text("REMEMBER WHY")
            } icon: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Palette.rose)
            }
            .microLabel(Palette.textSecondary)

            // A ZStack, so the old and new reason overlap while they crossfade.
            ZStack {
                Text(reason)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(index)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .glassSurface(cornerRadius: 24)
        .accessibilityElement(children: .combine)
    }
}
