import Foundation
import SwiftData
import Testing
@testable import Unhook

struct CleanDaysTests {
    private static let hour: TimeInterval = 3_600
    private static let day: TimeInterval = 86_400
    /// Monday 1 January 2024, 00:00 UTC.
    private static let monday = Date(timeIntervalSince1970: 1_704_067_200)
    /// Wednesday 3 January 2024, 15:00 UTC: "now" in most tests.
    private static let wednesday = Date(timeIntervalSince1970: 1_704_067_200 + 2 * 86_400 + 15 * 3_600)

    /// A fixed Gregorian calendar in UTC, so the tests don't depend on the machine's time zone.
    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    /// `offset` days from Wednesday 3 January 2024 (negative is earlier), at `atHour`:00 UTC.
    private static func date(_ offset: Int, atHour: Int = 12) -> Date {
        monday.addingTimeInterval(Double(2 + offset) * day + Double(atHour) * hour)
    }

    private static func model(_ habits: [CleanDaysHabit], now: Date) -> CleanDays {
        CleanDays(habits: habits, now: now, calendar: utc)
    }

    /// The square for the day containing `date`.
    private static func square(_ model: CleanDays, on date: Date) -> CleanDay? {
        let start = utc.startOfDay(for: date)
        return model.days.first { $0.date == start }
    }

    /// A calendar in a time zone that springs forward at midnight, and noon on that day (which starts at 01:00).
    private static func midnightClockChange() -> (calendar: Calendar, noon: Date)? {
        for identifier in ["America/Santiago", "America/Havana", "Asia/Beirut"] {
            guard let zone = TimeZone(identifier: identifier) else { continue }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
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

    // MARK: Shape

    @Test func twelveWeeksOfSevenDaysEndWithThisWeek() throws {
        let model = Self.model([], now: Self.wednesday)
        #expect(model.weeks.count == 12)
        #expect(model.weeks.allSatisfy { $0.count == 7 })
        #expect(model.days.count == 84)
        // Every column starts on a Monday; the last one is this week.
        #expect(model.weeks.allSatisfy { Self.utc.component(.weekday, from: $0[0].date) == 2 })
        #expect(model.weeks.last?.first?.date == Self.monday)
        #expect(model.weeks.first?.first?.date == Self.monday.addingTimeInterval(-77 * Self.day))

        let thisWeek = try #require(model.weeks.last)
        #expect(thisWeek[2].isToday)
        #expect(thisWeek[2].date == Self.utc.startOfDay(for: Self.wednesday))
        #expect(thisWeek[3...].allSatisfy { $0.status == .future && !$0.isToday })
        #expect(model.days.filter(\.isToday).count == 1)
        #expect(model.today?.date == thisWeek[2].date)
        // Days are in order, oldest first.
        #expect(model.days.map(\.date) == model.days.map(\.date).sorted())
    }

    @Test func onSundayTheWholeLastColumnHasHappened() {
        let model = Self.model([], now: Self.date(4, atHour: 23))
        #expect(model.weeks.last?.last?.isToday == true)
        #expect(!model.days.contains(where: { $0.status == .future }))
        #expect(model.weeks.last?.first?.date == Self.monday)
    }

    @Test func noHabitsMeansNoTrackedDays() {
        let model = Self.model([], now: Self.wednesday)
        #expect(model.cleanDayCount == 0)
        #expect(model.slipDayCount == 0)
        #expect(model.trackedDayCount == 0)
        #expect(model.days.filter { $0.status != .future }.allSatisfy { $0.status == .untracked })
        #expect(model.cleanDays(inLast: 7) == 0)
    }

    // MARK: Clean and slip days

    @Test func daysSinceTheStartAreCleanAndSlipDaysAreMarked() throws {
        // Quit on Sunday 24 December at 14:00, slipped on 30 December in the evening.
        let habit = CleanDaysHabit(start: Self.date(-10, atHour: 14), slips: [Self.date(-4, atHour: 20)])
        let model = Self.model([habit], now: Self.wednesday)

        #expect(Self.square(model, on: Self.date(-11))?.status == .untracked)
        #expect(Self.square(model, on: Self.date(-10))?.status == .clean)
        #expect(Self.square(model, on: Self.date(-4))?.status == .slip)
        #expect(Self.square(model, on: Self.date(-3))?.status == .clean)
        let today = try #require(Self.square(model, on: Self.wednesday))
        #expect(today.status == .clean)
        #expect(today.isToday)

        // 24 December through today is 11 days, one of them with a slip.
        #expect(model.trackedDayCount == 11)
        #expect(model.cleanDayCount == 10)
        #expect(model.slipDayCount == 1)
        // The last 7 days (28 December to today) include the slip on the 30th.
        #expect(model.cleanDays(inLast: 7) == 6)
    }

    @Test func cleanDaysGlowBrighterWhenMoreHabitsStayClean() throws {
        let smoking = CleanDaysHabit(start: Self.date(-20), slips: [])
        let sugar = CleanDaysHabit(start: Self.date(-5), slips: [Self.date(-1, atHour: 9)])
        let model = Self.model([smoking, sugar], now: Self.wednesday)

        let oneHabit = try #require(Self.square(model, on: Self.date(-10)))
        #expect(oneHabit.status == .clean)
        #expect(oneHabit.trackedHabits == 1)
        #expect(model.intensity(of: oneHabit) == 0.5)

        let bothHabits = try #require(Self.square(model, on: Self.date(-3)))
        #expect(bothHabits.cleanHabits == 2)
        #expect(model.intensity(of: bothHabits) == 1)

        // A slip in either habit marks the day, and it doesn't glow.
        let slipDay = try #require(Self.square(model, on: Self.date(-1)))
        #expect(slipDay.status == .slip)
        #expect(slipDay.trackedHabits == 2)
        #expect(slipDay.cleanHabits == 1)
        #expect(model.intensity(of: slipDay) == 0)

        let before = try #require(Self.square(model, on: Self.date(-30)))
        #expect(before.status == .untracked)
        #expect(model.intensity(of: before) == 0)
    }

    @Test func habitHistoryStartsWithItsFirstStreak() {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let start = Self.date(-30, atHour: 8)
        let habit = Habit(name: "Smoking", emoji: "🚬", theme: .fire, streakStart: start)
        context.insert(habit)
        let slip = Self.date(-12, atHour: 21)
        habit.recordRelapse(at: slip, in: context)

        let history = CleanDaysHabit(habit: habit)
        #expect(habit.streakStart == slip)
        #expect(history.start == start)
        #expect(history.slips == [slip])

        let model = Self.model([history], now: Self.wednesday)
        #expect(Self.square(model, on: start)?.status == .clean)
        #expect(Self.square(model, on: slip)?.status == .slip)
        #expect(Self.square(model, on: Self.date(-31))?.status == .untracked)
    }

    // MARK: Month labels

    @Test func monthLabelsSitOverTheWeekEachMonthBegins() {
        // Columns start on Mondays from 16 October 2023 to 1 January 2024. 1 November falls in the third column,
        // 1 December in the seventh and 1 January in the last; October starts too close to name.
        let model = Self.model([], now: Self.wednesday)
        #expect(model.monthLabels.map(\.column) == [2, 6, 11])
        #expect(model.monthLabels.map { Self.utc.component(.month, from: $0.date) } == [11, 12, 1])
    }

    @Test func theFirstColumnIsNamedWhenThereIsRoom() {
        // Wednesday 24 January 2024: columns start on Mondays from 6 November; 1 December is in the fourth column.
        let model = Self.model([], now: Self.date(21, atHour: 10))
        #expect(model.monthLabels.map(\.column) == [0, 3, 8])
        #expect(model.monthLabels.first.map { Self.utc.component(.month, from: $0.date) } == 11)
    }

    // MARK: This week

    @Test func recentCountsCoverTheLastDaysIncludingToday() {
        let firstDay = Self.date(-6, atHour: 0)
        let dates = [
            Self.wednesday,
            Self.date(0, atHour: 0),
            firstDay,
            firstDay.addingTimeInterval(-1),
            Self.date(1, atHour: 1),
        ]
        #expect(CleanDays.firstDay(ofLast: 7, now: Self.wednesday, calendar: Self.utc) == firstDay)
        #expect(CleanDays.count(dates, inLast: 7, now: Self.wednesday, calendar: Self.utc) == 3)
        #expect(CleanDays.count(dates, inLast: 1, now: Self.wednesday, calendar: Self.utc) == 2)
        #expect(CleanDays.count(dates, inLast: 0, now: Self.wednesday, calendar: Self.utc) == 0)
    }

    // MARK: Daylight saving

    @Test func everyDayGetsOneSquareAcrossAMidnightClockChange() throws {
        let (calendar, noon) = try #require(Self.midnightClockChange())
        let now = noon.addingTimeInterval(3 * Self.day)
        let habit = CleanDaysHabit(start: noon.addingTimeInterval(-40 * Self.day), slips: [])
        let model = CleanDays(habits: [habit], now: now, calendar: calendar)
        let days = model.days

        #expect(days.count == 84)
        #expect(days.allSatisfy { calendar.startOfDay(for: $0.date) == $0.date })
        #expect(model.weeks.allSatisfy { calendar.component(.weekday, from: $0[0].date) == 2 })
        // The day that starts at 01:00 is there, once.
        #expect(days.filter { calendar.component(.hour, from: $0.date) == 1 }.count == 1)
        // Squares are consecutive calendar days. Noon on the first day plus whole days of seconds lands on each day
        // in turn, because a clock change moves it by an hour at most.
        let firstNoon = days[0].date.addingTimeInterval(12 * Self.hour)
        for (offset, cell) in days.enumerated() {
            let expected = calendar.dateComponents([.year, .month, .day], from: firstNoon.addingTimeInterval(Double(offset) * Self.day))
            #expect(calendar.dateComponents([.year, .month, .day], from: cell.date) == expected)
        }
        let clockChangeDay = try #require(days.first { calendar.isDate($0.date, inSameDayAs: noon) })
        #expect(clockChangeDay.status == .clean)
        #expect(model.today.map { calendar.isDate($0.date, inSameDayAs: now) } == true)
        #expect(CleanDays.count([noon], inLast: 7, now: now, calendar: calendar) == 1)
    }
}
