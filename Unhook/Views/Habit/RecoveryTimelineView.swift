import SwiftUI

/// "What's happening in your body and mind": the habit's recovery steps measured against its current streak,
/// drawn as a vertical timeline that lights up in dawn colors as steps are reached.
/// Embedded in the habit detail scroll view.
struct RecoveryTimelineView: View {
    let habit: Habit

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    /// Steps shown before the "Show all" toggle.
    private static let collapsedCount = 4

    private var steps: [RecoveryStep] {
        RecoveryTimeline.steps(for: habit.presetID)
    }

    var body: some View {
        Card(title: "Recovery timeline", systemImage: "heart.text.square.fill", tint: Palette.rose) {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                content(steps: steps, elapsed: habit.stats(at: timeline.date).currentStreak)
            }
        }
    }

    private func content(steps: [RecoveryStep], elapsed: TimeInterval) -> some View {
        let progress = RecoveryTimeline.progress(elapsed: elapsed, steps: steps)
        return VStack(alignment: .leading, spacing: 16) {
            if let next = progress.next {
                NextRecoveryStepView(
                    step: next,
                    remaining: next.offset - elapsed,
                    fraction: progress.fractionToNext
                )
            } else {
                RecoveryCompleteView()
            }
            Text("\(progress.reached) of \(steps.count) steps reached")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            stepList(steps: steps, elapsed: elapsed, next: progress.next, fractionToNext: progress.fractionToNext)
            footer
        }
    }

    private func stepList(
        steps: [RecoveryStep],
        elapsed: TimeInterval,
        next: RecoveryStep?,
        fractionToNext: Double
    ) -> some View {
        let visible = isExpanded ? steps : Array(steps.prefix(Self.collapsedCount))
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, step in
                RecoveryStepRow(
                    step: step,
                    status: status(of: step, elapsed: elapsed, next: next),
                    lineFill: lineFill(below: index, in: visible, elapsed: elapsed, next: next, fractionToNext: fractionToNext)
                )
            }
            if steps.count > Self.collapsedCount {
                expandButton(total: steps.count)
            }
        }
    }

    private func status(of step: RecoveryStep, elapsed: TimeInterval, next: RecoveryStep?) -> HabitDetailNode.Status {
        if step.offset <= elapsed { return .reached }
        if step == next { return .next }
        return .upcoming
    }

    /// How much of the line from a step down to the following one is lit: all of it once the following step is
    /// reached, the progress toward it while it's up next, none before that. Nil for the last visible step.
    private func lineFill(
        below index: Int,
        in visible: [RecoveryStep],
        elapsed: TimeInterval,
        next: RecoveryStep?,
        fractionToNext: Double
    ) -> Double? {
        guard index + 1 < visible.count else { return nil }
        let following = visible[index + 1]
        if following.offset <= elapsed { return 1 }
        if following == next { return fractionToNext }
        return 0
    }

    private func expandButton(total: Int) -> some View {
        Button {
            Haptics.selection()
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                if isExpanded {
                    Text("Show less")
                } else {
                    Text("Show all \(total) steps")
                }
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.amber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Palette.amber.opacity(0.1), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let note = RecoveryTimeline.sourceNote(for: habit.presetID) {
                Text(note)
            }
            Text("Everyone is different. This is general information, not medical advice. Check with a doctor before making medical decisions.")
        }
        .font(.caption)
        .foregroundStyle(Palette.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The highlighted step the user is working toward, with a live countdown.
private struct NextRecoveryStepView: View {
    let step: RecoveryStep
    let remaining: TimeInterval
    let fraction: Double

    @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: step.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.inkText)
                    .frame(width: iconSize, height: iconSize)
                    .background(Brand.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Palette.amber.opacity(0.45), radius: 10, y: 2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Up next")
                        .microLabel(Palette.amber)
                    Text(step.title)
                        .font(.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                    Text(step.detail)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HabitDetailProgressBar(fraction: fraction, height: 8)
            HStack {
                Text("\(DurationFormatter.compact(remaining)) to go")
                    .monospacedDigit()
                Spacer()
                // Rounded down so it never reads 100% before the step is actually reached.
                Text(fraction, format: .percent.precision(.fractionLength(0)).rounded(rule: .down))
                    .monospacedDigit()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.amber.opacity(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Palette.amber.opacity(0.28), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Shown once every step on the timeline has been reached.
private struct RecoveryCompleteView: View {
    var body: some View {
        Label {
            Text("You've reached every step on this timeline. Your progress keeps building from here.")
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.sun)
        }
        .font(.subheadline.weight(.semibold))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.amber.opacity(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Palette.amber.opacity(0.28), lineWidth: 1)
        )
    }
}

/// One step on the timeline: a node on the rail, the line down to the next step, and the step's text.
private struct RecoveryStepRow: View {
    let step: RecoveryStep
    let status: HabitDetailNode.Status
    /// How much of the line below this step is lit (0...1), or nil when no line follows it.
    let lineFill: Double?

    @ScaledMetric(relativeTo: .subheadline) private var nodeSize: CGFloat = 34

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            rail
            details
                .padding(.bottom, lineFill == nil ? 4 : 20)
            Spacer(minLength: 0)
            if status == .next {
                Chip(text: Text("Next"), tint: Palette.amber)
                    .accessibilityHidden(true)
            }
        }
        // Lets the rail's line stretch to the full height of the step's text.
        .fixedSize(horizontal: false, vertical: true)
        .opacity(status == .upcoming ? 0.8 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityValue(statusDescription)
    }

    private var rail: some View {
        VStack(spacing: 4) {
            HabitDetailNode(systemImage: step.symbol, status: status, size: nodeSize)
            if let lineFill {
                RecoveryRailSegment(fill: lineFill)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.bottom, 4)
            }
        }
        .frame(width: nodeSize)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(RecoveryTimeline.offsetLabel(step.offset))
                .microLabel(status == .upcoming ? Palette.textTertiary : Palette.amber)
            Text(step.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(status == .upcoming ? Palette.textSecondary : Palette.textPrimary)
            Text(step.detail)
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    private var statusDescription: Text {
        switch status {
        case .reached: Text("Reached")
        case .next: Text("Up next")
        case .upcoming: Text("Upcoming")
        }
    }
}

/// A piece of the timeline's rail: lit with the dawn gradient from the top down to `fill`, dim below it.
private struct RecoveryRailSegment: View {
    let fill: Double

    var body: some View {
        let lit = fill.isFinite ? min(max(fill, 0), 1) : 0
        Capsule()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Palette.amber, location: 0),
                        .init(color: Palette.ember, location: lit),
                        .init(color: Color.white.opacity(0.12), location: lit),
                        .init(color: Color.white.opacity(0.12), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: lit > 0 ? Palette.amber.opacity(0.4) : .clear, radius: 4)
    }
}

#Preview {
    ScrollView {
        RecoveryTimelineView(habit: PreviewData.sampleHabit)
            .padding()
    }
    .dawnScreenBackground(glow: 0.4)
    .previewEnvironment()
}
