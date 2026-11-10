import SwiftUI

/// "What do you want to quit?": one tap picks a preset and moves on.
struct OnboardingHabitStep: View {
    let selectedPresetID: String?
    let onSelect: (HabitPreset) -> Void

    var body: some View {
        OnboardingStepLayout(
            title: Text("What do you want to quit?"),
            subtitle: Text("Start with the one that matters most right now.")
        ) {
            HabitPresetGrid(selectedPresetID: selectedPresetID, onSelect: onSelect)
        }
    }
}

#Preview {
    ZStack {
        DawnBackground(glow: 0.15)
        OnboardingHabitStep(selectedPresetID: "vaping") { _ in }
    }
    .environment(\.colorScheme, .dark)
    .previewEnvironment()
}
