import SwiftUI
import SwiftData

/// The full 30-Day Reset screen, presented by the root: an introduction before joining, then today's step and all
/// 30 days, and a celebration once every step is done.
struct ChallengeView: View {
    @Query(sort: \ChallengeProgress.joinedAt) private var runs: [ChallengeProgress]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var confirmingLeave = false
    @State private var showsConfetti = false

    init() {}

    var body: some View {
        NavigationStack {
            ScrollView {
                TimelineView(.everyMinute) { timeline in
                    content(now: timeline.date)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .dawnScreenBackground(glow: backgroundGlow)
            .navigationTitle("30-Day Reset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    closeButton
                }
            }
        }
        .overlay {
            if showsConfetti && !reduceMotion {
                ConfettiView()
            }
        }
        .confirmationDialog("Leave the 30-Day Reset?", isPresented: $confirmingLeave, titleVisibility: .visible) {
            Button("Leave the challenge", role: .destructive, action: leave)
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("This run ends here, but the XP you earned stays. You can start a new Reset anytime.")
        }
        .onAppear(perform: celebrateIfJustFinished)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("challengeView")
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if let run = ResetChallenge.current(in: runs) {
            if ResetChallenge.isFinished(run) {
                ChallengeFinishedSection(run: run, onRestart: start)
            } else {
                ChallengeActiveSection(
                    run: run,
                    now: now,
                    onMark: { day in mark(day, in: run) },
                    onUnmark: { day in unmark(day, in: run) },
                    onLeave: { confirmingLeave = true }
                )
            }
        } else {
            ChallengeIntroSection(onStart: start)
        }
    }

    /// The sky warms as the challenge fills up.
    private var backgroundGlow: Double {
        guard let run = ResetChallenge.current(in: runs) else { return 0.3 }
        return 0.25 + 0.7 * Double(ResetChallenge.completedCount(in: run)) / Double(ResetChallenge.length)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.12), in: Circle())
        }
        .accessibilityLabel(Text("Close"))
    }

    // MARK: Actions

    private func start() {
        Haptics.success()
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85)) {
            _ = ResetChallenge.start(existing: runs, in: context)
        }
        showsConfetti = false
        NotificationManager.setChallengeActive(true)
    }

    private func mark(_ day: Int, in run: ChallengeProgress) {
        let changed = withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7)) {
            ResetChallenge.markDone(day: day, in: run)
        }
        guard changed else { return }
        Haptics.success()
        if ResetChallenge.isFinished(run) {
            NotificationManager.setChallengeActive(false)
            celebrate()
        }
    }

    private func unmark(_ day: Int, in run: ChallengeProgress) {
        let changed = withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8)) {
            ResetChallenge.unmark(day: day, in: run)
        }
        if changed {
            Haptics.selection()
        }
    }

    private func leave() {
        guard let run = ResetChallenge.activeRun(in: runs) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            ResetChallenge.leave(run, in: context)
        }
        Haptics.selection()
        NotificationManager.setChallengeActive(false)
    }

    /// Opened right after the last step was checked off on the Today card: celebrate here.
    private func celebrateIfJustFinished() {
        guard let run = ResetChallenge.current(in: runs), let finishedAt = run.finishedAt,
              Date.now.timeIntervalSince(finishedAt) < 15 else { return }
        celebrate()
    }

    private func celebrate() {
        guard !reduceMotion else { return }
        showsConfetti = true
        Task {
            try? await Task.sleep(for: .seconds(6))
            showsConfetti = false
        }
    }
}

// MARK: - Not joined

private struct ChallengeIntroSection: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            DawnOrb(progress: 0.2, size: 150)
            VStack(spacing: 10) {
                Text("30-Day Reset")
                    .font(.screenTitle)
                    .foregroundStyle(Brand.dawn)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("One small, doable step a day for 30 days. Each takes a few minutes and makes the next day a little easier.")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            expectations
            firstSteps
            Button(action: onStart) {
                Label("Start the 30-Day Reset", systemImage: "sunrise.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            Text("Free and private. You can leave anytime.")
                .font(.footnote)
                .foregroundStyle(Palette.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var expectations: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What to expect")
                .microLabel(Palette.amber)
            ChallengeExpectationRow(
                systemImage: "sun.max.fill",
                tint: Palette.amber,
                title: "A new step every day",
                detail: "Practical and kind, from writing your why to choosing your next 30 days."
            )
            ChallengeExpectationRow(
                systemImage: "arrow.uturn.backward",
                tint: Palette.sky,
                title: "Missed a day? That's okay",
                detail: "Earlier steps stay open, so you can catch up whenever you like."
            )
            ChallengeExpectationRow(
                systemImage: "sparkles",
                tint: Palette.sun,
                title: "+\(XPRewards.perChallengeDay) XP for every step",
                detail: "Each step you finish moves you up the ranks."
            )
            ChallengeExpectationRow(
                systemImage: "heart.fill",
                tint: Palette.rose,
                title: "A slip doesn't reset it",
                detail: "Your Reset keeps going. Just take the next step."
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 24)
    }

    private var firstSteps: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your first three days")
                .microLabel(Palette.amber)
            ForEach(ResetChallenge.steps.prefix(3)) { step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(step.day)")
                        .font(.display(15, weight: .heavy))
                        .foregroundStyle(Palette.inkText)
                        .frame(width: 30, height: 30)
                        .background(Brand.gradient, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.textPrimary)
                        Text(step.detail)
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 24)
    }
}

private struct ChallengeExpectationRow: View {
    let systemImage: String
    let tint: Color
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            IconBadge(systemImage: systemImage, tint: tint, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - In progress

private struct ChallengeActiveSection: View {
    let run: ChallengeProgress
    let now: Date
    let onMark: (Int) -> Void
    let onUnmark: (Int) -> Void
    let onLeave: () -> Void

    var body: some View {
        let today = ResetChallenge.currentDay(for: run, now: now)
        let doneCount = ResetChallenge.completedCount(in: run)
        let openEarlier = ResetChallenge.openEarlierDays(in: run, now: now).count
        VStack(spacing: 24) {
            hero(today: today, doneCount: doneCount, openEarlier: openEarlier)
            ChallengeTodayCard(
                step: ResetChallenge.step(for: today),
                isDone: run.completedDays.contains(today),
                isLastDay: today == ResetChallenge.length,
                onMark: { onMark(today) },
                onUnmark: { onUnmark(today) }
            )
            daysList(today: today)
            Button(action: onLeave) {
                Text("Leave the challenge")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
    }

    private func hero(today: Int, doneCount: Int, openEarlier: Int) -> some View {
        VStack(spacing: 10) {
            ZStack {
                ProgressRing(
                    progress: Double(doneCount) / Double(ResetChallenge.length),
                    colors: [Palette.sun, Palette.amber, Palette.ember, Palette.rose],
                    lineWidth: 14
                )
                VStack(spacing: 0) {
                    Text("Today")
                        .microLabel(Palette.textSecondary)
                    Text("\(today)")
                        .font(.display(64, weight: .heavy))
                        .foregroundStyle(Brand.dawn)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                }
            }
            .frame(width: 196, height: 196)
            .accessibilityHidden(true)
            Text("Day \(today) of \(ResetChallenge.length)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("\(doneCount) of \(ResetChallenge.length) steps done")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
            if openEarlier > 0 {
                Label {
                    Text("Steps still open: \(openEarlier). Catch up whenever you like.")
                } icon: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundStyle(Palette.sky)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Palette.sky.opacity(0.12), in: Capsule())
            }
        }
        .padding(.top, 8)
    }

    private func daysList(today: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "All \(ResetChallenge.length) days", systemImage: "calendar", tint: Palette.amber)
            VStack(spacing: 0) {
                ForEach(ResetChallenge.steps) { step in
                    ChallengeDayRow(
                        step: step,
                        state: ResetChallenge.state(ofDay: step.day, in: run, now: now),
                        isToday: step.day == today,
                        onMark: { onMark(step.day) }
                    )
                    if step.day < ResetChallenge.length {
                        Divider()
                            .overlay(Palette.hairline)
                            .padding(.leading, 44)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .glassSurface(cornerRadius: 24)
        }
    }
}

private struct ChallengeTodayCard: View {
    let step: ChallengeStep
    let isDone: Bool
    let isLastDay: Bool
    let onMark: () -> Void
    let onUnmark: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("Today · Day \(step.day)")
                    .microLabel(Palette.amber)
                Spacer(minLength: 8)
                Chip(text: Text("+\(XPRewards.perChallengeDay) XP"), tint: Palette.amber, filled: isDone)
            }
            HStack(alignment: .top, spacing: 14) {
                IconBadge(systemImage: step.systemImage, tint: Palette.amber, size: 48)
                VStack(alignment: .leading, spacing: 6) {
                    Text(step.title)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(step.detail)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            if isDone {
                doneRow
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else {
                Button(action: onMark) {
                    Label("Mark done", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 26, tint: Palette.amber, highlighted: true)
    }

    private var doneRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(Brand.dawn)
                .accessibilityHidden(true)
            Group {
                if isLastDay {
                    Text("Day 30 done! Finish any open steps to complete your Reset.")
                } else {
                    Text("Done for today. See you tomorrow!")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Undo", action: onUnmark)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
                .accessibilityLabel(Text("Undo today's step"))
        }
        .padding(14)
        .background(Palette.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ChallengeDayRow: View {
    let step: ChallengeStep
    let state: ResetChallenge.DayState
    let isToday: Bool
    let onMark: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 14) {
                marker
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(step.day)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isToday ? Palette.amber : Palette.textTertiary)
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(state == .locked ? Palette.textTertiary : Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(stateDescription)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 12)
        .background {
            if isToday {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.amber.opacity(0.12))
                    .padding(.horizontal, -8)
            }
        }
    }

    @ViewBuilder
    private var marker: some View {
        switch state {
        case .done:
            EngagementCheckmark(isDone: true, size: 30)
        case .open:
            ZStack {
                Circle()
                    .strokeBorder(isToday ? Palette.amber : Palette.textTertiary, lineWidth: 2)
                Text("\(step.day)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isToday ? Palette.amber : Palette.textSecondary)
            }
            .frame(width: 30, height: 30)
            .accessibilityHidden(true)
        case .locked:
            Image(systemName: "lock.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.textTertiary)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.06), in: Circle())
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if state == .open {
            if isToday {
                Chip(text: Text("Today"), tint: Palette.amber)
                    .accessibilityHidden(true)
            } else {
                Button(action: onMark) {
                    EngagementCapsuleLabel(text: Text("Mark done"), font: .caption.weight(.bold))
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityLabel(Text("Mark day \(step.day) done"))
            }
        }
    }

    private var stateDescription: Text {
        switch state {
        case .done:
            return Text("Done")
        case .open:
            return isToday ? Text("Today") : Text("Open, you can still do it")
        case .locked:
            return Text("Locked")
        }
    }
}

// MARK: - Finished

private struct ChallengeFinishedSection: View {
    let run: ChallengeProgress
    let onRestart: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            badge
            VStack(spacing: 10) {
                Text("You did it!")
                    .font(.display(40, weight: .heavy))
                    .foregroundStyle(Brand.dawn)
                    .accessibilityAddTraits(.isHeader)
                Text("30 days, 30 steps. That's a new rhythm, and you built it yourself.")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                StatTile(title: "Finished", value: finishedText, systemImage: "calendar", tint: Palette.sky)
                StatTile(title: "XP earned", value: xpText, systemImage: "sparkles", tint: Palette.sun)
            }
            dots
            Button(action: onRestart) {
                Label("Start again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(PrimaryButtonStyle())
            Text("A fresh 30 days starts today. Your XP and this badge stay with you.")
                .font(.footnote)
                .foregroundStyle(Palette.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }

    private var badge: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Palette.amber.opacity(0.55), .clear], center: .center, startRadius: 40, endRadius: 120))
                .frame(width: 240, height: 240)
            Circle()
                .fill(Brand.gradient)
                .frame(width: 128, height: 128)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 3))
            Image(systemName: "trophy.fill")
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(Palette.inkText)
        }
        .frame(height: 200)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
        .opacity(appeared || reduceMotion ? 1 : 0)
        .accessibilityHidden(true)
    }

    private var dots: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 10), spacing: 10) {
            ForEach(1...ResetChallenge.length, id: \.self) { day in
                Circle()
                    .fill(run.completedDays.contains(day) ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Color.white.opacity(0.1)))
                    .frame(width: 16, height: 16)
            }
        }
        .padding(18)
        .glassSurface(cornerRadius: 22)
        .accessibilityHidden(true)
    }

    private var finishedText: String {
        guard let finishedAt = run.finishedAt else { return "—" }
        return finishedAt.formatted(.dateTime.month(.abbreviated).day())
    }

    private var xpText: String {
        "+\((ResetChallenge.completedCount(in: run) * XPRewards.perChallengeDay).formatted())"
    }
}

#Preview {
    ChallengeView()
        .previewEnvironment()
}
