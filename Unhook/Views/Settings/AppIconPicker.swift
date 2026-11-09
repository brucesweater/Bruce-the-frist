import SwiftUI
import UIKit

/// A grid of home-screen icons. Every icon is free.
struct AppIconPicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 60

    @State private var selection: AppIconOption = .standard
    /// The icon being switched to, while iOS applies it.
    @State private var pendingOption: AppIconOption?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if UIApplication.shared.supportsAlternateIcons {
                iconGrid
            } else {
                Text("This device can't change Unhook's icon.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .onAppear {
            syncSelection()
        }
        .alert("Couldn't change the icon", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var iconGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(AppIconOption.allCases) { option in
                iconButton(for: option)
            }
        }
        .padding(.vertical, 8)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75), value: selection)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: iconSize + 16), spacing: 12)]
    }

    // MARK: Cells

    private func iconButton(for option: AppIconOption) -> some View {
        let isSelected = option == selection
        return Button {
            select(option)
        } label: {
            VStack(spacing: 8) {
                iconImage(for: option, isSelected: isSelected)
                Text(option.title)
                    .font(.system(.caption, design: .rounded).weight(isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Palette.textPrimary : Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        // Plain style keeps each icon its own tap target inside the Form row.
        .buttonStyle(.plain)
        .disabled(pendingOption != nil)
        .accessibilityValue(isSelected ? String(localized: "Current icon") : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func iconImage(for option: AppIconOption, isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous)
        return Image(option.previewImageName)
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(Color.white.opacity(isSelected ? 0 : 0.12), lineWidth: 1)
            }
            .padding(4)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: iconSize * 0.22 + 4, style: .continuous)
                        .strokeBorder(Brand.gradient, lineWidth: 2.5)
                }
            }
            .shadow(color: Palette.amber.opacity(isSelected ? 0.45 : 0), radius: 12)
            .overlay {
                if pendingOption == option {
                    ProgressView()
                        .tint(.white)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isSelected {
                    checkmarkBadge
                        .offset(x: 4, y: 4)
                }
            }
            .scaleEffect(isSelected ? 1.04 : 1)
            .accessibilityHidden(true)
    }

    private var checkmarkBadge: some View {
        Image(systemName: "checkmark")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(Palette.inkText)
            .padding(5)
            .background(Brand.gradient, in: Circle())
            .overlay(Circle().strokeBorder(Palette.surface, lineWidth: 2))
    }

    // MARK: State

    private var isShowingError: Binding<Bool> {
        Binding {
            errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                errorMessage = nil
            }
        }
    }

    private func syncSelection() {
        selection = AppIconOption(alternateIconName: UIApplication.shared.alternateIconName)
    }

    // MARK: Actions

    private func select(_ option: AppIconOption) {
        guard option != selection, pendingOption == nil else { return }
        Haptics.selection()
        pendingOption = option
        Task { await apply(option) }
    }

    private func apply(_ option: AppIconOption) async {
        do {
            try await UIApplication.shared.setAlternateIconName(option.alternateIconName)
            selection = option
        } catch {
            errorMessage = error.localizedDescription
            syncSelection()
        }
        pendingOption = nil
    }
}

#Preview {
    Form {
        Section("App icon") {
            AppIconPicker()
        }
        .listRowBackground(Palette.surface.opacity(0.72))
    }
    .dawnScreenBackground()
    .previewEnvironment()
}
