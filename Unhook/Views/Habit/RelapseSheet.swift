import SwiftUI
import SwiftData

/// Recording a slip, written to be kind: shame drives people away, compassion brings them back.
struct RelapseSheet: View {
    let habit: Habit

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var note = ""
    @State private var trigger: CravingTrigger?

    private var savedProgress: TimeInterval {
        habit.stats(at: date).lifetimeClean
    }

    private static let rowBackground = Palette.surface.opacity(0.72)

    var body: some View {
        NavigationStack {
            Form {
                introSection
                dateSection
                triggerSection
                noteSection
            }
            .dawnScreenBackground(glow: 0.3)
            .tint(Palette.amber)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Log a slip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { confirmBar }
        }
    }

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                IconBadge(systemImage: "sunrise.fill", tint: Palette.amber, size: 40)
                Text("A slip isn't the end. Your earlier clean time stays banked, and a new streak starts now.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Chip(text: Text("\(DurationFormatter.compact(savedProgress)) of clean time banked"), tint: Palette.mint)
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
        }
        .listRowBackground(Self.rowBackground)
    }

    private var dateSection: some View {
        Section {
            DatePicker("Date", selection: $date, in: min(habit.streakStart, .now)...Date.now)
        } header: {
            Text("When did it happen?")
        }
        .listRowBackground(Self.rowBackground)
        .listRowSeparatorTint(Palette.hairline)
    }

    private var triggerSection: some View {
        Section {
            CravingTriggerPicker(selection: $trigger, tint: habit.theme.gradient)
                .padding(.vertical, 6)
        } header: {
            Text("What set it off?")
        } footer: {
            Text("Optional. Spotting your triggers is the fastest way to beat them next time.")
        }
        .listRowBackground(Self.rowBackground)
    }

    private var noteSection: some View {
        Section {
            TextField("Where you were, how you felt…", text: $note, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Text("Anything else? (optional)")
        } footer: {
            if let url = CoachSafety.helplineURL {
                Link(destination: url) {
                    Text("Feeling really low? Find a free helpline.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.amber)
                }
                .padding(.top, 6)
            }
        }
        .listRowBackground(Self.rowBackground)
    }

    private var confirmBar: some View {
        Button(action: logSlip) {
            Text("Log slip and start fresh")
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            LinearGradient(colors: [Palette.ink.opacity(0), Palette.ink.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }

    private func logSlip() {
        habit.recordRelapse(
            at: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            trigger: trigger,
            in: context
        )
        NotificationManager.scheduleMilestones(for: habit)
        Haptics.warning()
        dismiss()
    }
}

#Preview {
    RelapseSheet(habit: PreviewData.sampleHabit)
        .previewEnvironment()
}
