import SwiftUI
import SwiftData

/// First-run flow: pick the habit, personalize it, see what quitting gives back, opt into reminders and
/// meet Unhook Pro. The sky warms a little with every step, from deep night on the welcome screen toward dawn.
/// The habit is created only at the very end, so leaving midway never saves half an answer.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: OnboardingStep = .welcome
    @State private var answers = OnboardingAnswers()
    @State private var isMovingForward = true
    @State private var didFinish = false
    @State private var didSaveHabit = false

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            OnboardingSky(dawn: dawnLevel)

            VStack(spacing: 0) {
                if let number = step.questionNumber {
                    OnboardingTopBar(
                        questionNumber: number,
                        questionCount: OnboardingStep.questionCount,
                        onBack: { goBack() }
                    )
                    .transition(.opacity)
                }

                ZStack {
                    currentStep
                        .id(step)
                        .transition(stepTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var currentStep: some View {
        switch step {
        case .welcome:
            OnboardingWelcomeStep { move(to: .habit) }
        case .habit:
            OnboardingHabitStep(selectedPresetID: answers.selectedPresetID) { preset in choose(preset) }
        case .quitDate:
            OnboardingQuitDateStep(answers: $answers) { move(to: .cost) }
        case .cost:
            OnboardingCostStep(answers: $answers) { move(to: .reasons) }
        case .reasons:
            OnboardingReasonsStep(answers: $answers) { move(to: .projection) }
        case .projection:
            OnboardingProjectionStep(answers: answers) { move(to: .reminders) }
        case .reminders:
            OnboardingRemindersStep { leaveReminders() }
        case .paywall:
            PaywallView(reason: .onboarding, onClose: { finish() })
        }
    }

    /// How far the sky has warmed: night on the welcome screen, first light by the last step.
    private var dawnLevel: Double {
        Double(step.rawValue) / Double(OnboardingStep.paywall.rawValue)
    }

    /// Only the incoming screen moves (the outgoing one fades), so the direction is always read from current
    /// state and going back never slides the wrong way. The outgoing screen stops taking taps right away.
    private var stepTransition: AnyTransition {
        let exit = AnyTransition.modifier(
            active: OnboardingStepExit(isExiting: true),
            identity: OnboardingStepExit(isExiting: false)
        )
        guard !reduceMotion else { return .asymmetric(insertion: .opacity, removal: exit) }
        return .asymmetric(
            insertion: .offset(x: isMovingForward ? 48 : -48).combined(with: .opacity),
            removal: exit
        )
    }

    // MARK: Navigation

    private func move(to target: OnboardingStep) {
        guard target != step, !didFinish else { return }
        isMovingForward = target > step
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
            step = target
        }
    }

    private func goBack() {
        guard let previous = step.previous else { return }
        Haptics.tap()
        move(to: previous)
    }

    private func choose(_ preset: HabitPreset) {
        Haptics.selection()
        answers.choose(preset)
        move(to: .quitDate)
    }

    /// Members who already have Pro (restored, or Family Sharing) skip straight past the paywall.
    private func leaveReminders() {
        // Save before the paywall, so closing the app there never loses the user's setup.
        saveHabit()
        if store.isPro {
            finish()
        } else {
            move(to: .paywall)
        }
    }

    // MARK: Finish

    private func saveHabit() {
        guard !didSaveHabit else { return }
        didSaveHabit = true

        let habit = answers.makeHabit()
        context.insert(habit)
        // Save right away: this is the user's whole setup, and autosave may not run before the app is closed.
        try? context.save()
        NotificationManager.scheduleMilestones(for: habit)
        UserDefaults.standard.set(true, forKey: AppSettings.Keys.didPromptFirstHabit)
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        saveHabit()
        Haptics.success()
        onFinish()
    }
}

/// The onboarding sky: the app's night background plus a warm dawn light that rises a little with each step.
private struct OnboardingSky: View {
    let dawn: Double

    var body: some View {
        ZStack {
            DawnBackground(glow: 0.1)
            RadialGradient(
                colors: [Palette.amber.opacity(0.34), Palette.rose.opacity(0.14), .clear],
                center: UnitPoint(x: 0.5, y: 1.08),
                startRadius: 0,
                endRadius: 560
            )
            .opacity(dawn)
            .offset(y: 160 * (1 - dawn))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// How a step leaves: it fades out and, from the first frame, stops taking taps and drops out of the
/// accessibility tree, so a screen on its way out can never be activated by mistake.
private struct OnboardingStepExit: ViewModifier {
    let isExiting: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isExiting ? 0 : 1)
            .allowsHitTesting(!isExiting)
            .accessibilityHidden(isExiting)
    }
}

#Preview {
    OnboardingView {}
        .previewEnvironment()
}
