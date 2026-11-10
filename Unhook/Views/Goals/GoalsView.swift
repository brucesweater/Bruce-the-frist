import SwiftUI
import SwiftData

/// Every savings goal: the ones being saved for, in funding order, then the ones already bought.
/// Pushed from the Today screen's goals card.
struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(Store.self) private var store
    @Environment(AppRouter.self) private var router
    @Query(sort: [SortDescriptor(\SavingsGoal.sortIndex), SortDescriptor(\SavingsGoal.createdAt)])
    private var goals: [SavingsGoal]
    @Query(sort: \Habit.sortIndex) private var habits: [Habit]
    @AppStorage(AppSettings.Keys.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode

    @State private var showingNewGoal = false
    @State private var editingGoal: SavingsGoal?
    /// Set while the "bought it" confetti is showing. A new value restarts the burst.
    @State private var celebrationID: UUID?

    private static let rowBackground = Palette.surface.opacity(0.72)

    private var activeGoals: [SavingsGoal] {
        goals.filter { !$0.isRedeemed }
    }

    /// Most recently bought first.
    private var redeemedGoals: [SavingsGoal] {
        goals
            .filter(\.isRedeemed)
            .sorted { ($0.redeemedAt ?? .distantPast) > ($1.redeemedAt ?? .distantPast) }
    }

    var body: some View {
        content
            .dawnScreenBackground(glow: 0.35)
            .navigationTitle("Savings goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingNewGoal) {
                GoalEditorView()
            }
            .sheet(item: $editingGoal) { goal in
                GoalEditorView(goal: goal)
            }
            .overlay {
                if let celebrationID {
                    ConfettiView()
                        .id(celebrationID)
                }
            }
            .overlay(alignment: .top) {
                if celebrationID != nil {
                    celebrationBanner
                }
            }
            .animation(
                reduceMotion ? Animation.easeInOut(duration: 0.2) : Animation.spring(response: 0.4, dampingFraction: 0.8),
                value: celebrationID
            )
    }

    @ViewBuilder
    private var content: some View {
        if goals.isEmpty {
            emptyState
        } else {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                goalList(GoalFundingSnapshot(goals: goals, habits: habits, at: timeline.date))
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !goals.isEmpty {
                EditButton()
            }
            Button(action: addGoal) {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add goal")
        }
    }

    // MARK: List

    private func goalList(_ snapshot: GoalFundingSnapshot) -> some View {
        let active = activeGoals
        let redeemed = redeemedGoals
        return List {
            savingsSection(snapshot)
            Section {
                if active.isEmpty {
                    Button(action: addGoal) {
                        Label("Set a new goal", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Palette.amber)
                    }
                    .listRowBackground(Self.rowBackground)
                } else {
                    ForEach(active) { goal in
                        activeRow(goal, progress: snapshot.progress(for: goal))
                    }
                    .onMove { source, destination in
                        moveGoals(active, from: source, to: destination)
                    }
                    .onDelete { offsets in
                        deleteGoals(at: offsets, in: active)
                    }
                    .listRowBackground(Self.rowBackground)
                    .listRowSeparatorTint(Palette.hairline)
                }
            } header: {
                sectionHeader("Saving for")
            }
            if !redeemed.isEmpty {
                Section {
                    ForEach(redeemed) { goal in
                        redeemedRow(goal)
                    }
                    .onDelete { offsets in
                        deleteGoals(at: offsets, in: redeemed)
                    }
                    .listRowBackground(Self.rowBackground)
                    .listRowSeparatorTint(Palette.hairline)
                } header: {
                    sectionHeader("Redeemed")
                }
            }
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.sectionTitle)
            .foregroundStyle(Palette.textPrimary)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }

    private func savingsSection(_ snapshot: GoalFundingSnapshot) -> some View {
        Section {
            HStack(spacing: 14) {
                IconBadge(systemImage: "banknote.fill", tint: Palette.money, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Saved so far")
                        .microLabel(Palette.money)
                    Text(MoneyFormatter.rounded(snapshot.totalSaved, code: currencyCode))
                        .font(.display(30))
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Group {
                        if snapshot.dailySavings > 0 {
                            Text("\(MoneyFormatter.precise(snapshot.dailySavings, code: currencyCode)) more every day you stay free")
                        } else {
                            Text("Add what a habit cost you per day to start funding your goals.")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
            .listRowBackground(
                ZStack {
                    Self.rowBackground
                    Palette.money.opacity(0.1)
                }
            )
        } footer: {
            Text("Your savings fill goals from the top down. Tap Edit to change the order or remove a goal.")
                .foregroundStyle(Palette.textTertiary)
        }
    }

    private func activeRow(_ goal: SavingsGoal, progress: GoalProgress) -> some View {
        GoalsActiveRow(
            goal: goal,
            progress: progress,
            currencyCode: currencyCode,
            onEdit: { editingGoal = goal },
            onMarkBought: { markBought(goal) }
        )
        .contextMenu {
            Button {
                editingGoal = goal
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            ShareLink(item: GoalShareText.progress(emoji: goal.emoji, title: goal.title, fraction: progress.fraction)) {
                Label("Share progress", systemImage: "square.and.arrow.up")
            }
            if progress.isFunded {
                Button {
                    markBought(goal)
                } label: {
                    Label("Mark as bought", systemImage: "bag.fill")
                }
            }
            Divider()
            Button(role: .destructive) {
                delete(goal)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func redeemedRow(_ goal: SavingsGoal) -> some View {
        GoalsRedeemedRow(goal: goal, currencyCode: currencyCode)
            .contextMenu {
                Button {
                    editingGoal = goal
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button {
                    restore(goal)
                } label: {
                    Label("Not bought yet", systemImage: "arrow.uturn.backward")
                }
                Divider()
                Button(role: .destructive) {
                    delete(goal)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    // MARK: Empty state and celebration

    private var emptyState: some View {
        VStack(spacing: 18) {
            IconBadge(systemImage: "gift.fill", tint: Palette.amber, size: 72)
                .shadow(color: Palette.amber.opacity(0.35), radius: 18)
            VStack(spacing: 8) {
                Text("Reward yourself")
                    .font(.sectionTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Pick something you'd love. The money you no longer spend on your habit pays for it.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Set a savings goal", action: addGoal)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var celebrationBanner: some View {
        Text("You earned this! 🎉")
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(Palette.inkText)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Brand.gradient, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
            .shadow(color: Palette.amber.opacity(0.5), radius: 14, y: 4)
            .padding(.top, 8)
            .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.move(edge: .top).combined(with: .opacity))
            .allowsHitTesting(false)
    }

    // MARK: Actions

    /// Free users save toward one goal at a time; another active goal opens the Pro paywall. While Unhook is
    /// free (`Monetization.isProEnabled` is false) everyone counts as Pro, so this always opens the editor.
    private func addGoal() {
        if ProLimits.canAddGoal(activeCount: activeGoals.count, isPro: store.isPro) {
            showingNewGoal = true
        } else {
            router.showPaywall(.moreGoals)
        }
    }

    private func markBought(_ goal: SavingsGoal) {
        guard !goal.isRedeemed else { return }
        withAnimation(reduceMotion ? nil : Animation.spring(response: 0.4, dampingFraction: 0.8)) {
            goal.redeemedAt = .now
        }
        Haptics.success()
        ReviewPrompter.standard.recordPositiveMoment()

        let id = UUID()
        celebrationID = id
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if celebrationID == id {
                celebrationID = nil
            }
        }
    }

    /// Moves a bought goal back to the top of the list, where it was being funded before.
    private func restore(_ goal: SavingsGoal) {
        let active = activeGoals
        guard ProLimits.canAddGoal(activeCount: active.count, isPro: store.isPro) else {
            router.showPaywall(.moreGoals)
            return
        }
        let firstIndex = active.map(\.sortIndex).min() ?? 0
        withAnimation {
            goal.sortIndex = firstIndex - 1
            goal.redeemedAt = nil
        }
        Haptics.tap()
    }

    /// Rewrites the active goals' sort indexes to match their new order.
    private func moveGoals(_ active: [SavingsGoal], from source: IndexSet, to destination: Int) {
        var reordered = active
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, goal) in reordered.enumerated() where goal.sortIndex != index {
            goal.sortIndex = index
        }
        Haptics.selection()
    }

    private func deleteGoals(at offsets: IndexSet, in list: [SavingsGoal]) {
        for index in offsets where list.indices.contains(index) {
            context.delete(list[index])
        }
    }

    private func delete(_ goal: SavingsGoal) {
        withAnimation {
            context.delete(goal)
        }
    }
}

/// A goal being saved for: tap to edit, and a "Mark as bought" button once it's fully funded.
private struct GoalsActiveRow: View {
    let goal: SavingsGoal
    let progress: GoalProgress
    let currencyCode: String
    let onEdit: () -> Void
    let onMarkBought: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onEdit) {
                GoalSummaryView(emoji: goal.emoji, title: goal.title, progress: progress, currencyCode: currencyCode)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit goal")

            if progress.isFunded {
                Button(action: onMarkBought) {
                    Label("Mark as bought", systemImage: "bag.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Palette.inkText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Brand.gradient, in: Capsule())
                        .shadow(color: Palette.amber.opacity(0.4), radius: 10, y: 4)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}

/// A goal the user already bought with their savings.
private struct GoalsRedeemedRow: View {
    let goal: SavingsGoal
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(goal.emoji)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                    if let redeemedAt = goal.redeemedAt {
                        Text("Bought \(redeemedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                Spacer(minLength: 0)
                Text(GoalMoney.price(goal.cost, code: currencyCode))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)

            ShareLink(item: GoalShareText.bought(emoji: goal.emoji, title: goal.title)) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Palette.amber)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Share")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        GoalsView()
    }
    .previewEnvironment()
}
