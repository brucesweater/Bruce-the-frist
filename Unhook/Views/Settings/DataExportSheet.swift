import SwiftUI

/// The files made by "Export my data".
struct DataExportFiles: Identifiable {
    /// The complete JSON export.
    let json: URL
    /// The same history as a spreadsheet timeline, when it could be written.
    let csv: URL?

    var id: URL { json }
}

/// Shown after "Export my data": what's in the export and buttons to share or save it through the share sheet.
struct DataExportSheet: View {
    let files: DataExportFiles

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    fileRow
                    shareButtons
                }
                .padding(24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .dawnScreenBackground(glow: 0.45)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle.weight(.semibold))
                .imageScale(.large)
                .foregroundStyle(Brand.gradient)
                .shadow(color: Palette.amber.opacity(0.5), radius: 16)
                .accessibilityHidden(true)
            Text("Your data is ready")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Every habit, slip, craving, pledge, savings goal, daily mission and 30-Day Reset step in one file. It stays on your device until you choose where to send it.")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var fileRow: some View {
        HStack(spacing: 12) {
            IconBadge(systemImage: "doc.text.fill", tint: Palette.sky, size: 34)
            Text(files.json.lastPathComponent)
                .font(.footnote.monospaced())
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .glassSurface(cornerRadius: 18)
        .accessibilityElement(children: .combine)
    }

    private var shareButtons: some View {
        VStack(spacing: 12) {
            ShareLink(item: files.json) {
                Label("Share or save file", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryButtonStyle())

            if let csv = files.csv {
                ShareLink(item: csv) {
                    Label("Spreadsheet version (CSV)", systemImage: "tablecells")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}

#Preview {
    DataExportSheet(files: DataExportFiles(
        json: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Unhook-Export-2026-10-24.json"),
        csv: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Unhook-Export-2026-10-24.csv")
    ))
    .previewEnvironment()
}
