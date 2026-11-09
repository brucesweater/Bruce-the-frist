import SwiftUI
import SwiftData

/// The Today tab: the longest streak as a glowing dawn orb, today's numbers, the daily pledge, missions and the
/// challenge, every streak, and SOS one tap away.
struct HomeView: View {
    @Query(sort: \Habit.sortIndex) private var habits: [Habit]
    @Query(sort: \Pledge.day, order: .reverse) private var pledges: [Pledge]
    @AppStorage(AppSettings.Keys.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    @AppStorage(AppSettings.Keys.didPromptFirstHabit) private var didPromptFirstHabit = false
    @Environment(AppRouter.self) private var router
    @Environment(Store.self) private var store

    @State private var showingAddHabit = false
    @State private var showingPledge = false
    /// Set when "add habit" opened the paywall, so buying Pro carries straight on to adding the habit.
    @State private var addHabitAfterUpgrade = false

    /// Whether the latest pledge belongs to the day containing `date`.
    private func hasPledged(on date: Date) -> Bool {
        guard let latest = pledges.first else { return false }
        return Calendar.current.isDate(latest.day, inSameDayAs: date)
    }

    /// The sky behind Today warms as the longest streak passes more milestones.
    private var skyGlow: Double {
        guard let hero = TodayHeroView.heroHabit(in: habits) else { return 0.2 }
        let elapsed = hero.stats().currentStreak
        let reached = Milestone.all.filter { $0.seconds <= elapsed }.count
        return 0.2 + 0.4 * Double(reached) / Double(Milestone.all.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .dawnScreenBackground(glow: skyGlow)
            .overlay(alignment: .top) {
                StatusBarScrim()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !habits.isEmpty {
                    TodaySOSDock(action: showSOS)
                }
            }
            // Today draws its own header; the title still names the back button on pushed screens.
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Habit.self) { habit in
                HabitDetailView(habit: habit)
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView()
            }
            .sheet(isPresented: $showingPledge) {
                PledgeSheet()
                    .presentationDetents([.medium])
            }
            .onChange(of: router.paywallReason == nil) { _, paywallClosed in
                if paywallClosed { continueAfterPaywall() }
            }
            .onAppear {
                if habits.isEmpty && !didPromptFirstHabit {
                    didPromptFirstHabit = true
                    showingAddHabit = true
                }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 18) {
            TodayHeader(addAction: addHabit)
            if AppModelContainer.isUsingTemporaryStore {
                StorageWarningBanner()
            }
            if habits.isEmpty {
                TodayEmptyState(addAction: addHabit)
            } else {
                dashboard
            }
        }
    }

    @ViewBuilder
    private var dashboard: some View {
        TodayHeroView(habits: habits)
        SavingsBanner(habits: habits, currencyCode: currencyCode)
            .todayScrollReveal()
        // Refreshes each minute so a new day's pledge opens at midnight, even if Today stays on screen.
        TimelineView(.everyMinute) { timeline in
            let pledgedToday = hasPledged(on: timeline.date)
            PledgeCard(
                pledgedToday: pledgedToday,
                streak: StreakCalculator.consecutiveDays(pledges.map(\.day), now: timeline.date)
            ) {
                if !pledgedToday { showingPledge = true }
            }
        }
        .todayScrollReveal()
        MissionsCard()
            .todayScrollReveal()
        ChallengeCard()
            .todayScrollReveal()
        streaksSection
        CoachEntryCard(habit: nil)
            .accessibilityIdentifier("coachEntry")
            .todayScrollReveal()
        GoalsCard()
            .todayScrollReveal()
        TipOfTheDayCard()
            .todayScrollReveal()
    }

    private var streaksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your streaks", systemImage: "flame.fill", tint: Palette.streak)
                .padding(.top, 6)
            ForEach(habits) { habit in
                NavigationLink(value: habit) {
                    HabitCard(habit: habit)
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityIdentifier("habitCard")
                .todayScrollReveal()
            }
        }
    }

    private func showSOS() {
        Haptics.tap()
        router.isShowingSOS = true
    }

    /// Free users track one habit at a time; adding another opens the Pro paywall.
    private func addHabit() {
        if ProLimits.canAddHabit(currentCount: habits.count, isPro: store.isPro) {
            showingAddHabit = true
        } else {
            addHabitAfterUpgrade = true
            router.showPaywall(.moreHabits)
        }
    }

    private func continueAfterPaywall() {
        guard addHabitAfterUpgrade else { return }
        addHabitAfterUpgrade = false
        guard store.isPro else { return }
        Task {
            // Let the paywall finish sliding away before the next sheet comes up.
            try? await Task.sleep(for: .milliseconds(500))
            showingAddHabit = true
        }
    }
}

// MARK: - Header

/// The date, a greeting for the time of day, and the add-habit button.
private struct TodayHeader: View {
    let addAction: () -> Void

    var body: some View {
        // Refreshes each minute so the date and greeting roll over on their own.
        TimelineView(.everyMinute) { context in
            content(at: context.date)
        }
    }

    private func content(at date: Date) -> some View {
        let greeting = TodayGreeting(hour: hour(at: date))
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                } icon: {
                    Image(systemName: greeting.symbol)
                }
                .microLabel(Palette.amber)
                Text(greeting.title)
                    .font(.screenTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(greeting.subtitle)
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            addButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addButton: some View {
        Button(action: addAction) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.amber)
                .frame(width: 44, height: 44)
                .background(Palette.surfaceRaised.opacity(0.8), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("Add habit")
        .accessibilityIdentifier("addHabitButton")
    }

    private func hour(at date: Date) -> Int {
        #if DEBUG
        if let override = UITestSupport.hourOverride {
            return override
        }
        #endif
        return Calendar.current.component(.hour, from: date)
    }
}

private struct TodayGreeting {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let symbol: String

    init(hour: Int) {
        switch hour {
        case 5..<12:
            title = "Good morning"
            subtitle = "One day at a time."
            symbol = "sunrise.fill"
        case 12..<17:
            title = "Good afternoon"
            subtitle = "You've got this."
            symbol = "sun.max.fill"
        case 17..<22:
            title = "Good evening"
            subtitle = "Stay strong tonight."
            symbol = "sunset.fill"
        default:
            title = "Up late?"
            subtitle = "Cravings pass. You'll stay free."
            symbol = "moon.stars.fill"
        }
    }
}

// MARK: - Chrome

/// The SOS button pinned above the tab bar, on a soft fade so the cards scrolling beneath don't look cut off.
private struct TodaySOSDock: View {
    let action: () -> Void

    var body: some View {
        SOSButton(action: action)
            .frame(maxWidth: 640)
            .padding(.horizontal, 16)
            .padding(.top, 26)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background {
                LinearGradient(
                    stops: [
                        .init(color: Palette.night.opacity(0), location: 0),
                        .init(color: Palette.night.opacity(0.8), location: 0.5),
                        .init(color: Palette.night.opacity(0.94), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            }
    }
}

struct SOSButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Craving? Tap for SOS", systemImage: "wind")
        }
        .buttonStyle(PrimaryButtonStyle(gradient: Brand.sos, foreground: .white, glow: Palette.rose))
        .shadow(color: Palette.ember.opacity(0.28), radius: 22, y: 8)
        .accessibilityIdentifier("sosButton")
    }
}

/// Cards ease in and out as they scroll past the edges of the screen (off with Reduce Motion).
private struct TodayScrollReveal: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.scrollTransition { effect, phase in
                effect
                    .opacity(phase.isIdentity ? 1 : 0.55)
                    .scaleEffect(phase.isIdentity ? 1 : 0.96)
            }
        }
    }
}

private extension View {
    func todayScrollReveal() -> some View {
        modifier(TodayScrollReveal())
    }
}

// MARK: - States

/// Shown only if the saved data couldn't be opened, so the user isn't silently losing what they enter.
private struct StorageWarningBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemImage: "exclamationmark.triangle.fill", tint: Palette.ember, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text("Your saved progress couldn't be opened")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text("Please close Unhook completely and open it again. Until then, changes won't be kept.")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassSurface(cornerRadius: 20, tint: Palette.ember, highlighted: true)
        .accessibilityElement(children: .combine)
    }
}

/// Before the first habit: a night sky just before dawn and one clear way to start.
private struct TodayEmptyState: View {
    let addAction: () -> Void

    /// The orb breathes, except in UI test runs (an endless animation keeps the app from ever looking idle).
    private static var breathes: Bool {
        #if DEBUG
        return !UITestSupport.isActive
        #else
        return true
        #endif
    }

    var body: some View {
        VStack(spacing: 20) {
            DawnOrb(progress: 0.1, size: 190, animated: Self.breathes)
                .padding(.vertical, -12)
            VStack(spacing: 10) {
                Text("What do you want to quit?")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Pick a habit to break. Unhook tracks every second, dollar and hour you win back.")
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Start my first streak", action: addAction)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }
}

#Preview {
    HomeView()
        .previewEnvironment()
}
