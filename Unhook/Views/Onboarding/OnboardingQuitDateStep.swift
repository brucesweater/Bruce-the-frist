import SwiftUI

/// "When did you last …?": start the streak now, or count the clean time already earned.
/// Custom habits are named here too.
struct OnboardingQuitDateStep: View {
    @Binding var answers: OnboardingAnswers
    let onContinue: () -> Void

    @FocusState private var isNameFocused: Bool

    init(answers: Binding<OnboardingAnswers>, onContinue: @escaping () -> Void) {
        _answers = answers
        self.onContinue = onContinue
    }

    var body: some View {
        OnboardingStepLayout(
            title: Text(OnboardingCopy.lastTimeQuestion(presetID: answers.draft.presetID)),
            subtitle: Text("Already been going without? Unhook counts every minute you've earned.")
        ) {
            VStack(alignment: .leading, spacing: 24) {
                if answers.isCustom {
                    nameField
                }
                timingChoices
            }
        } footer: {
            Button("Continue") {
                isNameFocused = false
                Haptics.tap()
                onContinue()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!answers.canLeaveQuitDateStep)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Name your habit")
                .font(.cardTitle)
                .foregroundStyle(Palette.textPrimary)
            TextField("e.g. Late-night snacking", text: $answers.draft.name)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
                .tint(Palette.amber)
                .submitLabel(.done)
                .focused($isNameFocused)
                .onSubmit { isNameFocused = false }
                .padding(16)
                .onboardingPanel(isHighlighted: isNameFocused)
        }
    }

    private var timingChoices: some View {
        VStack(spacing: 12) {
            OnboardingChoiceRow(
                title: Text("Just now"),
                subtitle: Text("I'm starting fresh today"),
                systemImage: "sparkles",
                isSelected: answers.timing == .justNow
            ) {
                select(.justNow)
            }
            OnboardingChoiceRow(
                title: Text("Earlier"),
                subtitle: Text("I've already been going without"),
                systemImage: "calendar",
                isSelected: answers.timing == .earlier
            ) {
                select(.earlier)
            }
            if answers.timing == .earlier {
                earlierPicker
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if answers.draft.presetID == "alcohol" {
                WithdrawalCaution()
            }
        }
    }

    private var earlierPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("Last time", selection: $answers.draft.quitDate, in: ...Date.now)
                .font(.cardTitle)
                .foregroundStyle(Palette.textPrimary)
                .tint(Palette.amber)
            if let encouragement {
                Label {
                    Text(encouragement)
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Palette.sun)
                }
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(16)
        .onboardingPanel()
    }

    private var encouragement: String? {
        let clean = answers.cleanTime()
        guard clean >= 60 else { return nil }
        return String(localized: "That's \(DurationFormatter.compact(clean)) already. It all counts.")
    }

    private func select(_ timing: OnboardingAnswers.QuitTiming) {
        guard answers.timing != timing else { return }
        Haptics.selection()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            answers.setTiming(timing)
        }
    }
}

#Preview {
    ZStack {
        DawnBackground(glow: 0.2)
        OnboardingQuitDateStep(answers: .constant(.preview)) {}
    }
    .environment(\.colorScheme, .dark)
    .previewEnvironment()
}

/// Stopping heavy daily drinking all at once can be dangerous, so say so before the streak starts.
struct WithdrawalCaution: View {
    var body: some View {
        Label {
            Text("Drinking heavily every day? Stopping suddenly can cause dangerous withdrawal. Talk to a doctor before you stop.")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "stethoscope")
                .foregroundStyle(Palette.amber)
        }
        .font(.footnote)
        .foregroundStyle(Palette.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
