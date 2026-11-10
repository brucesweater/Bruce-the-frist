import SwiftUI

/// The habit presets as a grid of glass tiles: each habit's emoji on a soft glow in its color, its name and a thin
/// accent line. Used by onboarding and by "New habit". Tapping a tile calls `onSelect`.
struct HabitPresetGrid: View {
    let selectedPresetID: String?
    let onSelect: (HabitPreset) -> Void

    @ScaledMetric(relativeTo: .body) private var minimumTileWidth: CGFloat = 100

    init(selectedPresetID: String? = nil, onSelect: @escaping (HabitPreset) -> Void) {
        self.selectedPresetID = selectedPresetID
        self.onSelect = onSelect
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: min(minimumTileWidth, 160)), spacing: 12)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(HabitPreset.all) { preset in
                tile(for: preset)
            }
        }
    }

    private func tile(for preset: HabitPreset) -> some View {
        let isSelected = preset.id == selectedPresetID
        return Button {
            onSelect(preset)
        } label: {
            HabitPresetTile(preset: preset, isSelected: isSelected)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel(preset.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// One habit preset. A selected tile glows with a warm outline and a check mark.
struct HabitPresetTile: View {
    let preset: HabitPreset
    let isSelected: Bool

    @ScaledMetric(relativeTo: .title) private var emojiSize: CGFloat = 34

    init(preset: HabitPreset, isSelected: Bool = false) {
        self.preset = preset
        self.isSelected = isSelected
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(preset.emoji)
                .font(.system(size: emojiSize))
                .frame(minWidth: 52, minHeight: 52)
                .background {
                    Circle()
                        .fill(RadialGradient(
                            colors: [preset.theme.accent.opacity(isSelected ? 0.5 : 0.26), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 32
                        ))
                }
            Text(preset.title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Capsule()
                .fill(preset.theme.gradient)
                .frame(width: isSelected ? 34 : 22, height: 3)
                .shadow(color: preset.theme.accent.opacity(0.7), radius: isSelected ? 6 : 3)
        }
        .frame(maxWidth: .infinity, minHeight: 104)
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onboardingPanel(cornerRadius: 22, isHighlighted: isSelected)
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Palette.inkText, Palette.sun)
                    .padding(8)
            }
        }
    }
}

#Preview {
    ScrollView {
        HabitPresetGrid(selectedPresetID: "vaping") { _ in }
            .padding(20)
    }
    .dawnScreenBackground()
    .environment(\.colorScheme, .dark)
}
