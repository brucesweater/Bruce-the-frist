import Foundation
import SwiftData
import Testing
@testable import Unhook

// Pledges, mission check-offs and 30-Day Reset runs save their day without a time zone (`StoredDay`), so a trip east
// or west never moves them to another date.

/// 00:00 UTC on 9 November 2026: the stored day for anything saved on that date, wherever it was saved.
private let ninthOfNovember = Date(timeIntervalSince1970: 1_794_182_400)
/// 00:00 UTC on 5 November 2026.
private let fifthOfNovember = Date(timeIntervalSince1970: 1_793_836_800)

/// A Gregorian calendar in the time zone `identifier`.
private func gregorianCalendar(in identifier: String) throws -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: identifier))
    return calendar
}

/// `hour`:`minute` on a day in 2026, in `calendar`'s time zone.
private func localTime(_ month: Int, _ day: Int, hour: Int, minute: Int = 0, in calendar: Calendar) throws -> Date {
    try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)))
}

struct StoredDayTests {
    @Test func aDaySavedAnywhereHasTodaysIndexThere() throws {
        // Every half hour through a day in January and one in July, in every time zone the system knows.
        let utc = try gregorianCalendar(in: "UTC")
        let starts = try [localTime(1, 14, hour: 0, in: utc), localTime(7, 14, hour: 0, in: utc)]
        var mismatches: [String] = []
        for identifier in TimeZone.knownTimeZoneIdentifiers {
            guard let timeZone = TimeZone(identifier: identifier) else { continue }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            for start in starts {
                for step in 0..<48 {
                    let now = start.addingTimeInterval(Double(step) * 1_800)
                    let stored = StoredDay.make(for: now, calendar: calendar)
                    if EngagementCalendar.dayIndex(ofStored: stored) != EngagementCalendar.dayIndex(for: now, calendar: calendar)
                        || StoredDay.localStart(of: stored, calendar: calendar) != calendar.startOfDay(for: now) {
                        mismatches.append("\(identifier) at \(now)")
                    }
                }
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.prefix(5))")
    }

    @Test func aSavedDayKeepsItsDateInEveryTimeZone() throws {
        let newYork = try gregorianCalendar(in: "America/New_York")
        // Just after midnight, in the morning and late in the evening of 9 November in New York (by then it's
        // 10 November in UTC).
        for hour in [0, 7, 23] {
            let saved = try localTime(11, 9, hour: hour, minute: 30, in: newYork)
            let stored = StoredDay.make(for: saved, calendar: newYork)
            #expect(stored == ninthOfNovember)
            #expect(EngagementCalendar.dayIndex(ofStored: stored) == EngagementCalendar.dayIndex(for: saved, calendar: newYork))
            for identifier in ["America/Los_Angeles", "Pacific/Honolulu", "UTC", "Asia/Tokyo", "Pacific/Kiritimati"] {
                let zone = try gregorianCalendar(in: identifier)
                let noon = try localTime(11, 9, hour: 12, in: zone)
                #expect(StoredDay.localStart(of: stored, calendar: zone) == zone.startOfDay(for: noon), "\(identifier)")
            }
        }
    }

    @Test func daysSavedAtLocalMidnightStillReadAsTheirOwnDate() throws {
        // Before stored days, a day was saved as its start in the phone's time zone. Those rows keep their date if
        // they were saved anywhere from UTC-11 (Pago Pago) to UTC+12 (Kamchatka), in winter and in summer.
        let identifiers = [
            "Pacific/Pago_Pago", "Pacific/Honolulu", "America/Los_Angeles", "America/New_York", "UTC", "Europe/London",
            "Asia/Kolkata", "Asia/Kathmandu", "Asia/Tokyo", "Australia/Sydney", "Asia/Kamchatka",
        ]
        let losAngeles = try gregorianCalendar(in: "America/Los_Angeles")
        for identifier in identifiers {
            let zone = try gregorianCalendar(in: identifier)
            for month in [1, 7] {
                let noon = try localTime(month, 14, hour: 12, in: zone)
                let saved = zone.startOfDay(for: noon)
                #expect(EngagementCalendar.dayIndex(ofStored: saved) == EngagementCalendar.dayIndex(for: noon, calendar: zone), "\(identifier)")
                #expect(StoredDay.localStart(of: saved, calendar: zone) == saved, "\(identifier)")
                // Read in another time zone, it's the same date there.
                let noonThere = try localTime(month, 14, hour: 12, in: losAngeles)
                #expect(StoredDay.localStart(of: saved, calendar: losAngeles) == losAngeles.startOfDay(for: noonThere), "\(identifier)")
            }
        }
    }

    @Test func aDayThatStartsAtOneStillStartsAtOne() throws {
        // In a time zone that springs forward at midnight, that day starts at 01:00.
        let (zone, noon) = try #require(Self.midnightClockChange())
        let start = StoredDay.localStart(of: StoredDay.make(for: noon, calendar: zone), calendar: zone)
        #expect(start == zone.startOfDay(for: noon))
        #expect(zone.component(.hour, from: start) == 1)

        // Pledges on the day before, that day and the day after make a three-day streak.
        let dates = (-1...1).compactMap { zone.date(byAdding: .day, value: $0, to: noon) }
        let days = dates.map { StoredDay.localStart(of: StoredDay.make(for: $0, calendar: zone), calendar: zone) }
        let dayAfter = try #require(dates.last)
        #expect(days.count == 3)
        #expect(StreakCalculator.consecutiveDays(days, now: dayAfter, calendar: zone) == 3)
    }

    /// A calendar in a time zone that springs forward at midnight, and noon on that day.
    private static func midnightClockChange() -> (calendar: Calendar, noon: Date)? {
        for identifier in ["America/Santiago", "America/Havana", "Asia/Beirut"] {
            guard let timeZone = TimeZone(identifier: identifier) else { continue }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            guard let firstNoon = calendar.date(from: DateComponents(year: 2023, month: 1, day: 1, hour: 12)) else { continue }
            for offset in 0..<365 {
                guard let noon = calendar.date(byAdding: .day, value: offset, to: firstNoon) else { continue }
                if calendar.component(.hour, from: calendar.startOfDay(for: noon)) != 0 {
                    return (calendar, noon)
                }
            }
        }
        return nil
    }
}

@MainActor
struct StoredDayTravelTests {
    @Test func movingWestKeepsTodaysPledgeMissionsAndResetDay() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let newYork = try gregorianCalendar(in: "America/New_York")
        // At 7 AM on 9 November in New York: the pledge and both self-reported missions, on Day 5 of a Reset that
        // started on 5 November.
        let saved = try localTime(11, 9, hour: 7, in: newYork)
        let started = try localTime(11, 5, hour: 9, in: newYork)
        let run = ResetChallenge.start(existing: [], in: context, now: started, calendar: newYork)
        let pledge = Pledge(day: saved, mood: 4, calendar: newYork)
        let missions = DailyMissions.missions(for: saved, calendar: newYork)
        let completions = missions.filter { $0.kind == .selfReported }.map {
            MissionCompletion(day: StoredDay.make(for: saved, calendar: newYork), missionID: $0.id, completedAt: saved)
        }
        context.insert(pledge)
        completions.forEach { context.insert($0) }
        #expect(completions.count == 2)
        #expect(pledge.day == ninthOfNovember)
        #expect(completions.allSatisfy { $0.day == ninthOfNovember })
        #expect(run.startDay == fifthOfNovember)

        // 9 PM the same day in Chicago, Los Angeles and Honolulu. By 9 PM in Honolulu it's 10 November in New York.
        for identifier in ["America/Chicago", "America/Los_Angeles", "Pacific/Honolulu"] {
            let zone = try gregorianCalendar(in: identifier)
            let evening = try localTime(11, 9, hour: 21, in: zone)
            #expect(evening > saved)
            #expect(DailyMissions.missions(for: evening, calendar: zone) == missions)
            for mission in missions {
                let done = DailyMissions.isCompleted(mission, on: evening, completions: completions, pledges: [pledge], urges: [], calendar: zone)
                #expect(done, "\(mission.id) in \(identifier)")
            }
            #expect(ResetChallenge.currentDay(for: run, now: evening, calendar: zone) == 5, "\(identifier)")
        }
    }

    @Test func movingEastStartsTheNextDayOnTheLocalDate() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let newYork = try gregorianCalendar(in: "America/New_York")
        let tokyo = try gregorianCalendar(in: "Asia/Tokyo")
        let saved = try localTime(11, 9, hour: 7, in: newYork)
        let started = try localTime(11, 5, hour: 9, in: newYork)
        let run = ResetChallenge.start(existing: [], in: context, now: started, calendar: newYork)
        let pledge = Pledge(day: saved, mood: 4, calendar: newYork)
        context.insert(pledge)
        let mission = DailyMissions.pledgeMission

        // Until midnight in Tokyo, 9 November is still the pledge's day there too.
        let lateInTokyo = try localTime(11, 9, hour: 23, in: tokyo)
        #expect(DailyMissions.isCompleted(mission, on: lateInTokyo, completions: [], pledges: [pledge], urges: [], calendar: tokyo))
        #expect(ResetChallenge.currentDay(for: run, now: lateInTokyo, calendar: tokyo) == 5)

        // 8 AM on 10 November in Tokyo and on Kiritimati (UTC+14), while it's still 9 November in New York: a new day
        // there, with its own pledge to take and Day 6 of the Reset. The 9 November pledge keeps the streak going.
        for identifier in ["Asia/Tokyo", "Pacific/Kiritimati"] {
            let zone = try gregorianCalendar(in: identifier)
            let morning = try localTime(11, 10, hour: 8, in: zone)
            #expect(newYork.component(.day, from: morning) == 9)
            #expect(!DailyMissions.isCompleted(mission, on: morning, completions: [], pledges: [pledge], urges: [], calendar: zone), "\(identifier)")
            #expect(ResetChallenge.currentDay(for: run, now: morning, calendar: zone) == 6, "\(identifier)")
            let streak = StreakCalculator.consecutiveDays([StoredDay.localStart(of: pledge.day, calendar: zone)], now: morning, calendar: zone)
            #expect(streak == 1, "\(identifier)")
        }

        // A pledge taken just after midnight in Tokyo is for 10 November. Back in New York that evening, still
        // 9 November there, it isn't today's pledge, and the New York one still is.
        let earlyInTokyo = try localTime(11, 10, hour: 0, minute: 30, in: tokyo)
        let next = Pledge(day: earlyInTokyo, mood: 5, calendar: tokyo)
        context.insert(next)
        let backHome = try localTime(11, 9, hour: 23, minute: 30, in: newYork)
        #expect(backHome > earlyInTokyo)
        #expect(!DailyMissions.isCompleted(mission, on: backHome, completions: [], pledges: [next], urges: [], calendar: newYork))
        #expect(DailyMissions.isCompleted(mission, on: backHome, completions: [], pledges: [next, pledge], urges: [], calendar: newYork))
    }

    @Test func xpCountsTheSameDaysWhereverItIsRead() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let newYork = try gregorianCalendar(in: "America/New_York")
        // At 7 AM on 8 and 9 November in New York: the pledge and both self-reported missions, two perfect days.
        // 7 and 10 November are SOS days with one self-reported slot, so a day read as the one before or after
        // would lose XP.
        var pledges: [Pledge] = []
        var completions: [MissionCompletion] = []
        for day in [8, 9] {
            let saved = try localTime(11, day, hour: 7, in: newYork)
            pledges.append(Pledge(day: saved, mood: 4, calendar: newYork))
            for mission in DailyMissions.missions(for: saved, calendar: newYork) where mission.kind == .selfReported {
                completions.append(MissionCompletion(day: StoredDay.make(for: saved, calendar: newYork), missionID: mission.id, completedAt: saved))
            }
        }
        pledges.forEach { context.insert($0) }
        completions.forEach { context.insert($0) }
        #expect(completions.count == 4)

        let now = try localTime(11, 10, hour: 12, in: newYork)
        for identifier in ["America/New_York", "America/Chicago", "America/Los_Angeles", "Pacific/Honolulu", "Asia/Tokyo", "Pacific/Kiritimati"] {
            let zone = try gregorianCalendar(in: identifier)
            let summary = XPCalculator.summary(
                habits: [], pledges: pledges, urges: [], missions: completions, challenges: [],
                unlockedAchievementCount: 0, now: now, calendar: zone
            )
            let counts = Dictionary(uniqueKeysWithValues: summary.sources.map { ($0.kind, $0.count) })
            #expect(counts[.pledges] == 2, "\(identifier)")
            #expect(counts[.missions] == 6, "\(identifier)")
            #expect(counts[.perfectDays] == 2, "\(identifier)")
            #expect(summary.total == 2 * XPRewards.perPledge + 6 * XPRewards.perMission + 2 * XPRewards.perPerfectDay, "\(identifier)")
        }
    }

    @Test func streaksAndWeeklyCountsUseTheSavedDate() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let newYork = try gregorianCalendar(in: "America/New_York")
        // A pledge at 7 AM every day from 3 to 9 November in New York.
        let pledges = try (3...9).map { day in
            try Pledge(day: localTime(11, day, hour: 7, in: newYork), mood: 4, calendar: newYork)
        }
        pledges.forEach { context.insert($0) }

        // Where it's read, the local day and hour, the pledge streak and the pledges in the last 7 days.
        let reads: [(zone: String, day: Int, hour: Int, streak: Int, lastSevenDays: Int)] = [
            ("America/Los_Angeles", 9, 21, 7, 7),
            // The next evening, before pledging: the streak is still alive.
            ("Pacific/Honolulu", 10, 20, 7, 6),
            ("Asia/Tokyo", 10, 8, 7, 6),
            ("Pacific/Kiritimati", 10, 8, 7, 6),
        ]
        for read in reads {
            let zone = try gregorianCalendar(in: read.zone)
            let now = try localTime(11, read.day, hour: read.hour, in: zone)
            let days = pledges.map { StoredDay.localStart(of: $0.day, calendar: zone) }
            #expect(StreakCalculator.consecutiveDays(days, now: now, calendar: zone) == read.streak, "\(read.zone)")
            #expect(CleanDays.count(days, inLast: 7, now: now, calendar: zone) == read.lastSevenDays, "\(read.zone)")
        }
    }

    @Test func oldRowsFromNewYorkStillCountOnTheirOwnDay() throws {
        // A pledge, a mission check-off and a Reset start saved the old way (at local midnight in New York) still
        // count on their own day, there and after a move west.
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let newYork = try gregorianCalendar(in: "America/New_York")
        let saved = try localTime(11, 9, hour: 7, in: newYork)
        let started = try localTime(11, 5, hour: 9, in: newYork)
        let pledge = Pledge(day: saved, mood: 3, calendar: newYork)
        pledge.day = newYork.startOfDay(for: saved)
        let mission = try #require(DailyMissions.missions(for: saved, calendar: newYork).first(where: { $0.kind == .selfReported }))
        let completion = MissionCompletion(day: newYork.startOfDay(for: saved), missionID: mission.id, completedAt: saved)
        let run = ChallengeProgress(challengeID: ResetChallenge.id, startDay: newYork.startOfDay(for: started))
        context.insert(pledge)
        context.insert(completion)
        context.insert(run)

        for identifier in ["America/New_York", "Pacific/Honolulu"] {
            let zone = try gregorianCalendar(in: identifier)
            let evening = try localTime(11, 9, hour: 21, in: zone)
            #expect(DailyMissions.isCompleted(DailyMissions.pledgeMission, on: evening, completions: [], pledges: [pledge], urges: [], calendar: zone), "\(identifier)")
            #expect(DailyMissions.isCompleted(mission, on: evening, completions: [completion], pledges: [], urges: [], calendar: zone), "\(identifier)")
            #expect(ResetChallenge.currentDay(for: run, now: evening, calendar: zone) == 5, "\(identifier)")
        }
    }
}
