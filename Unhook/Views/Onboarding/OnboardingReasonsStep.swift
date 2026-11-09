import SwiftUI

/// "Why do you want to quit?": pick from the preset's suggestions and/or write one in your own words.
struct OnboardingReasonsStep: View {
    @Binding var answers: OnboardingAnswers
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isCustomFocused: Bool

    init(answers: Binding<OnboardingAnswers>, onContinue: @escaping () -> Void) {
        _answers = answers
        self.onContinue = onContinue
    }

    private var suggestions: [String] { answers.draft.suggestedReasons }
    private var hasCustomReason: Bool { !answers.trimmedCustomReason.isEmpty }

    var body: some View {
        OnboardingStepLayout(title: Text("Why do you want to quit?"), subtitle: subtitle) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(suggestions, id: \.self) { reason in
                    reasonChip(reason)
                }
                customField
                    .padding(.top, suggestions.isEmpty ? 0 : 6)
                if !answers.canAddReason {
                    Text("That's \(OnboardingAnswers.maxReasons). Tap one to swap it out.")
                        .font(.footnote)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: answers.selectedReasons)
        } footer: {
            Button {
                isCustomFocused = false
                Haptics.tap()
                onContinue()
            } label: {
                Text(answers.reasons.isEmpty ? "Skip for now" : "Continue")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var subtitle: Text {
        if suggestions.isEmpty {
            return Text("In your own words. It shows up on the SOS screen when a craving hits.")
        }
        return Text("Pick up to \(OnboardingAnswers.maxReasons). They show up on the SOS screen when a craving hits.")
    }

    private func reasonChip(_ reason: String) -> some View {
        let isSelected = answers.isSelected(reason)
        let isAvailable = isSelected || answers.canAddReason
        return Button {
            toggle(reason)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.headline)
                    .foregroundStyle(isSelected ? Palette.sun : Palette.textSecondary)
                    .accessibilityHidden(true)
                Text(reason)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onboardingPanel(cornerRadius: 18, isHighlighted: isSelected)
        }
        .buttonStyle(PressableCardStyle())
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.45)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var customField: some View {
        HStack(spacing: 12) {
            Image(systemName: "pencil")
                .font(.headline)
                .foregroundStyle(isCustomFocused || hasCustomReason ? Palette.sun : Palette.textTertiary)
                .accessibilityHidden(true)
            TextField("Add your own reason (optional)", text: $answers.customReason)
                .foregroundStyle(Palette.textPrimary)
                .tint(Palette.amber)
                .submitLabel(.done)
                .focused($isCustomFocused)
                .onSubmit { isCustomFocused = false }
        }
        .padding(16)
        .onboardingPanel(cornerRadius: 18, isHighlighted: isCustomFocused || hasCustomReason)
        .disabled(!answers.canEditCustomReason)
        .opacity(answers.canEditCustomReason ? 1 : 0.45)
    }

    private func toggle(_ reason: String) {
        if answers.toggleReason(reason) {
            Haptics.selection()
        } else {
            Haptics.warning()
        }
    }
}

#Preview {
    ZStack {
        DawnBackground(glow: 0.4)
        OnboardingReasonsStep(answers: .constant(.preview)) {}
    }
    .environment(\.colorScheme, .dark)
    .previewEnvironment()
}
