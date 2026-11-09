import SwiftUI

/// A habit's live streak on the Today screen: a ring toward the next milestone around the habit's emoji, the streak
/// in rounded numerals and how long until the next milestone.
struct HabitCard: View {
    let habit: Habit

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            TodayHabitCardContent(habit: habit, elapsed: habit.stats(at: timeline.date).currentStreak)
        }
    }
}

private struct TodayHabitCardContent: View {
    let habit: Habit
    let elapsed: TimeInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let duration = DurationFormatter.detailed(elapsed)
        HStack(spacing: 16) {
            ring
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                Text(duration)
                    .font(.display(24))
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: duration)
                nextMilestone
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 24)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var ring: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [habit.theme.accent.opacity(0.24), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 30
                ))
            ProgressRing(progress: Milestone.progress(toward: elapsed), colors: habit.theme.colors, lineWidth: 6)
                .shadow(color: habit.theme.accent.opacity(0.45), radius: 6)
            Text(habit.emoji)
                .font(.system(size: 28))
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var nextMilestone: some View {
        if let next = Milestone.next(after: elapsed) {
            Label {
                Text("\(DurationFormatter.compact(next.seconds - elapsed)) to \(next.title)")
            } icon: {
                Image(systemName: next.symbol)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(habit.theme.accent)
            .lineLimit(1)
        } else {
            Label("Every milestone unlocked", systemImage: "crown.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(habit.theme.accent)
        }
    }
}
