import SwiftUI

/// Every streak checkpoint for a habit: unlocked ones glow in dawn colors with the day they were reached,
/// the next one is outlined, and the rest wait, dimmed, with the date they'll unlock.
struct MilestoneListView: View {
    let habit: Habit

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            content(elapsed: habit.stats(at: timeline.date).currentStreak)
        }
    }

    private func content(elapsed: TimeInterval) -> some View {
        let next = Milestone.next(after: elapsed)
        let unlockedCount = Milestone.all.filter { elapsed >= $0.seconds }.count
        return Card(title: "Milestones", systemImage: "flag.checkered", tint: Palette.amber) {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(unlockedCount) of \(Milestone.all.count) unlocked")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                VStack(spacing: 0) {
                    ForEach(Milestone.all) { milestone in
                        MilestoneRow(
                            milestone: milestone,
                            date: habit.streakStart.addingTimeInterval(milestone.seconds),
                            status: status(of: milestone, elapsed: elapsed, next: next)
                        )
                    }
                }
            }
        }
    }

    private func status(of milestone: Milestone, elapsed: TimeInterval, next: Milestone?) -> HabitDetailNode.Status {
        if elapsed >= milestone.seconds { return .reached }
        if milestone == next { return .next }
        return .upcoming
    }
}

private struct MilestoneRow: View {
    let milestone: Milestone
    let date: Date
    let status: HabitDetailNode.Status

    @ScaledMetric(relativeTo: .subheadline) private var nodeSize: CGFloat = 38

    var body: some View {
        HStack(spacing: 14) {
            HabitDetailNode(
                systemImage: status == .upcoming ? "lock.fill" : milestone.symbol,
                status: status,
                size: nodeSize
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(status == .upcoming ? Palette.textSecondary : Palette.textPrimary)
                caption
                    .font(.caption)
                    .foregroundStyle(status == .upcoming ? Palette.textTertiary : Palette.textSecondary)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
        .accessibilityValue(statusDescription)
    }

    private var caption: Text {
        switch status {
        case .reached:
            Text("Unlocked \(date.formatted(date: .abbreviated, time: .omitted))")
        case .next, .upcoming:
            Text(date.formatted(date: .abbreviated, time: .shortened))
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch status {
        case .reached:
            Image(systemName: "checkmark.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.amber)
                .shadow(color: Palette.amber.opacity(0.5), radius: 6)
                .accessibilityHidden(true)
        case .next:
            Chip(text: Text("Next"), tint: Palette.amber)
                .accessibilityHidden(true)
        case .upcoming:
            EmptyView()
        }
    }

    private var statusDescription: Text {
        switch status {
        case .reached: Text("Unlocked")
        case .next: Text("Up next")
        case .upcoming: Text("Locked")
        }
    }
}

#Preview {
    ScrollView {
        MilestoneListView(habit: PreviewData.sampleHabit)
            .padding()
    }
    .dawnScreenBackground(glow: 0.4)
    .previewEnvironment()
}
