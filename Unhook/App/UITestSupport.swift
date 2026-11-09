#if DEBUG
import SwiftData
import SwiftUI

/// Launch arguments for UI tests and the App Store screenshot run. Compiled into Debug builds only.
///
/// - `-UITest`: fresh in-memory data and no system permission prompts.
/// - `-UITestSeed`: fill that store with realistic sample data (a 47-day streak, goals, cravings, pledges).
/// - `-UITestScreen <name>`: open a screen at launch: `today`, `progress`, `settings`, `sos`, `celebration`,
///   `challenge` (the 30-Day Reset) or `rankup` (the rank-up celebration).
/// - `-UITestHour <0-23>`: the hour Today's greeting is written for, so screenshots don't depend on the clock.
///
/// Rank-up celebrations only appear with `-UITestScreen rankup`, so they never cover other screenshots.
/// Onboarding is controlled with the user-defaults argument `-hasOnboarded YES` / `-hasOnboarded NO`.
enum UITestSupport {
    static let arguments = ProcessInfo.processInfo.arguments
    static let isActive = arguments.contains("-UITest")
    static let seedsSampleData = arguments.contains("-UITestSeed")

    static var initialScreen: String? {
        guard let index = arguments.firstIndex(of: "-UITestScreen"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    /// The hour passed with `-UITestHour`, or nil to use the clock.
    static var hourOverride: Int? {
        guard let index = arguments.firstIndex(of: "-UITestHour"), arguments.indices.contains(index + 1),
              let hour = Int(arguments[index + 1]), (0..<24).contains(hour)
        else { return nil }
        return hour
    }

    @MainActor
    static func makeContainer() -> ModelContainer {
        let container = AppModelContainer.make(inMemory: true)
        if seedsSampleData {
            UITestSampleData.populate(container.mainContext)
        }
        return container
    }

    /// Applies `-UITestScreen` once the tabs are on screen.
    @MainActor
    static func applyInitialScreen(router: AppRouter, habits: [Habit]) {
        switch initialScreen {
        case "progress":
            router.selectedTab = .progress
        case "settings":
            router.selectedTab = .settings
        case "sos":
            router.isShowingSOS = true
        case "challenge":
            router.showChallenge()
        case "celebration":
            guard let habit = habits.first,
                  let milestone = Milestone.latest(reachedBy: habit.stats().currentStreak) else { return }
            router.celebration = MilestoneCelebration(habit: habit, milestone: milestone)
        default:
            break
        }
    }
}

/// Sample data that looks like a real person a few weeks into quitting. Used for UI tests and screenshots.
@MainActor
enum UITestSampleData {
    static func populate(_ context: ModelContext, now: Date = .now) {
        let day: TimeInterval = 86_400

        let smoking = Habit(
            name: "Smoking", emoji: "🚬", theme: .fire,
            streakStart: now.addingTimeInterval(-47 * day - 4 * 3_600),
            dailyCost: 12, dailyMinutes: 45, unitsPerDay: 15, unitName: "cigarettes",
            reasons: ["Breathe easier on my runs", "Save for a trip to Japan", "Be there for my family"],
            sortIndex: 0, presetID: "smoking"
        )
        let scrolling = Habit(
            name: "Doomscrolling", emoji: "📱", theme: .ocean,
            streakStart: now.addingTimeInterval(-12 * day - 2 * 3_600),
            dailyMinutes: 150,
            reasons: ["Be present with my friends", "Sleep before midnight"],
            sortIndex: 1, presetID: "social"
        )
        let sugar = Habit(
            name: "Sugar", emoji: "🍩", theme: .candy,
            streakStart: now.addingTimeInterval(-5 * day - 9 * 3_600),
            dailyCost: 4, dailyMinutes: 10, unitsPerDay: 3, unitName: "snacks",
            reasons: ["More energy in the afternoon"],
            sortIndex: 2, presetID: "sugar"
        )
        for habit in [smoking, scrolling, sugar] {
            context.insert(habit)
        }

        // An earlier attempt at doomscrolling, so the history and "best streak" have something to show.
        let slip = Relapse(date: now.addingTimeInterval(-12 * day - 2 * 3_600), streakSeconds: 9 * day, note: "")
        context.insert(slip)
        scrolling.relapses.append(slip)
        scrolling.bankedSeconds = 9 * day
        scrolling.bestStreakSeconds = 9 * day

        // Milestones already reached were celebrated, so no celebration covers the first screen.
        for habit in [smoking, scrolling, sugar] {
            habit.celebratedMilestoneSeconds = Milestone.latest(reachedBy: habit.stats(at: now).currentStreak)?.seconds ?? 0
        }

        context.insert(SavingsGoal(title: "Trip to Japan", emoji: "🗾", cost: 1_200, sortIndex: 0))
        context.insert(SavingsGoal(title: "New running shoes", emoji: "👟", cost: 140, sortIndex: 1))

        // Beaten cravings over the last few weeks, mostly in the evening, with a mix of triggers.
        let triggers: [CravingTrigger] = [.stress, .social, .boredom, .stress, .routine, .tired, .stress, .social, .anxiety, .boredom]
        for index in 0..<26 {
            let hoursAgo = Double(index) * 41 + Double(index % 3) * 2
            let urge = Urge(
                date: now.addingTimeInterval(-hoursAgo * 3_600),
                resisted: true,
                trigger: triggers[index % triggers.count],
                intensity: 1 + (index * 3) % 5
            )
            context.insert(urge)
            (index % 4 == 3 ? scrolling : smoking).urges.append(urge)
        }

        // A daily pledge every day for the last 30 days, today included.
        let moods = [4, 4, 3, 5, 4, 3, 4, 5, 5, 4, 3, 4, 2, 4, 5, 4, 4, 3, 5, 4, 4, 5, 3, 4, 4, 5, 4, 3, 4, 5]
        for (offset, mood) in moods.enumerated() {
            context.insert(Pledge(day: now.addingTimeInterval(-Double(offset) * day), mood: mood))
        }

        // One of today's missions already checked off, and a 30-Day Reset on day 5 with days 1-4 done.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        if let mission = DailyMissions.missions(for: now, calendar: calendar).first(where: { $0.kind == .selfReported }) {
            context.insert(MissionCompletion(day: today, missionID: mission.id, completedAt: now))
        }
        let resetStart = calendar.date(byAdding: .day, value: -4, to: today) ?? today
        let reset = ChallengeProgress(challengeID: ResetChallenge.id, startDay: resetStart)
        reset.joinedAt = resetStart
        reset.completedDays = [1, 2, 3, 4]
        context.insert(reset)

        try? context.save()
    }
}
#endif
