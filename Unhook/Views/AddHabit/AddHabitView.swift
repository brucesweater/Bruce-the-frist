import SwiftUI

/// Entry point for creating a habit (preset picker, then form) or editing one (form only).
struct AddHabitView: View {
    var editing: Habit? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPreset: HabitPreset?

    var body: some View {
        NavigationStack {
            Group {
                if let editing {
                    HabitFormView(draft: HabitDraft(habit: editing), editing: editing) { dismiss() }
                } else {
                    PresetPickerView { preset in
                        selectedPreset = preset
                    }
                    .navigationDestination(item: $selectedPreset) { preset in
                        HabitFormView(draft: HabitDraft(preset: preset), editing: nil) { dismiss() }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(Palette.amber)
    }
}

/// "New habit": the same glass grid of presets as onboarding, on the night sky. "Something else" starts a custom habit.
struct PresetPickerView: View {
    let onSelect: (HabitPreset) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                HabitPresetGrid { preset in
                    Haptics.selection()
                    onSelect(preset)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollBounceBehavior(.basedOnSize)
        .dawnScreenBackground(glow: 0.2)
        .navigationTitle("New habit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What do you want to quit?")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Pick one to start. You can fine-tune the details next.")
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    AddHabitView()
        .previewEnvironment()
}
