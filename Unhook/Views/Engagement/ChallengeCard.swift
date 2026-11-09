import SwiftUI
import SwiftData

/// The 30-Day Reset on Today: an invitation before joining, then "Day 5 of 30" with today's step and a check button,
/// and a gold badge once all 30 steps are done.
struct ChallengeCard: View {
    @Query(sort: \ChallengeProgress.joinedAt) private var runs: [ChallengeProgress]
    @Environment(AppRouter.self) private var router

    init() {}

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            content(now: timeline.date)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("challengeCard")
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if let run = ResetChallenge.current(in: runs) {
            if ResetChallenge.isFinished(run) {
                ChallengeFinishedCardContent(run: run, onOpen: open)
            } else {
                ChallengeActiveCardContent(run: run, now: now, onOpen: open)
            }
        } else {
            ChallengeInviteCardContent(onStart: open)
        }
    }

    private func open() {
        Haptics.tap()
        router.showChallenge()
    }
}

private struct ChallengeInviteCardContent: View {
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    IconBadge(systemImage: "sunrise.fill", tint: Palette.amber, size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("30-Day Reset")
                            .font(.cardTitle)
                            .foregroundStyle(Palette.textPrimary)
                        Text("One small step a day for 30 days.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    Chip(text: Text("+\(XPRewards.perChallengeDay) XP a day"), tint: Palette.amber)
                    Spacer(minLength: 8)
                    EngagementCapsuleLabel(text: Text("Start"))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: 24, tint: Palette.amber)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Brand.gradient, lineWidth: 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens the 30-Day Reset"))
    }
}

private struct ChallengeActiveCardContent: View {
    let run: ChallengeProgress
    let now: Date
    let onOpen: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let day = ResetChallenge.currentDay(for: run, now: now)
        let doneCount = ResetChallenge.completedCount(in: run)
        let openEarlier = ResetChallenge.openEarlierDays(in: run, now: now).count
        VStack(alignment: .leading, spacing: 14) {
            headerButton
            HStack(spacing: 14) {
                Button(action: onOpen) {
                    HStack(spacing: 14) {
                        ring(day: day, doneCount: doneCount)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Day \(day) of \(ResetChallenge.length)")
                                .microLabel(Palette.amber)
                            Text(ResetChallenge.step(for: day).title)
                                .font(.cardTitle)
                                .foregroundStyle(Palette.textPrimary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            statusLine(doneCount: doneCount, openEarlier: openEarlier)
                                .font(.caption)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityElement(children: .combine)
                .accessibilityHint(Text("Opens the 30-Day Reset"))

                checkButton(day: day, isDone: run.completedDays.contains(day))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 24, tint: Palette.amber)
    }

    private var headerButton: some View {
        Button(action: onOpen) {
            HStack(spacing: 6) {
                Image(systemName: "sunrise.fill")
                    .foregroundStyle(Palette.amber)
                Text("30-Day Reset")
                    .font(.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: 8)
                Text("See all")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("See all 30 days of the Reset"))
    }

    private func statusLine(doneCount: Int, openEarlier: Int) -> Text {
        if openEarlier > 0 {
            return Text("\(doneCount) of \(ResetChallenge.length) done · \(openEarlier) to catch up")
        }
        return Text("\(doneCount) of \(ResetChallenge.length) done")
    }

    private func ring(day: Int, doneCount: Int) -> some View {
        ZStack {
            ProgressRing(
                progress: Double(doneCount) / Double(ResetChallenge.length),
                colors: [Palette.sun, Palette.amber, Palette.ember],
                lineWidth: 6
            )
            Text("\(day)")
                .font(.display(20, weight: .heavy))
                .foregroundStyle(Palette.textPrimary)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
        }
        .frame(width: 58, height: 58)
        .accessibilityHidden(true)
    }

    private func checkButton(day: Int, isDone: Bool) -> some View {
        Button {
            toggleToday(day: day, isDone: isDone)
        } label: {
            ZStack {
                Circle()
                    .fill(isDone ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Palette.surfaceRaised))
                Circle()
                    .strokeBorder(isDone ? Color.white.opacity(0.3) : Palette.amber.opacity(0.55), lineWidth: 1.5)
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(isDone ? Palette.inkText : Palette.amber)
                    .symbolEffect(.bounce, value: reduceMotion ? false : isDone)
            }
            .frame(width: 50, height: 50)
            .shadow(color: Palette.amber.opacity(isDone ? 0.5 : 0), radius: 10)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel(isDone ? Text("Today's step is done") : Text("Mark today's step done"))
        .accessibilityAddTraits(isDone ? .isSelected : [])
    }

    private func toggleToday(day: Int, isDone: Bool) {
        let changed = withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6)) {
            isDone ? ResetChallenge.unmark(day: day, in: run) : ResetChallenge.markDone(day: day, in: run)
        }
        guard changed else { return }
        if isDone {
            Haptics.selection()
        } else {
            Haptics.success()
        }
        if ResetChallenge.isFinished(run) {
            NotificationManager.setChallengeActive(false)
            // Finishing deserves the full celebration on the challenge screen.
            onOpen()
        }
    }
}

private struct ChallengeFinishedCardContent: View {
    let run: ChallengeProgress
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Brand.gradient)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Palette.inkText)
                }
                .frame(width: 56, height: 56)
                .shadow(color: Palette.amber.opacity(0.55), radius: 14)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("30-Day Reset complete")
                        .font(.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                    finishedLine
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: 24, tint: Palette.sun, highlighted: true)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens the 30-Day Reset"))
    }

    private var finishedLine: Text {
        if let finishedAt = run.finishedAt {
            return Text("Finished \(finishedAt, format: .dateTime.month(.abbreviated).day()). Ready for another round?")
        }
        return Text("All 30 steps done. Ready for another round?")
    }
}

#Preview {
    ScrollView {
        ChallengeCard()
            .padding()
    }
    .dawnScreenBackground()
    .previewEnvironment()
}
