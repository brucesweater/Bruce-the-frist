import SwiftUI

/// The live streak at the top of a habit's page: a dawn orb that brightens as the next milestone gets closer,
/// the day count in big rounded numerals, a ticking clock and a slim bar toward the next milestone.
struct HabitHeroView: View {
    let habit: Habit

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            content(elapsed: habit.stats(at: timeline.date).currentStreak)
        }
    }

    private func content(elapsed: TimeInterval) -> some View {
        let parts = DurationFormatter.parts(elapsed)
        let next = Milestone.next(after: elapsed)
        let progress = Milestone.progress(toward: elapsed)
        return VStack(spacing: 0) {
            DawnOrb(progress: progress, size: 124)
                .padding(.bottom, -8)
            Text("Free from \(habit.name)")
                .microLabel(Palette.amber)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            dayCount(parts.days)
            clock(parts)
                .padding(.top, 8)
            milestoneProgress(elapsed: elapsed, next: next, progress: progress)
                .padding(.top, 22)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Free from \(habit.name) for \(parts.days) days, \(parts.hours) hours and \(parts.minutes) minutes"))
        .accessibilityValue(milestoneDescription(elapsed: elapsed, next: next))
    }

    private var tickAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.3)
    }

    // MARK: Day count

    private func dayCount(_ days: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(days, format: .number)
                .font(.display(92, weight: .heavy))
                .foregroundStyle(Self.numeralGradient)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .shadow(color: Palette.amber.opacity(0.28), radius: 18)
            Text(days == 1 ? "day" : "days")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
        }
        // The line box of a 92 pt font is much taller than its digits; tighten it so the hero stays compact.
        .padding(.vertical, -6)
        .animation(tickAnimation, value: days)
    }

    private static let numeralGradient = LinearGradient(
        colors: [Color.white, Palette.sun],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: Clock

    private func clock(_ parts: DurationFormatter.Parts) -> some View {
        HStack(spacing: 8) {
            HeroTimePill(value: parts.hours, unit: "hrs")
            HeroTimePill(value: parts.minutes, unit: "min")
            HeroTimePill(value: parts.seconds, unit: "sec")
        }
        .animation(tickAnimation, value: parts)
    }

    // MARK: Next milestone

    @ViewBuilder
    private func milestoneProgress(elapsed: TimeInterval, next: Milestone?, progress: Double) -> some View {
        if let next {
            VStack(spacing: 10) {
                HabitDetailProgressBar(fraction: progress)
                HStack(spacing: 6) {
                    Image(systemName: next.symbol)
                        .foregroundStyle(Palette.amber)
                    Text("\(DurationFormatter.compact(next.seconds - elapsed)) until \(next.title)")
                        .foregroundStyle(Palette.textSecondary)
                        .monospacedDigit()
                }
                .font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 12)
        } else {
            Label("Every milestone unlocked. Legend.", systemImage: "crown.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.sun)
        }
    }

    private func milestoneDescription(elapsed: TimeInterval, next: Milestone?) -> Text {
        guard let next else { return Text("Every milestone unlocked. Legend.") }
        return Text("\(DurationFormatter.compact(next.seconds - elapsed)) until \(next.title)")
    }
}

/// Hours, minutes or seconds of the live streak in a small glass pill.
private struct HeroTimePill: View {
    let value: Int
    let unit: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(verbatim: String(format: "%02d", value))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(unit)
                .microLabel(Palette.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Palette.surface.opacity(0.62), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }
}

#Preview {
    ScrollView {
        HabitHeroView(habit: PreviewData.sampleHabit)
            .padding()
    }
    .dawnScreenBackground(glow: 0.4)
    .previewEnvironment()
}
