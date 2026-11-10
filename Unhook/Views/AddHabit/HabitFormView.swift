import SwiftUI
import SwiftData

/// Creates or edits a habit: a Form of frosted rows on the night sky.
struct HabitFormView: View {
    let editing: Habit?
    let onSave: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.sortIndex) private var habits: [Habit]
    @AppStorage(AppSettings.Keys.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode

    @State private var draft: HabitDraft
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, emoji, cost, minutes, units, unitName
        case reason(Int)
    }

    init(draft: HabitDraft, editing: Habit?, onSave: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.editing = editing
        self.onSave = onSave
    }

    var body: some View {
        Form {
            identitySection
            themeSection
            dateSection
            costSection
            reasonsSection
        }
        .dawnScreenBackground(glow: 0.2)
        .tint(Palette.amber)
        .navigationTitle(editing == nil ? "New habit" : "Edit habit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(editing == nil ? "Start" : "Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(!draft.isValid)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onAppear {
            if draft.name.isEmpty { focusedField = .name }
        }
    }

    // MARK: Sections

    private var identitySection: some View {
        Section {
            HStack(spacing: 14) {
                TextField("✨", text: $draft.emoji)
                    .font(.system(size: 34))
                    .multilineTextAlignment(.center)
                    .frame(width: 62, height: 62)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(draft.theme.gradient)
                            .opacity(0.3)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(draft.theme.accent.opacity(0.55), lineWidth: 1)
                    }
                    .focused($focusedField, equals: .emoji)
                    .onChange(of: draft.emoji) { _, newValue in
                        if newValue.count > 1 { draft.emoji = String(newValue.suffix(1)) }
                    }
                    .accessibilityLabel("Emoji")
                TextField("What are you quitting?", text: $draft.name)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.done)
            }
            .padding(.vertical, 6)
        } header: {
            HabitFormHeader(title: Text("Your habit"), systemImage: "sparkles", tint: draft.theme.accent)
        } footer: {
            HabitFormFooter(text: Text("Tap the emoji to pick your own."))
        }
        .habitFormRowStyle()
    }

    private var themeSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(HabitTheme.allCases) { theme in
                        themeSwatch(theme)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
        } header: {
            HabitFormHeader(title: Text("Color"), systemImage: "paintpalette.fill", tint: draft.theme.accent)
        }
        .habitFormRowStyle()
    }

    private func themeSwatch(_ theme: HabitTheme) -> some View {
        let isSelected = draft.theme == theme
        return Button {
            draft.theme = theme
            Haptics.selection()
        } label: {
            Circle()
                .fill(theme.gradient)
                .frame(width: 38, height: 38)
                .padding(4)
                .overlay(Circle().strokeBorder(Palette.textPrimary, lineWidth: isSelected ? 2.5 : 0))
                .shadow(color: theme.accent.opacity(isSelected ? 0.6 : 0), radius: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The current streak can't start before the last slip; otherwise that clean time would count twice.
    /// (A slip logged by mistake can be undone from the habit's history instead.)
    private var earliestQuitDate: Date {
        min(editing?.latestRelapse?.date ?? .distantPast, .now)
    }

    private var dateSection: some View {
        Section {
            DatePicker("Quit date", selection: $draft.quitDate, in: earliestQuitDate...Date.now)
        } header: {
            HabitFormHeader(
                title: Text(editing == nil ? "When did you quit?" : "Current streak started"),
                systemImage: "calendar",
                tint: Palette.sky
            )
        } footer: {
            VStack(alignment: .leading, spacing: 10) {
                HabitFormFooter(text: Text(editing == nil
                    ? "Already clean for a while? Pick the date and Unhook counts it."
                    : "Fix the date if you set it wrong. It can't be earlier than your last slip; to take back a slip, undo it from the habit's history."))
                if editing == nil && WithdrawalCaution.applies(to: draft.presetID) {
                    WithdrawalCaution(presetID: draft.presetID)
                }
            }
        }
        .habitFormRowStyle()
    }

    private var costSection: some View {
        Section {
            numberRow(
                "Money per day",
                systemImage: "banknote.fill",
                tint: Palette.money,
                text: $draft.costText,
                prefix: currencySymbol,
                field: .cost
            )
            numberRow(
                "Minutes per day",
                systemImage: "clock.fill",
                tint: Palette.time,
                text: $draft.minutesText,
                prefix: nil,
                field: .minutes
            )
            amountRow
        } header: {
            HabitFormHeader(title: Text("What it cost you"), systemImage: "chart.bar.fill", tint: Palette.money)
        } footer: {
            HabitFormFooter(text: Text("Used to show the money, time and \(unitsLabel) you win back. Leave blank if it doesn't apply."))
        }
        .habitFormRowStyle()
    }

    private var amountRow: some View {
        HStack(spacing: 12) {
            IconBadge(systemImage: "number", tint: Palette.units, size: 30)
            Text("Amount per day")
            Spacer()
            TextField("0", text: $draft.unitsText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .rounded).weight(.semibold).monospacedDigit())
                .frame(maxWidth: 70)
                .focused($focusedField, equals: .units)
                .accessibilityLabel(Text("Amount per day"))
            TextField("units", text: $draft.unitName)
                .frame(maxWidth: 100)
                .foregroundStyle(Palette.textSecondary)
                .focused($focusedField, equals: .unitName)
        }
    }

    private var reasonsSection: some View {
        Section {
            ForEach(draft.reasons.indices, id: \.self) { index in
                TextField(reasonPlaceholder(index), text: $draft.reasons[index], axis: .vertical)
                    .focused($focusedField, equals: .reason(index))
            }
        } header: {
            HabitFormHeader(title: Text("Why are you quitting?"), systemImage: "heart.fill", tint: Palette.rose)
        } footer: {
            HabitFormFooter(text: Text("Your reasons appear on the SOS screen when a craving hits. Make them personal."))
        }
        .habitFormRowStyle()
    }

    // MARK: Helpers

    private func numberRow(
        _ title: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        text: Binding<String>,
        prefix: String?,
        field: Field
    ) -> some View {
        HStack(spacing: 12) {
            IconBadge(systemImage: systemImage, tint: tint, size: 30)
            Text(title)
            Spacer()
            if let prefix {
                Text(prefix)
                    .foregroundStyle(Palette.textSecondary)
            }
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .rounded).weight(.semibold).monospacedDigit())
                .frame(maxWidth: 100)
                .focused($focusedField, equals: field)
                .accessibilityLabel(Text(title))
        }
    }

    private var unitsLabel: String {
        draft.unitName.isEmpty ? String(localized: "units") : draft.unitName
    }

    private func reasonPlaceholder(_ index: Int) -> String {
        if index < draft.suggestedReasons.count {
            return String(localized: "e.g. \(draft.suggestedReasons[index])")
        }
        return String(localized: "Reason \(index + 1)")
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? currencyCode
    }

    private func save() {
        let habit: Habit
        if let editing {
            habit = editing
        } else {
            let nextIndex = (habits.map(\.sortIndex).max() ?? -1) + 1
            habit = Habit(name: draft.trimmedName, emoji: draft.emoji, theme: draft.theme, sortIndex: nextIndex, presetID: draft.presetID)
            context.insert(habit)
        }

        habit.name = draft.trimmedName
        habit.emoji = draft.emoji.isEmpty ? "✨" : draft.emoji
        habit.theme = draft.theme
        habit.dailyCost = HabitDraft.parse(draft.costText, upTo: HabitDraft.maxMoney)
        habit.dailyMinutes = HabitDraft.parse(draft.minutesText, upTo: HabitDraft.maxDailyMinutes)
        habit.unitsPerDay = HabitDraft.parse(draft.unitsText)
        habit.unitName = draft.unitName.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.reasons = draft.cleanedReasons
        habit.streakStart = min(max(draft.quitDate, earliestQuitDate), .now)
        // Moving the quit date later must not leave an old celebration record that would skip milestones.
        let reached = Milestone.latest(reachedBy: habit.stats().currentStreak)?.seconds ?? 0
        habit.celebratedMilestoneSeconds = min(habit.celebratedMilestoneSeconds, reached)

        NotificationManager.scheduleMilestones(for: habit)
        Haptics.success()
        onSave()
    }
}

/// A rounded section heading with a tinted symbol.
private struct HabitFormHeader: View {
    let title: Text
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            title
                .foregroundStyle(Palette.textPrimary)
        }
        .font(.system(.subheadline, design: .rounded).weight(.bold))
        .textCase(nil)
    }
}

/// Section footnote text, readable on the night background.
private struct HabitFormFooter: View {
    let text: Text

    var body: some View {
        text
            .font(.footnote)
            .foregroundStyle(Palette.textSecondary)
    }
}

private extension View {
    /// Frosted rows with soft separators on the night background.
    func habitFormRowStyle() -> some View {
        listRowBackground(Palette.surface.opacity(0.72))
            .listRowSeparatorTint(Palette.hairline)
    }
}

#Preview {
    NavigationStack {
        HabitFormView(draft: HabitDraft(preset: HabitPreset.all[0]), editing: nil) {}
    }
    .previewEnvironment()
}
