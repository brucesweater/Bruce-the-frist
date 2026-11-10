import SwiftUI

/// "What did it cost you?": money and time per day, prefilled from the preset. Each figure keeps its color
/// everywhere in the app: money is mint, time is sky, units are amber.
struct OnboardingCostStep: View {
    @Binding var answers: OnboardingAnswers
    let onContinue: () -> Void

    @AppStorage(AppSettings.Keys.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case cost, minutes, units
    }

    init(answers: Binding<OnboardingAnswers>, onContinue: @escaping () -> Void) {
        _answers = answers
        self.onContinue = onContinue
    }

    var body: some View {
        OnboardingStepLayout(
            title: Text("What did it cost you?"),
            subtitle: Text("A rough guess is perfect. Unhook turns it into the money and time you win back.")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                numberRow(
                    Text("Money per day"),
                    systemImage: "banknote.fill",
                    tint: Palette.money,
                    text: $answers.draft.costText,
                    prefix: currencySymbol,
                    suffix: nil,
                    field: .cost
                )
                numberRow(
                    Text("Minutes per day"),
                    systemImage: "clock.fill",
                    tint: Palette.time,
                    text: $answers.draft.minutesText,
                    prefix: nil,
                    suffix: Text("min"),
                    field: .minutes
                )
                if !answers.draft.unitName.isEmpty {
                    numberRow(
                        Text("\(answers.draft.unitName.localizedCapitalized) per day"),
                        systemImage: "number",
                        tint: Palette.units,
                        text: $answers.draft.unitsText,
                        prefix: nil,
                        suffix: nil,
                        field: .units
                    )
                }
                Text("Leave a field empty if it doesn't apply. You can change this anytime.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 4)
            }
        } footer: {
            Button("Continue") {
                focusedField = nil
                Haptics.tap()
                onContinue()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func numberRow(
        _ title: Text,
        systemImage: String,
        tint: Color,
        text: Binding<String>,
        prefix: String?,
        suffix: Text?,
        field: Field
    ) -> some View {
        HStack(spacing: 12) {
            IconBadge(systemImage: systemImage, tint: tint, size: 36)
            title
                .font(.cardTitle)
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 8)
            if let prefix {
                Text(prefix)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundStyle(Palette.textPrimary)
                .tint(tint)
                .frame(maxWidth: 96)
                .focused($focusedField, equals: field)
                .accessibilityLabel(title)
            if let suffix {
                suffix
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(16)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture { focusedField = field }
        .onboardingPanel(isHighlighted: focusedField == field, tint: tint)
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? currencyCode
    }
}

#Preview {
    ZStack {
        DawnBackground(glow: 0.3)
        OnboardingCostStep(answers: .constant(.preview)) {}
    }
    .environment(\.colorScheme, .dark)
    .previewEnvironment()
}
