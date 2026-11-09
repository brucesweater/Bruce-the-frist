import SwiftUI
import SwiftData

/// Reads everything that earns XP and hands the current `XPSummary` to `content`. Refreshes every minute so clean
/// days add up on their own, and records newly unlocked achievements in `AchievementTracker`.
struct XPSummaryReader<Content: View>: View {
    @Query private var habits: [Habit]
    @Query private var pledges: [Pledge]
    @Query private var urges: [Urge]
    @Query private var missions: [MissionCompletion]
    @Query private var challenges: [ChallengeProgress]

    private let content: (XPSummary) -> Content

    init(@ViewBuilder content: @escaping (XPSummary) -> Content) {
        self.content = content
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let snapshot = makeSnapshot(at: timeline.date)
            content(snapshot.summary)
                .onAppear {
                    AchievementTracker.shared.record(snapshot.achievements)
                }
                .onChange(of: snapshot.unlockedIDs) {
                    AchievementTracker.shared.record(snapshot.achievements)
                }
        }
    }

    private func makeSnapshot(at now: Date) -> XPReaderSnapshot {
        let achievements = EngagementAchievements.evaluate(habits: habits, pledges: pledges, urges: urges, now: now)
        let unlocked = Set(achievements.filter(\.isUnlocked).map(\.id))
        let known = Set(achievements.map(\.id))
        // Achievements that ever unlocked keep their XP, even if one locks again (a pledge streak that lapsed).
        let everUnlocked = unlocked.union(AchievementTracker.shared.unlockedIDs.intersection(known))
        let summary = XPCalculator.summary(
            habits: habits,
            pledges: pledges,
            urges: urges,
            missions: missions,
            challenges: challenges,
            unlockedAchievementCount: everUnlocked.count,
            now: now
        )
        return XPReaderSnapshot(summary: summary, achievements: achievements, unlockedIDs: unlocked)
    }
}

private struct XPReaderSnapshot {
    let summary: XPSummary
    let achievements: [Achievement]
    let unlockedIDs: Set<String>
}

/// Achievements evaluated with the same inputs as the Progress tab.
enum EngagementAchievements {
    static func evaluate(habits: [Habit], pledges: [Pledge], urges: [Urge], now: Date = .now) -> [Achievement] {
        let totals = HabitTotals(habits: habits, at: now)
        let input = AchievementInput(
            habitCount: habits.count,
            bestStreak: totals.bestStreak,
            cravingsBeaten: urges.filter(\.resisted).count,
            moneySaved: totals.moneySaved,
            currencyCode: AppSettings.currencyCode,
            pledgeStreak: StreakCalculator.consecutiveDays(pledges.map { StoredDay.localStart(of: $0.day) }, now: now),
            totalPledges: pledges.count
        )
        return Achievement.evaluate(input)
    }
}
