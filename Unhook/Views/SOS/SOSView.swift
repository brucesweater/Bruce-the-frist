import SwiftUI
import SwiftData
import UIKit

/// The craving emergency button: about a minute of guided breathing with the user's own reasons, then a sunrise.
/// The craving is logged as beaten, with an optional trigger and strength, plus ideas to try, the coach and a helpline.
struct SOSView: View {
    /// The habit the craving is about, or nil when opened from the home screen.
    let habit: Habit?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Habit.sortIndex) private var allHabits: [Habit]
    @Query private var urges: [Urge]

    private enum Phase { case breathing, finished }

    private enum BreathStep {
        case inhale, hold, exhale

        var title: String {
            switch self {
            case .inhale: String(localized: "Breathe in")
            case .hold: String(localized: "Hold")
            case .exhale: String(localized: "Breathe out")
            }
        }

        /// In for 4, hold for 4, out for 6.
        var seconds: Int {
            switch self {
            case .inhale: 4
            case .hold: 4
            case .exhale: 6
            }
        }
    }

    /// Something to do while a craving fades, with a symbol for its chip.
    private struct Distraction: Hashable {
        let text: String
        let systemImage: String
    }

    private static let totalCycles = 4

    private static let fallbackReasons = [
        String(localized: "Cravings peak and fade within minutes."),
        String(localized: "You are stronger than this moment."),
        String(localized: "Future you is already proud of you."),
    ]

    private static let allDistractions: [Distraction] = [
        Distraction(text: String(localized: "Drink a big glass of cold water"), systemImage: "drop.fill"),
        Distraction(text: String(localized: "Go for a five-minute walk"), systemImage: "figure.walk"),
        Distraction(text: String(localized: "Text or call a friend"), systemImage: "message.fill"),
        Distraction(text: String(localized: "Do 15 push-ups or squats"), systemImage: "figure.strengthtraining.traditional"),
        Distraction(text: String(localized: "Splash cold water on your face"), systemImage: "snowflake"),
        Distraction(text: String(localized: "Chew gum or eat something crunchy"), systemImage: "carrot.fill"),
        Distraction(text: String(localized: "Put on your favorite song"), systemImage: "music.note"),
        Distraction(text: String(localized: "Write down how you feel right now"), systemImage: "square.and.pencil"),
        Distraction(text: String(localized: "Brush your teeth"), systemImage: "sparkles"),
        Distraction(text: String(localized: "Step outside and take ten deep breaths"), systemImage: "wind"),
    ]

    @State private var phase: Phase = .breathing
    @State private var step: BreathStep = .inhale
    /// 0 with empty lungs, 1 at the top of the breath. Drives the orb.
    @State private var breath: Double = 0
    @State private var secondsLeft = BreathStep.inhale.seconds
    @State private var cycle = 1
    @State private var reasonIndex = 0
    /// Changes on "Breathe again", which restarts the breathing task.
    @State private var runID = UUID()
    @State private var beatenCount = 0
    @State private var distractions = Array(SOSView.allDistractions.shuffled().prefix(3))
    @State private var selectedTrigger: CravingTrigger?
    /// 1 (mild) … 5 (overwhelming), or 0 when not rated.
    @State private var intensity = 0
    /// The craving logged as beaten when the breathing ended. Picking a trigger or a strength updates it, and
    /// breathing again never logs the same craving twice.
    @State private var loggedUrge: Urge?
    /// False once today's beaten cravings pass the daily XP cap, so the finish screen doesn't promise XP.
    @State private var earnedXP = true
    @State private var sunRisen = false
    @State private var showingCoach = false

    private var reasons: [String] {
        let source = habit.map { [$0] } ?? allHabits
        let all = source.flatMap(\.reasons)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return all.isEmpty ? Self.fallbackReasons : all
    }

    private var currentReason: String {
        let all = reasons
        return all[reasonIndex % all.count]
    }

    var body: some View {
        ZStack {
            screenBackground

            switch phase {
            case .breathing:
                breathingContent
                    .transition(.opacity)
            case .finished:
                finishedContent
                    .transition(finishTransition)
            }
        }
        .overlay(alignment: .topTrailing) {
            closeButton
        }
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showingCoach) {
            CoachView(habit: habit)
        }
        .task(id: runID) {
            await runBreathing(id: runID)
        }
        .onChange(of: phase, initial: true) { _, newPhase in
            // A minute without touching the screen is longer than many Auto-Lock settings.
            UIApplication.shared.isIdleTimerDisabled = newPhase == .breathing
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var finishTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97))
    }

    private var screenBackground: some View {
        ZStack {
            DawnBackground(glow: 0.35)
            // Morning light that comes up with the sun once the craving is beaten.
            RadialGradient(
                colors: [Palette.amber.opacity(0.32), Palette.rose.opacity(0.14), .clear],
                center: UnitPoint(x: 0.5, y: 0.1),
                startRadius: 0,
                endRadius: 560
            )
            .opacity(sunRisen ? 1 : 0)
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
    }

    // MARK: Breathing

    private var breathingContent: some View {
        GeometryReader { proxy in
            let orbSize = max(140, min(300, proxy.size.width - 64, proxy.size.height * 0.38))
            VStack(spacing: 0) {
                Spacer(minLength: 52)
                SOSBreathingOrb(breath: breath, secondsLeft: secondsLeft, diameter: orbSize)
                breathGuide
                    .padding(.top, 20)
                Spacer(minLength: 20)
                SOSReasonCard(reason: currentReason, index: reasonIndex)
                skipButton
                    .padding(.top, 16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    /// The step in big rounded type, then one dot per cycle.
    private var breathGuide: some View {
        VStack(spacing: 14) {
            // A ZStack, so the old and new step overlap while they crossfade.
            ZStack {
                Text(step.title)
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .id(step)
                    .transition(.opacity)
            }
            SOSCycleDots(current: cycle, total: Self.totalCycles)
        }
    }

    private var skipButton: some View {
        Button(action: finish) {
            Text("Skip")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Ends the breathing early")
    }

    private func runBreathing(id: UUID) async {
        guard phase == .breathing else { return }

        for current in 1...Self.totalCycles {
            cycle = current
            for next in [BreathStep.inhale, .hold, .exhale] {
                guard await breathe(next, run: id) else { return }
            }
            if current < Self.totalCycles {
                withAnimation(.easeInOut(duration: 0.8)) { reasonIndex += 1 }
            }
        }

        finish()
    }

    /// One step of the breath: moves the orb, counts the seconds down with a gentle tick each second (none while
    /// holding) and a firmer tap when the step changes. Returns false if the screen closed, the user skipped ahead
    /// or a newer run took over.
    private func breathe(_ next: BreathStep, run id: UUID) async -> Bool {
        withAnimation(.easeInOut(duration: 0.4)) { step = next }
        secondsLeft = next.seconds
        Haptics.tap()
        Self.announce(next.title)

        switch next {
        case .inhale:
            withAnimation(.easeInOut(duration: Double(next.seconds))) { breath = 1 }
        case .exhale:
            withAnimation(.easeInOut(duration: Double(next.seconds))) { breath = 0 }
        case .hold:
            break
        }

        for elapsed in 1...next.seconds {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return false
            }
            guard phase == .breathing, id == runID else { return false }
            if elapsed < next.seconds {
                withAnimation(.easeInOut(duration: 0.3)) { secondsLeft = next.seconds - elapsed }
                if next != .hold {
                    Haptics.selection()
                }
            }
        }
        return true
    }

    /// Speaks each step for VoiceOver users, who can't see the orb.
    private static func announce(_ text: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    // MARK: Craving beaten

    private var finishedContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                finishHeader
                cravingDetailsCard
                distractionsCard
                moreHelp
            }
            .padding(.horizontal, 20)
            .padding(.top, 44)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            doneBar
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.6) : .easeOut(duration: 1.8)) {
                sunRisen = true
            }
        }
    }

    private var finishHeader: some View {
        VStack(spacing: 12) {
            SOSRisingSun(risen: sunRisen)
                .padding(.bottom, 4)
            Text("Craving beaten")
                .font(.screenTitle)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
            if earnedXP {
                Chip(text: Text("+\(XPRewards.perCravingBeaten) XP"), tint: Palette.amber, filled: true)
            }
            Text(celebrationLine)
                .font(.callout)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var celebrationLine: String {
        beatenCount <= 1
            ? String(localized: "Your first one. Every craving you ride out proves you can do it.")
            : String(localized: "That's \(beatenCount) cravings beaten. Every one you ride out proves you can do it.")
    }

    /// The optional "what set it off / how strong" questions. Answers are saved on the craving right away.
    private var cravingDetailsCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                cardTitle("What set it off?")
                SOSFlowLayout(spacing: 8) {
                    ForEach(CravingTrigger.allCases) { trigger in
                        SOSChoiceChip(title: trigger.title, emoji: trigger.emoji, isSelected: selectedTrigger == trigger) {
                            selectTrigger(trigger)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                cardTitle("How strong was it?")
                SOSFlowLayout(spacing: 8) {
                    ForEach(1...5, id: \.self) { level in
                        SOSChoiceChip(title: Self.intensityDescription(level), isSelected: intensity == level) {
                            selectIntensity(level)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassSurface(cornerRadius: 24)
    }

    private var distractionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Still craving? Try one of these:")
            SOSFlowLayout(spacing: 8) {
                ForEach(distractions, id: \.text) { idea in
                    SOSIdeaChip(text: idea.text, systemImage: idea.systemImage)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassSurface(cornerRadius: 24)
    }

    private func cardTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.cardTitle)
            .foregroundStyle(Palette.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private var moreHelp: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.tap()
                showingCoach = true
            } label: {
                Label("Talk it through with your coach", systemImage: "sparkles")
            }
            .buttonStyle(SecondaryButtonStyle())

            Button(action: restart) {
                Label("Breathe again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(SecondaryButtonStyle())

            if let url = CoachSafety.helplineURL {
                Link(destination: url) {
                    Label("Find a free helpline", systemImage: "phone.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .accessibilityHint("Opens a free directory of crisis lines")
            }
        }
    }

    private var doneBar: some View {
        Button {
            Haptics.tap()
            dismiss()
        } label: {
            Text("Done")
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background {
            LinearGradient(
                colors: [Palette.ink.opacity(0), Palette.ink.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private static func intensityDescription(_ level: Int) -> String {
        switch level {
        case 1: String(localized: "Mild")
        case 2: String(localized: "Manageable")
        case 3: String(localized: "Strong")
        case 4: String(localized: "Intense")
        case 5: String(localized: "Overwhelming")
        default: String(localized: "Not rated")
        }
    }

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.headline)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 44, height: 44)
                .background(Palette.surfaceRaised.opacity(0.6), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .accessibilityLabel("Close")
    }

    // MARK: Actions

    /// Ends the breathing, whether it ran to the end or the user skipped: logs the beaten craving and lets the sun up.
    private func finish() {
        guard phase == .breathing else { return }
        logBeatenCraving()
        Haptics.success()
        withAnimation(.easeInOut(duration: 0.5)) { phase = .finished }
    }

    /// Logs the craving as beaten, once per visit, on the habit it's about (or the only habit there is).
    private func logBeatenCraving() {
        guard loggedUrge == nil else { return }
        let resisted = urges.filter(\.resisted)
        beatenCount = resisted.count + 1
        let calendar = Calendar.current
        earnedXP = resisted.filter { calendar.isDateInToday($0.date) }.count < XPRewards.maxCravingsPerDay
        let urge = Urge(resisted: true, trigger: selectedTrigger, intensity: intensity)
        context.insert(urge)
        if let target = habit ?? (allHabits.count == 1 ? allHabits.first : nil) {
            target.urges.append(urge)
        }
        loggedUrge = urge
        // Counts toward the App Store review prompt, which is only shown later at a calm high point.
        ReviewPrompter.standard.recordPositiveMoment()
    }

    /// Picks a trigger (tapping the picked one clears it) and saves it on the logged craving.
    private func selectTrigger(_ trigger: CravingTrigger) {
        let newValue: CravingTrigger? = selectedTrigger == trigger ? nil : trigger
        selectedTrigger = newValue
        loggedUrge?.trigger = newValue
        Haptics.selection()
    }

    /// Picks a strength (tapping the picked one clears it) and saves it on the logged craving.
    private func selectIntensity(_ level: Int) {
        let newValue = intensity == level ? 0 : level
        intensity = newValue
        loggedUrge?.intensity = newValue
        Haptics.selection()
    }

    private func close() {
        dismiss()
    }

    /// Another round of breathing for a craving that's still there. The craving stays logged once.
    private func restart() {
        Haptics.tap()
        breath = 0
        step = .inhale
        secondsLeft = BreathStep.inhale.seconds
        cycle = 1
        distractions = Array(Self.allDistractions.shuffled().prefix(3))
        withAnimation(.easeInOut(duration: 0.4)) {
            phase = .breathing
            sunRisen = false
        }
        runID = UUID()
    }
}

#Preview {
    SOSView(habit: nil)
        .previewEnvironment()
}
