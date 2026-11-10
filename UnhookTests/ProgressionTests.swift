import Foundation
import SwiftData
import Testing
@testable import Unhook

private let secondsPerDay: TimeInterval = 86_400

private func gregorian(_ identifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier) ?? TimeZone(secondsFromGMT: 0)!
    return calendar
}

/// UTC, so day boundaries don't depend on the machine running the tests.
private let utc = gregorian("UTC")

private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0, in calendar: Calendar = utc) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

// MARK: - Ranks

struct RankTests {
    @Test func twelveRanksFromMidnightToLegend() {
        #expect(Rank.all.count == 12)
        #expect(Rank.all.map(\.level) == Array(1...12))
        #expect(Rank.all.first?.minXP == 0)
        #expect(Rank.all.last?.minXP == 15_000)
        let thresholds = Rank.all.map(\.minXP)
        #expect(thresholds == thresholds.sorted())
        #expect(Set(thresholds).count == thresholds.count)
        #expect(Set(Rank.all.map(\.symbol)).count == Rank.all.count)
        #expect(Rank.all.allSatisfy { !$0.title.isEmpty && !$0.encouragement.isEmpty })
    }

    @Test func rankForXP() {
        #expect(Rank.rank(for: -20).level == 1)
        #expect(Rank.rank(for: 0).level == 1)
        #expect(Rank.rank(for: 99).level == 1)
        #expect(Rank.rank(for: 100).level == 2)
        #expect(Rank.rank(for: 499).level == 3)
        #expect(Rank.rank(for: 500).level == 4)
        #expect(Rank.rank(for: 14_999).level == 11)
        #expect(Rank.rank(for: 15_000).level == 12)
        #expect(Rank.rank(for: 9_000_000).level == 12)
    }

    @Test func nextRank() throws {
        let first = try #require(Rank.all.first)
        let last = try #require(Rank.all.last)
        #expect(Rank.next(after: first)?.level == 2)
        #expect(Rank.next(after: last) == nil)
    }

    @Test func progressTowardTheNextRank() {
        let summary = XPSummary(total: 640)
        #expect(summary.rank.level == 4)
        #expect(summary.nextRank?.level == 5)
        #expect(summary.xpToNext == 260)
        #expect(abs(summary.progressToNext - 0.35) < 0.000_1)

        let exact = XPSummary(total: 900)
        #expect(exact.rank.level == 5)
        #expect(exact.progressToNext == 0)
        #expect(exact.xpToNext == 600)
    }

    @Test func topRankIsComplete() {
        let summary = XPSummary(total: 20_000)
        #expect(summary.rank.level == 12)
        #expect(summary.nextRank == nil)
        #expect(summary.xpToNext == nil)
        #expect(summary.progressToNext == 1)
    }

    @Test func negativeTotalsClampToZero() {
        let summary = XPSummary(total: -50)
        #expect(summary.total == 0)
        #expect(summary.rank.level == 1)
        #expect(summary.xpToNext == 100)
    }
}

// MARK: - XP

@MainActor
struct XPCalculatorTests {
    private static let now = makeDate(2025, 3, 10)

    @Test func nothingDoneIsMidnight() {
        let summary = XPCalculator.summary(
            habits: [], pledges: [], urges: [], missions: [], challenges: [],
            unlockedAchievementCount: 0, now: Self.now, calendar: utc
        )
        #expect(summary.total == 0)
        #expect(summary.rank.level == 1)
        #expect(summary.sources.count == XPSource.Kind.allCases.count)
        #expect(summary.sources.allSatisfy { $0.count == 0 })
    }

    @Test func everySourceAddsUp() {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let now = Self.now
        let sosDay = makeDate(2025, 3, 8)
        #expect(DailyMissions.isSOSDay(EngagementCalendar.dayIndex(for: sosDay, calendar: utc)))
        #expect(!DailyMissions.isSOSDay(EngagementCalendar.dayIndex(for: now, calendar: utc)))

        // 2 banked days + a 3.5-day streak = 5 whole clean days.
        let habit = Habit(name: "Smoking", emoji: "🚬", theme: .fire, streakStart: now.addingTimeInterval(-3.5 * secondsPerDay))
        habit.bankedSeconds = 2 * secondsPerDay
        context.insert(habit)

        // Two pledge days (today twice counts once).
        let pledges = [
            Pledge(day: now, mood: 4, calendar: utc),
            Pledge(day: now.addingTimeInterval(-3_600), mood: 3, calendar: utc),
            Pledge(day: sosDay, mood: 5, calendar: utc),
        ]
        // Two beaten cravings; a lost one earns nothing.
        let urges = [
            Urge(date: now, resisted: true),
            Urge(date: sosDay, resisted: true),
            Urge(date: makeDate(2025, 3, 9), resisted: false),
        ]
        // Today: two self-reported missions (one double-tapped). SOS day: one self-reported mission.
        let today = utc.startOfDay(for: now)
        let missions = [
            MissionCompletion(day: today, missionID: "walk"),
            MissionCompletion(day: today, missionID: "water"),
            MissionCompletion(day: today, missionID: "walk"),
            MissionCompletion(day: utc.startOfDay(for: sosDay), missionID: "song"),
        ]
        let run = ChallengeProgress(challengeID: ResetChallenge.id, startDay: makeDate(2025, 3, 1))
        run.completedDays = [1, 2, 3, 3, 31]
        pledges.forEach { context.insert($0) }
        urges.forEach { context.insert($0) }
        missions.forEach { context.insert($0) }
        context.insert(run)

        let summary = XPCalculator.summary(
            habits: [habit], pledges: pledges, urges: urges, missions: missions, challenges: [run],
            unlockedAchievementCount: 2, now: now, calendar: utc
        )
        let counts = Dictionary(uniqueKeysWithValues: summary.sources.map { ($0.kind, $0.count) })
        #expect(counts[.cleanDays] == 5)
        #expect(counts[.pledges] == 2)
        #expect(counts[.cravings] == 2)
        // Today: pledge + 2 self-reported. SOS day: pledge + 1 self-reported + the beaten craving. Both perfect.
        #expect(counts[.missions] == 6)
        #expect(counts[.perfectDays] == 2)
        #expect(counts[.challengeDays] == 3)
        #expect(counts[.achievements] == 2)
        // 50 + 30 + 40 + 60 + 30 + 75 + 100
        #expect(summary.total == 385)
        #expect(summary.rank.level == 3)
        #expect(summary.xpToNext == 115)
    }

    @Test func beatenCravingsEarnXPUpToADailyCap() {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let now = Self.now
        // Eight on one day, two the day before: only five of the eight count.
        let urges = (0..<8).map { Urge(date: now.addingTimeInterval(-Double($0) * 60), resisted: true) }
            + (0..<2).map { _ in Urge(date: now.addingTimeInterval(-secondsPerDay), resisted: true) }
        urges.forEach { context.insert($0) }
        let summary = XPCalculator.summary(
            habits: [], pledges: [], urges: urges, missions: [], challenges: [],
            unlockedAchievementCount: 0, now: now, calendar: utc
        )
        let cravings = summary.sources.first { $0.kind == .cravings }
        #expect(cravings?.count == XPRewards.maxCravingsPerDay + 2)
        #expect(cravings?.xp == (XPRewards.maxCravingsPerDay + 2) * XPRewards.perCravingBeaten)
    }

    @Test func aSlipNeverLowersXP() {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let now = Self.now
        let habit = Habit(name: "Vaping", emoji: "💨", theme: .grape, streakStart: now.addingTimeInterval(-10 * secondsPerDay - 600))
        context.insert(habit)

        let before = XPCalculator.summary(
            habits: [habit], pledges: [], urges: [], missions: [], challenges: [],
            unlockedAchievementCount: 0, now: now, calendar: utc
        )
        habit.recordRelapse(at: now, in: context)
        let after = XPCalculator.summary(
            habits: [habit], pledges: [], urges: [], missions: [], challenges: [],
            unlockedAchievementCount: 0, now: now, calendar: utc
        )
        #expect(before.total == 10 * XPRewards.perCleanDay)
        #expect(after.total == before.total)
    }

    @Test func leavingTheResetKeepsItsXP() {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let run = ResetChallenge.start(existing: [], in: context, now: Self.now, calendar: utc)
        #expect(ResetChallenge.markDone(day: 1, in: run, now: Self.now, calendar: utc))
        ResetChallenge.leave(run, in: context, now: Self.now)

        #expect(run.leftAt != nil)
        #expect(ResetChallenge.current(in: [run]) == nil)
        let summary = XPCalculator.summary(
            habits: [], pledges: [], urges: [], missions: [], challenges: [run],
            unlockedAchievementCount: 0, now: Self.now, calendar: utc
        )
        #expect(summary.total == XPRewards.perChallengeDay)
    }
}

// MARK: - Daily missions

struct DailyMissionsTests {
    @Test func threeMissionsEveryDayWithThePledgeFirst() {
        for index in -40..<400 {
            let missions = DailyMissions.missions(forDayIndex: index)
            #expect(missions.count == 3)
            #expect(missions.first?.kind == .pledge)
            #expect(Set(missions.map(\.id)).count == 3, "Day \(index) repeats a mission")
        }
    }

    @Test func theSameMissionsAllDay() {
        let midnight = makeDate(2025, 6, 2, hour: 0)
        let lastMinute = makeDate(2025, 6, 2, hour: 23, minute: 59)
        #expect(DailyMissions.missions(for: midnight, calendar: utc) == DailyMissions.missions(for: lastMinute, calendar: utc))
        #expect(DailyMissions.missions(for: makeDate(2025, 6, 3), calendar: utc) != DailyMissions.missions(for: midnight, calendar: utc))
    }

    @Test func sosMissionEveryThirdDay() {
        var sosDays = 0
        for index in 0..<90 {
            let missions = DailyMissions.missions(forDayIndex: index)
            let hasSOS = missions.contains { $0.kind == .sos }
            #expect(hasSOS == DailyMissions.isSOSDay(index))
            if hasSOS {
                sosDays += 1
                #expect(missions.last?.kind == .sos)
            }
        }
        #expect(sosDays == 30)
        #expect(DailyMissions.isSOSDay(-3))
        #expect(!DailyMissions.isSOSDay(-1))
    }

    @Test func poolIsSelfReportedWithUniqueIDs() {
        let ids = DailyMissions.pool.map(\.id)
        #expect(DailyMissions.pool.count >= 25)
        #expect(Set(ids).count == ids.count)
        #expect(!ids.contains(DailyMissions.pledgeMission.id))
        #expect(!ids.contains(DailyMissions.sosMission.id))
        #expect(DailyMissions.pool.allSatisfy { $0.kind == .selfReported && !$0.title.isEmpty && !$0.detail.isEmpty })
    }

    @Test func rotationVisitsTheWholePool() {
        var seen = Set<String>()
        for index in 0..<90 {
            for mission in DailyMissions.missions(forDayIndex: index) where mission.kind == .selfReported {
                seen.insert(mission.id)
            }
        }
        #expect(seen.count == DailyMissions.pool.count)
    }

    @Test func dayIndexCountsCalendarDaysAcrossDaylightSaving() {
        let newYork = gregorian("America/New_York")
        #expect(EngagementCalendar.dayIndex(for: makeDate(2024, 1, 1, hour: 0, in: newYork), calendar: newYork) == 0)
        #expect(EngagementCalendar.dayIndex(for: makeDate(2024, 1, 1, hour: 23, in: newYork), calendar: newYork) == 0)
        #expect(EngagementCalendar.dayIndex(for: makeDate(2025, 3, 10), calendar: utc) == 434)

        var cursor = makeDate(2025, 1, 1, hour: 0, in: newYork)
        var previous = EngagementCalendar.dayIndex(for: cursor, calendar: newYork)
        for _ in 0..<400 {
            cursor = newYork.date(byAdding: .day, value: 1, to: cursor)!
            let index = EngagementCalendar.dayIndex(for: cursor, calendar: newYork)
            #expect(index == previous + 1)
            previous = index
        }
    }

    @Test func moduloHelpersHandleNegatives() {
        #expect(EngagementCalendar.positiveModulo(-1, 3) == 2)
        #expect(EngagementCalendar.positiveModulo(7, 3) == 1)
        #expect(EngagementCalendar.floorDivision(-1, 30) == -1)
        #expect(EngagementCalendar.floorDivision(-30, 30) == -1)
        #expect(EngagementCalendar.floorDivision(-31, 30) == -2)
        #expect(EngagementCalendar.floorDivision(59, 30) == 1)
    }
}

@MainActor
struct MissionCompletionTests {
    private static let today = makeDate(2025, 3, 10)
    private static let yesterday = makeDate(2025, 3, 9)

    @Test func pledgeMissionCompletesWithTodaysPledge() {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let old = Pledge(day: Self.yesterday, mood: 4, calendar: utc)
        context.insert(old)
        let mission = DailyMissions.pledgeMission
        #expect(!DailyMissions.isCompleted(mission, on: Self.today, completions: [], pledges: [old], urges: [], calendar: utc))

        let todays = Pledge(day: Self.today, mood: 4, calendar: utc)
        context.insert(todays)
        #expect(DailyMissions.isCompleted(mission, on: Self.today, completions: [], pledges: [old, todays], urges: [], calendar: utc))
    }

    @Test func sosMissionCompletesWithABeatenCravingOrByHand() {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let mission = DailyMissions.sosMission
        let lost = Urge(date: Self.today, resisted: false)
        let beaten = Urge(date: Self.today, resisted: true)
        let earlier = Urge(date: Self.yesterday, resisted: true)
        let manual = MissionCompletion(day: utc.startOfDay(for: Self.today), missionID: mission.id)
        [lost, beaten, earlier].forEach { context.insert($0) }
        context.insert(manual)

        #expect(!DailyMissions.isCompleted(mission, on: Self.today, completions: [], pledges: [], urges: [lost, earlier], calendar: utc))
        #expect(DailyMissions.isCompleted(mission, on: Self.today, completions: [], pledges: [], urges: [lost, beaten], calendar: utc))
        #expect(DailyMissions.isCompleted(mission, on: Self.today, completions: [manual], pledges: [], urges: [], calendar: utc))
    }

    @Test func selfReportedMissionNeedsItsOwnCheckOffToday() {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let mission = DailyMissions.pool[0]
        let other = DailyMissions.pool[1]
        let yesterdays = MissionCompletion(day: utc.startOfDay(for: Self.yesterday), missionID: mission.id)
        let wrongMission = MissionCompletion(day: utc.startOfDay(for: Self.today), missionID: other.id)
        let done = MissionCompletion(day: utc.startOfDay(for: Self.today), missionID: mission.id)
        let pledge = Pledge(day: Self.today, mood: 3, calendar: utc)
        let beaten = Urge(date: Self.today, resisted: true)
        [yesterdays, wrongMission, done].forEach { context.insert($0) }
        context.insert(pledge)
        context.insert(beaten)

        #expect(!DailyMissions.isCompleted(mission, on: Self.today, completions: [yesterdays, wrongMission], pledges: [pledge], urges: [beaten], calendar: utc))
        #expect(DailyMissions.isCompleted(mission, on: Self.today, completions: [yesterdays, done], pledges: [], urges: [], calendar: utc))
    }

    @Test func dailyCountsCapSelfReportedSlots() {
        // Day 1 has two self-reported slots; day 0 (an SOS day) has one, plus the SOS mission.
        #expect(DailyMissions.completedCount(onDayIndex: 1, pledged: true, beatCraving: false, checkedIDs: ["a", "b", "c"]) == 3)
        #expect(DailyMissions.completedCount(onDayIndex: 0, pledged: false, beatCraving: false, checkedIDs: ["a", "b"]) == 1)
        #expect(DailyMissions.completedCount(onDayIndex: 0, pledged: true, beatCraving: true, checkedIDs: ["a"]) == 3)
        #expect(DailyMissions.completedCount(onDayIndex: 0, pledged: false, beatCraving: false, checkedIDs: ["sos"]) == 1)
        #expect(DailyMissions.completedCount(onDayIndex: 1, pledged: false, beatCraving: true, checkedIDs: ["sos"]) == 0)
    }
}

// MARK: - 30-Day Reset

@MainActor
struct ResetChallengeTests {
    @Test func thirtyStepsInOrder() {
        #expect(ResetChallenge.steps.count == ResetChallenge.length)
        #expect(ResetChallenge.steps.map(\.day) == Array(1...30))
        #expect(Set(ResetChallenge.steps.map(\.title)).count == ResetChallenge.length)
        #expect(ResetChallenge.steps.allSatisfy { !$0.detail.isEmpty && !$0.systemImage.isEmpty })
        #expect(ResetChallenge.step(for: 0).day == 1)
        #expect(ResetChallenge.step(for: 99).day == 30)
    }

    @Test func currentDayCountsFromTheStartAndCapsAtThirty() {
        let run = ChallengeProgress(challengeID: ResetChallenge.id, startDay: utc.startOfDay(for: makeDate(2025, 3, 1)))
        #expect(ResetChallenge.currentDay(for: run, now: makeDate(2025, 3, 1, hour: 23), calendar: utc) == 1)
        #expect(ResetChallenge.currentDay(for: run, now: makeDate(2025, 3, 5), calendar: utc) == 5)
        #expect(ResetChallenge.currentDay(for: run, now: makeDate(2025, 3, 30), calendar: utc) == 30)
        #expect(ResetChallenge.currentDay(for: run, now: makeDate(2025, 6, 1), calendar: utc) == 30)
        #expect(ResetChallenge.currentDay(for: run, now: makeDate(2025, 2, 20), calendar: utc) == 1)
    }

    @Test func currentDayIsSafeAcrossDaylightSaving() {
        // US clocks spring forward on 9 March 2025 and fall back on 2 November 2025.
        let newYork = gregorian("America/New_York")
        let spring = ChallengeProgress(challengeID: ResetChallenge.id, startDay: newYork.startOfDay(for: makeDate(2025, 3, 8, in: newYork)))
        #expect(ResetChallenge.currentDay(for: spring, now: makeDate(2025, 3, 9, hour: 23, minute: 30, in: newYork), calendar: newYork) == 2)
        #expect(ResetChallenge.currentDay(for: spring, now: makeDate(2025, 3, 10, hour: 0, minute: 10, in: newYork), calendar: newYork) == 3)

        let fall = ChallengeProgress(challengeID: ResetChallenge.id, startDay: newYork.startOfDay(for: makeDate(2025, 11, 1, in: newYork)))
        #expect(ResetChallenge.currentDay(for: fall, now: makeDate(2025, 11, 2, hour: 23, minute: 30, in: newYork), calendar: newYork) == 2)
        #expect(ResetChallenge.currentDay(for: fall, now: makeDate(2025, 11, 3, hour: 0, minute: 10, in: newYork), calendar: newYork) == 3)
    }

    @Test func markingStepsAndFinishing() {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let start = makeDate(2025, 3, 1)
        let run = ResetChallenge.start(existing: [], in: context, now: start, calendar: utc)
        #expect(run.startDay == utc.startOfDay(for: start))

        let dayFive = makeDate(2025, 3, 5)
        #expect(ResetChallenge.markDone(day: 5, in: run, now: dayFive, calendar: utc))
        #expect(ResetChallenge.markDone(day: 2, in: run, now: dayFive, calendar: utc))
        #expect(!ResetChallenge.markDone(day: 6, in: run, now: dayFive, calendar: utc))
        #expect(!ResetChallenge.markDone(day: 5, in: run, now: dayFive, calendar: utc))
        #expect(run.completedDays == [2, 5])
        #expect(ResetChallenge.openEarlierDays(in: run, now: dayFive, calendar: utc) == [1, 3, 4])
        #expect(ResetChallenge.state(ofDay: 2, in: run, now: dayFive, calendar: utc) == .done)
        #expect(ResetChallenge.state(ofDay: 3, in: run, now: dayFive, calendar: utc) == .open)
        #expect(ResetChallenge.state(ofDay: 6, in: run, now: dayFive, calendar: utc) == .locked)

        // Only today's step can be unchecked.
        #expect(!ResetChallenge.unmark(day: 2, in: run, now: dayFive, calendar: utc))
        #expect(ResetChallenge.unmark(day: 5, in: run, now: dayFive, calendar: utc))
        #expect(run.completedDays == [2])

        // Weeks later every step is open, and the last one finishes the run.
        let later = makeDate(2025, 4, 20)
        for day in 1...30 where day != 17 {
            ResetChallenge.markDone(day: day, in: run, now: later, calendar: utc)
        }
        #expect(!ResetChallenge.isFinished(run))
        #expect(run.finishedAt == nil)
        #expect(ResetChallenge.markDone(day: 17, in: run, now: later, calendar: utc))
        #expect(ResetChallenge.isFinished(run))
        #expect(run.finishedAt == later)
        #expect(!ResetChallenge.unmark(day: 30, in: run, now: later, calendar: utc))
        #expect(ResetChallenge.activeRun(in: [run]) == nil)
        #expect(ResetChallenge.current(in: [run]) === run)
    }

    @Test func oneActiveRunAtATimeAndAFreshStartAfterFinishing() {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let now = makeDate(2025, 3, 1)
        let first = ResetChallenge.start(existing: [], in: context, now: now, calendar: utc)
        #expect(ResetChallenge.start(existing: [first], in: context, now: now, calendar: utc) === first)

        first.completedDays = Array(1...30)
        first.finishedAt = now
        let later = now.addingTimeInterval(40 * secondsPerDay)
        let second = ResetChallenge.start(existing: [first], in: context, now: later, calendar: utc)
        #expect(second !== first)
        #expect(ResetChallenge.activeRun(in: [first, second]) === second)
        #expect(ResetChallenge.currentDay(for: second, now: later, calendar: utc) == 1)
    }

    @Test func leavingAnEmptyRunDeletesIt() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let run = ResetChallenge.start(existing: [], in: context, now: makeDate(2025, 3, 1), calendar: utc)
        try context.save()
        ResetChallenge.leave(run, in: context)
        try context.save()
        let remaining = try context.fetch(FetchDescriptor<ChallengeProgress>())
        #expect(remaining.isEmpty)
    }
}

// MARK: - Tips

struct DailyTipsTests {
    @Test func enoughTipsAllFilledIn() {
        #expect(DailyTips.all.count >= 30)
        #expect(DailyTips.all.allSatisfy { !$0.title.isEmpty && !$0.body.isEmpty && !$0.systemImage.isEmpty })
        #expect(Set(DailyTips.all.map(\.title)).count == DailyTips.all.count)
    }

    @Test func oneTipPerDay() {
        let midnight = makeDate(2025, 3, 10, hour: 0)
        let lateNight = makeDate(2025, 3, 10, hour: 23, minute: 59)
        #expect(DailyTips.tip(for: midnight, calendar: utc) == DailyTips.tip(for: lateNight, calendar: utc))
        #expect(DailyTips.tip(for: makeDate(2025, 3, 11), calendar: utc) != DailyTips.tip(for: midnight, calendar: utc))
        #expect(DailyTips.tip(forDayIndex: -1) == DailyTips.all[DailyTips.all.count - 1])
        #expect(DailyTips.tip(forDayIndex: DailyTips.all.count) == DailyTips.all[0])
    }
}

// MARK: - Achievement tracker

@MainActor
struct AchievementTrackerTests {
    /// Runs `body` with a tracker backed by its own throwaway defaults suite.
    private func withTracker(_ body: (AchievementTracker, UserDefaults) throws -> Void) throws {
        let suiteName = "AchievementTrackerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(AchievementTracker(defaults: defaults), defaults)
    }

    private static func achievement(_ id: String, unlocked: Bool) -> Achievement {
        Achievement(id: id, title: id, detail: "", symbol: "star.fill", theme: .gold, isUnlocked: unlocked)
    }

    @Test func recordsFirstUnlocksOnceAndMarksThemNew() throws {
        try withTracker { tracker, defaults in
            let now = makeDate(2025, 3, 10)
            let fresh = tracker.record([Self.achievement("a", unlocked: true), Self.achievement("b", unlocked: false)], now: now)
            #expect(fresh.map(\.id) == ["a"])
            #expect(tracker.isNew("a"))
            #expect(!tracker.isNew("b"))
            #expect(tracker.unlockDate(for: "a") == now)
            #expect(tracker.record([Self.achievement("a", unlocked: true)]).isEmpty)

            tracker.markAllSeen()
            #expect(!tracker.isNew("a"))
            #expect(tracker.unlockedIDs == ["a"])

            // Persisted, and an achievement that locks again isn't forgotten.
            let reloaded = AchievementTracker(defaults: defaults)
            #expect(reloaded.unlockedIDs == ["a"])
            #expect(reloaded.unlockDate(for: "a") == now)
            #expect(!reloaded.isNew("a"))
            let next = reloaded.record([Self.achievement("a", unlocked: false), Self.achievement("b", unlocked: true)])
            #expect(next.map(\.id) == ["b"])
            #expect(reloaded.isNew("b"))
            #expect(reloaded.unlockedIDs == ["a", "b"])
        }
    }

    @Test func resetForgetsEverything() throws {
        try withTracker { tracker, defaults in
            tracker.record([Self.achievement("a", unlocked: true)])
            tracker.reset()
            #expect(tracker.unlockedIDs.isEmpty)
            #expect(!tracker.isNew("a"))
            #expect(AchievementTracker(defaults: defaults).unlockedIDs.isEmpty)
        }
    }
}
