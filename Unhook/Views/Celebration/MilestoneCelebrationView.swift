import SwiftUI

/// The full-screen "milestone unlocked" moment shown when the app opens after a streak checkpoint: a sunrise
/// bursting behind the habit's orb, the win in dawn gold, and the numbers behind it.
/// Sharing from the high point turns a personal win into word of mouth.
struct MilestoneCelebrationView: View {
    let celebration: MilestoneCelebration
    let onDone: () -> Void

    @AppStorage(AppSettings.Keys.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 38

    @State private var hasAppeared = false
    @State private var showsDetails = false
    @State private var showingShare = false

    init(celebration: MilestoneCelebration, onDone: @escaping () -> Void) {
        self.celebration = celebration
        self.onDone = onDone
    }

    private var habit: Habit { celebration.habit }
    private var milestone: Milestone { celebration.milestone }

    var body: some View {
        ZStack {
            CelebrationBackground()

            GeometryReader { proxy in
                ScrollView {
                    hero
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .safeAreaInset(edge: .bottom) {
                actions
            }

            // Falls with motion; with Reduce Motion it only fades in and out.
            ConfettiView()
        }
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showingShare) {
            ShareProgressSheet(habit: habit)
        }
        .onAppear(perform: celebrate)
    }

    // MARK: Content

    private var hero: some View {
        VStack(spacing: 26) {
            CelebrationBadge(
                emoji: habit.emoji,
                symbol: milestone.symbol,
                dawn: dawnLevel,
                isVisible: hasAppeared || reduceMotion
            )

            VStack(spacing: 22) {
                headline
                CelebrationStatsRow(stats: statItems)
                Text(CelebrationCenter.encouragement(for: milestone))
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(showsDetails || reduceMotion ? 1 : 0)
            .offset(y: showsDetails || reduceMotion ? 0 : 18)
        }
    }

    private var headline: some View {
        VStack(spacing: 12) {
            Text("MILESTONE UNLOCKED")
                .font(.caption.weight(.heavy))
                .tracking(2)
                .foregroundStyle(Palette.sun)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Palette.sun.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.sun.opacity(0.3), lineWidth: 1))
            Text("\(milestone.title) free from \(habit.name)!")
                .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Brand.dawn)
                .shadow(color: Palette.ember.opacity(0.35), radius: 16, y: 4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.tap()
                showingShare = true
            } label: {
                Label("Share my progress", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Keep going") {
                Haptics.tap()
                onDone()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background {
            // Lets long content (large Dynamic Type) scroll softly under the buttons.
            LinearGradient(
                colors: [CelebrationBackground.fadeColor.opacity(0), CelebrationBackground.fadeColor.opacity(0.8)],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }

    /// Bigger milestones show more sunrise on the orb: from early light at 1 hour to full gold at 5 years.
    private var dawnLevel: Double {
        let index = Milestone.all.firstIndex(of: milestone) ?? 0
        let fraction = Double(index + 1) / Double(max(Milestone.all.count, 1))
        return 0.35 + 0.65 * fraction
    }

    /// Money and time when the habit tracks them; otherwise cravings beaten or the streak itself.
    private var statItems: [CelebrationStat] {
        let stats = habit.stats()
        var items: [CelebrationStat] = []
        if stats.moneySaved >= 1 {
            items.append(CelebrationStat(
                id: "money",
                value: MoneyFormatter.rounded(stats.moneySaved, code: currencyCode),
                title: String(localized: "Money saved"),
                systemImage: "banknote.fill",
                tint: Palette.money
            ))
        }
        if stats.minutesReclaimed >= 1 {
            items.append(CelebrationStat(
                id: "time",
                value: DurationFormatter.minutes(stats.minutesReclaimed),
                title: String(localized: "Time reclaimed"),
                systemImage: "clock.fill",
                tint: Palette.time
            ))
        }
        let beaten = habit.resistedUrgeCount
        if items.count < 2 && beaten > 0 {
            items.append(CelebrationStat(
                id: "cravings",
                value: beaten.formatted(),
                title: String(localized: "Cravings beaten"),
                systemImage: "shield.lefthalf.filled",
                tint: Palette.cravings
            ))
        }
        if items.isEmpty {
            items.append(CelebrationStat(
                id: "streak",
                value: DurationFormatter.compact(stats.currentStreak),
                title: String(localized: "Free for"),
                systemImage: "timer",
                tint: Palette.streak
            ))
        }
        return items
    }

    // MARK: Actions

    private func celebrate() {
        // Presenting the share sheet and coming back must not replay the moment.
        guard !hasAppeared else { return }
        Haptics.success()
        withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.15)) {
            hasAppeared = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.45)) {
            showsDetails = true
        }
    }
}

#Preview {
    MilestoneCelebrationView(
        celebration: MilestoneCelebration(habit: PreviewData.sampleHabit, milestone: Milestone.all[4])
    ) {}
    .previewEnvironment()
}
