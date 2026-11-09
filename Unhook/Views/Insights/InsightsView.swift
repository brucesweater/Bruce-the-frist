import SwiftUI
import SwiftData

/// The Progress tab, told as a story: who you're becoming (your rank), your week, twelve weeks of clean days,
/// what you've unlocked, the patterns behind your cravings and mood, and everything you've gained so far.
struct InsightsView: View {
    @Query(sort: \Habit.sortIndex) private var habits: [Habit]
    @Query(sort: \Urge.date) private var urges: [Urge]
    @Query(sort: \Pledge.day) private var pledges: [Pledge]
    @AppStorage(AppSettings.Keys.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                content(at: timeline.date)
            }
            // The screen draws its own large header, so the bar itself stays out of the way. The title is kept for
            // accessibility. (A custom title in the bar would get a glass capsule on iOS 26.)
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            AchievementTracker.shared.record(achievements(at: .now))
        }
        .onDisappear {
            AchievementTracker.shared.markAllSeen()
        }
    }

    private func content(at now: Date) -> some View {
        let cleanDays = CleanDays(habits: habits.map(CleanDaysHabit.init(habit:)), now: now)
        let currentAchievements = achievements(at: now)
        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                RankCard()
                weekSection(cleanDays, now: now)
                calendarSection(cleanDays)
                achievementsSection(currentAchievements)
                cravingsSection(now: now)
                TriggerInsightsCard()
                moodSection(now: now)
                totalsSection(now: now)
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .dawnScreenBackground(glow: glow(for: cleanDays))
        .overlay(alignment: .top) {
            StatusBarScrim()
        }
        .onChange(of: currentAchievements.filter(\.isUnlocked).map(\.id)) { _, _ in
            AchievementTracker.shared.record(currentAchievements)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Progress")
                .font(.screenTitle)
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Look how far you've come.")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The more of the last twelve weeks were clean, the warmer the sky.
    private func glow(for cleanDays: CleanDays) -> Double {
        let total = max(cleanDays.days.count, 1)
        return 0.2 + 0.45 * Double(cleanDays.cleanDayCount) / Double(total)
    }

    // MARK: This week

    private func weekSection(_ cleanDays: CleanDays, now: Date) -> some View {
        let beaten = CleanDays.count(urges.filter(\.resisted).map(\.date), inLast: 7, now: now)
        let pledged = CleanDays.count(pledges.map { StoredDay.localStart(of: $0.day) }, inLast: 7, now: now)
        // Three across leaves each label about 80 pt, so from xxLarge text "CRAVINGS BEATEN" would break mid-word.
        // Stack the tiles at those sizes instead.
        let stacked = dynamicTypeSize >= .xxLarge
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "This week", systemImage: "calendar", tint: Palette.amber, trailing: Text("Last 7 days"))
            layout {
                InsightsWeekTile(title: "Clean days", value: cleanDays.cleanDays(inLast: 7), systemImage: "flame.fill", tint: Palette.streak)
                InsightsWeekTile(title: "Cravings beaten", value: beaten, systemImage: "shield.lefthalf.filled", tint: Palette.cravings)
                InsightsWeekTile(title: "Pledges", value: pledged, systemImage: "hand.raised.fill", tint: Palette.celebrate)
            }
            // Equal tile heights only matter side by side.
            .fixedSize(horizontal: false, vertical: !stacked)
        }
    }

    // MARK: Clean days

    private func calendarSection(_ cleanDays: CleanDays) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Clean days", systemImage: "sun.horizon.fill", tint: Palette.amber, trailing: Text("Last 12 weeks"))
            CleanDaysCalendar(model: cleanDays)
        }
    }

    // MARK: Achievements

    private func achievements(at now: Date) -> [Achievement] {
        let totals = HabitTotals(habits: habits, at: now)
        let input = AchievementInput(
            habitCount: habits.count,
            bestStreak: totals.bestStreak,
            cravingsBeaten: urges.filter(\.resisted).count,
            moneySaved: totals.moneySaved,
            currencyCode: currencyCode,
            pledgeStreak: StreakCalculator.consecutiveDays(pledges.map { StoredDay.localStart(of: $0.day) }, now: now),
            totalPledges: pledges.count
        )
        return Achievement.evaluate(input)
    }

    private func achievementsSection(_ achievements: [Achievement]) -> some View {
        // Same rule as XPSummaryReader: a badge that ever unlocked stays earned, so a lapsed pledge streak, a deleted
        // habit or a lower daily cost never locks it again, and the grid, this count and the Rank card agree.
        let everUnlocked = AchievementTracker.shared.unlockedIDs
        let shown = achievements.map {
            Achievement(id: $0.id, title: $0.title, detail: $0.detail, symbol: $0.symbol, theme: $0.theme,
                        isUnlocked: $0.isUnlocked || everUnlocked.contains($0.id))
        }
        let unlocked = shown.filter(\.isUnlocked).count
        let columns = [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 150 : 100), spacing: 12)]
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Achievements", systemImage: "rosette", tint: Palette.sun, trailing: Text("\(unlocked) of \(shown.count)"))
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(shown) { achievement in
                    InsightsAchievementMedallion(
                        achievement: achievement,
                        isNew: AchievementTracker.shared.isNew(achievement.id)
                    )
                }
            }
        }
    }

    // MARK: Charts

    private func cravingsSection(now: Date) -> some View {
        let data = DailyCounts.make(from: urges.filter(\.resisted).map(\.date), days: 14, now: now)
        let total = data.reduce(0) { $0 + $1.count }
        return InsightsSection(
            title: "Cravings beaten",
            systemImage: "shield.lefthalf.filled",
            tint: Palette.cravings,
            trailing: Text("Last 14 days")
        ) {
            if total == 0 {
                InsightsPlaceholder(text: "Tap SOS when a craving hits. Every one you beat shows up here.")
            } else {
                InsightsHeadline(
                    value: Text(total, format: .number),
                    label: Text("beaten in the last two weeks. Every one counts."),
                    tint: Palette.cravings
                )
                InsightsCravingsChart(data: data)
            }
        }
    }

    private func moodSection(now: Date) -> some View {
        let cutoff = CleanDays.firstDay(ofLast: 30, now: now)
        let recent = pledges.filter { StoredDay.localStart(of: $0.day) >= cutoff }
        return InsightsSection(
            title: "Mood",
            systemImage: "face.smiling",
            tint: Palette.sun,
            trailing: Text("Last 30 days")
        ) {
            if recent.count < 2 {
                InsightsPlaceholder(text: "Take your daily pledge to see how your mood lifts over time.")
            } else {
                moodHeadline(recent)
                InsightsMoodChart(pledges: recent)
            }
        }
    }

    private func moodHeadline(_ recent: [Pledge]) -> some View {
        let average = Double(recent.reduce(0) { $0 + $1.mood }) / Double(max(recent.count, 1))
        let emoji = MoodScale.emoji(for: Int(average.rounded()))
        return InsightsHeadline(
            value: Text(average, format: .number.precision(.fractionLength(1))),
            label: Text("average mood \(emoji)"),
            tint: Palette.sun
        )
    }

    // MARK: All time

    private func totalsSection(now: Date) -> some View {
        let totals = HabitTotals(habits: habits, at: now)
        let beaten = urges.filter(\.resisted).count
        // One tile per row at accessibility sizes so the labels have room.
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "All time", systemImage: "sparkles", tint: Palette.mint)
            LazyVGrid(columns: columns, spacing: 12) {
                StatTile(title: "Total saved", value: MoneyFormatter.rounded(totals.moneySaved, code: currencyCode), systemImage: "banknote.fill", tint: Palette.money)
                StatTile(title: "Time reclaimed", value: DurationFormatter.minutes(totals.minutesReclaimed), systemImage: "clock.fill", tint: Palette.time)
                StatTile(title: "Cravings beaten", value: beaten.formatted(), systemImage: "shield.lefthalf.filled", tint: Palette.cravings)
                StatTile(title: "Longest streak", value: DurationFormatter.compact(totals.bestStreak), systemImage: "trophy.fill", tint: Palette.streak)
            }
        }
    }
}

/// Whether the Progress header is still on screen (its bottom edge below the top of the scroll view).
/// One number from the last seven days, in the style of `StatTile` but with room for a two-line label.
private struct InsightsWeekTile: View {
    let title: LocalizedStringKey
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IconBadge(systemImage: systemImage, tint: tint, size: 30)
            Text(value, format: .number)
                .font(.display(26))
                .foregroundStyle(Palette.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(title)
                .microLabel()
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .glassSurface(cornerRadius: 20, tint: tint)
        .accessibilityElement(children: .combine)
    }
}

/// An achievement as a glass medallion: unlocked ones glow in their colors, locked ones wait behind a lock.
private struct InsightsAchievementMedallion: View {
    let achievement: Achievement
    let isNew: Bool

    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 58

    var body: some View {
        VStack(spacing: 10) {
            medallion
            VStack(spacing: 3) {
                Text(achievement.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(achievement.isUnlocked ? Palette.textPrimary : Palette.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                Text(achievement.detail)
                    .font(.caption2)
                    .foregroundStyle(Palette.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .padding(.horizontal, 8)
        .glassSurface(cornerRadius: 20, tint: achievement.isUnlocked ? achievement.theme.accent : nil, highlighted: isNew)
        .overlay(alignment: .topTrailing) {
            if isNew {
                Chip(text: Text("NEW"), tint: Palette.amber, filled: true)
                    .padding(6)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityStatus)
    }

    @ViewBuilder
    private var medallion: some View {
        if achievement.isUnlocked {
            ZStack {
                Circle()
                    .fill(achievement.theme.gradient)
                Circle()
                    .fill(LinearGradient(colors: [Color.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                Circle()
                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                Image(systemName: achievement.symbol)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .shadow(color: achievement.theme.accent.opacity(0.55), radius: 12)
            .accessibilityHidden(true)
        } else {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                Circle()
                    .strokeBorder(Palette.hairline, lineWidth: 1)
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.3, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        }
    }

    private var accessibilityStatus: Text {
        if !achievement.isUnlocked {
            return Text("Locked")
        }
        return isNew ? Text("Unlocked, new") : Text("Unlocked")
    }
}

#Preview {
    InsightsView()
        .previewEnvironment()
}
