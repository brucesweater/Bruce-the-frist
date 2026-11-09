import SwiftUI
import SwiftData

struct HabitDetailView: View {
    let habit: Habit

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @AppStorage(AppSettings.Keys.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode

    @State private var showingSOS = false
    @State private var showingRelapse = false
    @State private var showingEdit = false
    @State private var showingShare = false
    @State private var confirmingDelete = false
    @State private var confirmingUndoSlip = false

    var body: some View {
        content
            .dawnScreenBackground(glow: backgroundGlow)
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) { actionBar }
            .fullScreenCover(isPresented: $showingSOS) {
                SOSView(habit: habit)
            }
            .sheet(isPresented: $showingRelapse) {
                RelapseSheet(habit: habit)
            }
            .sheet(isPresented: $showingEdit) {
                AddHabitView(editing: habit)
            }
            .sheet(isPresented: $showingShare) {
                ShareProgressSheet(habit: habit)
            }
            .confirmationDialog("Delete \(habit.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete habit and history", role: .destructive, action: deleteHabit)
            } message: {
                Text("This removes the streak, milestones and history for this habit. It can't be undone.")
            }
            .confirmationDialog("Undo this slip?", isPresented: $confirmingUndoSlip, titleVisibility: .visible) {
                Button("Undo slip", action: undoLatestSlip)
            } message: {
                Text("Your streak picks up as if the slip never happened.")
            }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 18) {
                HabitHeroView(habit: habit)
                statsSection
                RecoveryTimelineView(habit: habit)
                reasonsCard
                CoachEntryCard(habit: habit)
                MilestoneListView(habit: habit)
                historyCard
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    /// The sky warms as the streak grows: a hint of dawn on day one, close to sunrise after a few months.
    private var backgroundGlow: Double {
        let days = max(habit.stats().currentStreak / 86_400, 0)
        return 0.18 + 0.5 * min(1, log1p(days) / log1p(120))
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HabitDetailHeader(habit: habit)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showingShare = true
                } label: {
                    Label("Share progress", systemImage: "square.and.arrow.up")
                }
                Button {
                    showingEdit = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: Self.menuSymbol)
            }
            .accessibilityLabel("More options")
        }
    }

    /// iOS 26 draws toolbar buttons on their own glass circle, so the plain glyph avoids a circle in a circle.
    private static var menuSymbol: String {
        if #available(iOS 26.0, *) {
            return "ellipsis"
        }
        return "ellipsis.circle"
    }

    // MARK: Action bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                showingRelapse = true
            } label: {
                Label("I slipped", systemImage: "arrow.uturn.backward")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .background(Palette.surfaceRaised.opacity(0.6), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableCardStyle())
            .layoutPriority(1)
            .accessibilityHint("Log a slip and start a new streak")

            Button {
                Haptics.tap()
                showingSOS = true
            } label: {
                Label("SOS", systemImage: "wind")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
            }
            .buttonStyle(PrimaryButtonStyle(gradient: Brand.sos, foreground: .white, glow: Palette.rose))
            .accessibilityHint("Opens a guided breathing exercise for this craving")
            .accessibilityIdentifier("detailSOSButton")
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background {
            LinearGradient(colors: [Palette.ink.opacity(0), Palette.ink.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                .padding(.top, -20)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }

    // MARK: Stats

    private var statsSection: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            HabitDetailStatsGrid(habit: habit, stats: habit.stats(at: timeline.date), currencyCode: currencyCode)
        }
    }

    // MARK: Reasons

    private var reasonsCard: some View {
        Card(title: "Why I'm quitting", systemImage: "heart.fill", tint: Palette.rose) {
            if habit.reasons.isEmpty {
                Button {
                    showingEdit = true
                } label: {
                    Label {
                        Text("Add your reasons. They show up on the SOS screen when a craving hits.")
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Palette.amber)
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(habit.reasons.enumerated()), id: \.offset) { _, reason in
                        Label {
                            Text(reason)
                                .foregroundStyle(Palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Palette.amber)
                                .shadow(color: Palette.amber.opacity(0.45), radius: 5)
                        }
                    }
                }
            }
        }
    }

    // MARK: History

    private struct HistoryItem: Identifiable {
        let id: PersistentIdentifier
        let date: Date
        let title: String
        let detail: String
        let systemImage: String
        let tint: Color
        var isLatestSlip = false
    }

    private var historyItems: [HistoryItem] {
        let latestSlip = habit.latestRelapse
        let urgeItems = habit.urges.map { urge in
            HistoryItem(
                id: urge.persistentModelID,
                date: urge.date,
                title: urge.resisted ? String(localized: "Beat a craving") : String(localized: "Logged a craving"),
                detail: Self.cravingDetail(trigger: urge.trigger, intensity: urge.intensity, note: urge.note),
                systemImage: "shield.lefthalf.filled",
                tint: Palette.cravings
            )
        }
        let relapseItems = habit.relapses.map { relapse in
            HistoryItem(
                id: relapse.persistentModelID,
                date: relapse.date,
                title: String(localized: "Slipped after \(DurationFormatter.compact(relapse.streakSeconds))"),
                detail: Self.cravingDetail(trigger: relapse.trigger, intensity: 0, note: relapse.note),
                systemImage: "arrow.uturn.backward",
                // Slips stay quiet: a neutral tint, never alarm red.
                tint: Palette.textSecondary,
                isLatestSlip: relapse === latestSlip
            )
        }
        return (urgeItems + relapseItems).sorted { $0.date > $1.date }
    }

    /// "😤 Stress · 4/5 · note", leaving out whatever wasn't logged.
    private static func cravingDetail(trigger: CravingTrigger?, intensity: Int, note: String) -> String {
        var parts: [String] = []
        if let trigger {
            parts.append("\(trigger.emoji) \(trigger.title)")
        }
        if intensity > 0 {
            parts.append(String(localized: "\(intensity)/5 strength"))
        }
        if !note.isEmpty {
            parts.append(note)
        }
        return parts.joined(separator: " · ")
    }

    private var historyCard: some View {
        Card(title: "History", systemImage: "clock.arrow.circlepath", tint: Palette.time) {
            let items = historyItems
            if items.isEmpty {
                Text("Cravings you beat and slips you bounce back from will show up here.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 14) {
                    ForEach(items.prefix(20)) { item in
                        HistoryRow(item: item, onUndo: item.isLatestSlip ? { confirmingUndoSlip = true } : nil)
                    }
                }
            }
        }
    }

    private struct HistoryRow: View {
        let item: HistoryItem
        /// Set only for the most recent slip, which can be taken back.
        let onUndo: (() -> Void)?

        var body: some View {
            HStack(spacing: 12) {
                IconBadge(systemImage: item.systemImage, tint: item.tint, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.textPrimary)
                    if !item.detail.isEmpty {
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    Text(item.date, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                    if let onUndo {
                        Button(action: onUndo) {
                            Text("Undo")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Palette.amber)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Palette.amber.opacity(0.14), in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Undo this slip")
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func undoLatestSlip() {
        habit.undoLatestRelapse(in: context)
        NotificationManager.scheduleMilestones(for: habit)
        Haptics.success()
    }

    private func deleteHabit() {
        // Pop back first so this screen never renders a deleted model.
        let habit = self.habit
        let context = self.context
        NotificationManager.cancelMilestones(for: habit.uuid)
        if router.celebration?.habit === habit {
            router.celebration = nil
        }
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            context.delete(habit)
            try? context.save()
        }
    }
}

// MARK: - Header

/// The compact title in the navigation bar: the habit's emoji in a soft glass circle and its name.
private struct HabitDetailHeader: View {
    let habit: Habit

    var body: some View {
        HStack(spacing: 8) {
            Text(habit.emoji)
                .font(.system(size: 16))
                .frame(width: 30, height: 30)
                .background(Circle().fill(habit.theme.accent.opacity(0.2)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .accessibilityHidden(true)
            Text(habit.name)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Stats grid

/// The wins in role colors, two to a row. Slips are counted too, but quietly: a muted tile that completes
/// the last row, or a single line under the grid, so setbacks never get the same billing as wins.
private struct HabitDetailStatsGrid: View {
    let habit: Habit
    let stats: HabitStats
    let currencyCode: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Two to a row, or one at accessibility sizes so the labels have room.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    private var showsUnits: Bool {
        habit.unitsPerDay > 0
    }

    private var unitsTitle: LocalizedStringKey {
        let unit = habit.unitName.isEmpty ? String(localized: "Units") : habit.unitName.capitalized
        return "\(unit) avoided"
    }

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                StatTile(
                    title: "Money saved",
                    value: MoneyFormatter.rounded(stats.moneySaved, code: currencyCode),
                    systemImage: "banknote.fill",
                    tint: Palette.money
                )
                StatTile(
                    title: "Time reclaimed",
                    value: DurationFormatter.minutes(stats.minutesReclaimed),
                    systemImage: "clock.fill",
                    tint: Palette.time
                )
                if showsUnits {
                    StatTile(
                        title: unitsTitle,
                        value: stats.unitsAvoided.clampedWholeNumber.formatted(),
                        systemImage: "xmark.circle.fill",
                        tint: Palette.units
                    )
                }
                StatTile(
                    title: "Best streak",
                    value: DurationFormatter.compact(stats.bestStreak),
                    systemImage: "trophy.fill",
                    tint: Palette.celebrate
                )
                StatTile(
                    title: "Cravings beaten",
                    value: "\(habit.resistedUrgeCount)",
                    systemImage: "shield.lefthalf.filled",
                    tint: Palette.cravings
                )
                // Five wins leave one open cell; a muted slips tile fills it.
                if showsUnits {
                    HabitDetailSlipsTile(count: habit.relapses.count)
                }
            }
            if !showsUnits {
                HabitDetailSlipsLine(count: habit.relapses.count)
            }
        }
    }
}

/// The slip count as a dimmed tile, sized like a stat tile so the grid stays even.
private struct HabitDetailSlipsTile: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IconBadge(systemImage: "arrow.uturn.backward", tint: Palette.textTertiary, size: 30)
            Text(count, format: .number)
                .font(.display(24))
                .foregroundStyle(Palette.textSecondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("Slips")
                .microLabel()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Palette.surface.opacity(0.3), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// The slip count as one quiet line under the stats.
private struct HabitDetailSlipsLine: View {
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.uturn.backward")
                .font(.caption.weight(.bold))
                .accessibilityHidden(true)
            message
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(Palette.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var message: some View {
        if count == 0 {
            Text("No slips logged")
        } else if count == 1 {
            Text("1 slip logged. Your clean time stays banked.")
        } else {
            Text("\(count) slips logged. Your clean time stays banked.")
        }
    }
}

#Preview {
    NavigationStack {
        HabitDetailView(habit: PreviewData.sampleHabit)
    }
    .previewEnvironment()
}
