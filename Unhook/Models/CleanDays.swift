import Foundation

/// The parts of a habit the clean-days calendar needs: when its first clean streak began and when each slip
/// happened. A plain value so the calendar math is easy to test.
struct CleanDaysHabit: Equatable {
    /// When the habit's first clean streak began.
    let start: Date
    /// When each slip happened.
    let slips: [Date]
}

extension CleanDaysHabit {
    /// Tracking began with the habit's first streak: the current streak's start, or earlier when slips ended
    /// streaks before it (each slip stores how long the streak it ended had lasted).
    init(habit: Habit) {
        var start = habit.streakStart
        var slips: [Date] = []
        for relapse in habit.relapses {
            slips.append(relapse.date)
            let streak = relapse.streakSeconds.isFinite ? max(0, relapse.streakSeconds) : 0
            start = min(start, relapse.date.addingTimeInterval(-streak))
        }
        self.init(start: start, slips: slips)
    }
}

/// One square of the clean-days calendar.
struct CleanDay: Identifiable, Equatable {
    enum Status: Equatable {
        /// No habit was being tracked yet.
        case untracked
        /// Every habit tracked that day stayed clean.
        case clean
        /// At least one habit slipped that day.
        case slip
        /// Later this week: it hasn't happened yet.
        case future
    }

    /// Start of the day in the calendar's time zone.
    let date: Date
    let status: Status
    /// Habits being tracked that day, slipped ones included.
    let trackedHabits: Int
    /// Habits that stayed clean that day.
    let cleanHabits: Int
    let isToday: Bool

    var id: Date { date }
}

/// The Progress tab's clean-days heat map: the last `weekCount` weeks as columns of seven days (Monday first),
/// with the current week, today included, in the last column. Pure value type, so it is easy to test.
///
/// Days are stepped one at a time from the start of a day (never by adding 24 hours), so days of 23 or 25 hours
/// and days that start at 01:00 (daylight saving at midnight) each get exactly one square.
struct CleanDays: Equatable {
    /// A month name above the calendar.
    struct MonthLabel: Identifiable, Equatable {
        /// The column (week) the label sits over.
        let column: Int
        /// A day in the month to name.
        let date: Date

        var id: Int { column }
    }

    static let defaultWeekCount = 12
    static let daysPerWeek = 7
    /// Month labels closer than this many columns would overlap.
    static let minimumLabelSpacing = 3

    /// Columns, oldest first. Each holds seven days, Monday first.
    let weeks: [[CleanDay]]
    /// Month names to show over the columns, left to right.
    let monthLabels: [MonthLabel]
    /// Habits being tracked in all. A clean day glows brighter the more of them stayed clean.
    let habitCount: Int

    init(habits: [CleanDaysHabit], weekCount: Int = defaultWeekCount, now: Date = .now, calendar: Calendar = .current) {
        let weekCount = max(weekCount, 1)
        let today = calendar.startOfDay(for: now)
        let todayRow = Self.weekdayRow(of: today, calendar: calendar)

        // From the Monday `weekCount - 1` weeks back up to today, oldest first...
        var past: [Date] = [today]
        var cursor = today
        for _ in 0..<((weekCount - 1) * Self.daysPerWeek + todayRow) {
            cursor = calendar.startOfPreviousDay(before: cursor)
            past.append(cursor)
        }
        past.reverse()
        // ...then the rest of this week.
        var future: [Date] = []
        cursor = today
        for _ in 0..<(Self.daysPerWeek - 1 - todayRow) {
            cursor = Self.startOfNextDay(after: cursor, calendar: calendar)
            future.append(cursor)
        }

        let prepared = habits.map { PreparedHabit($0, calendar: calendar) }
        var days = past.map { Self.day($0, habits: prepared, isToday: $0 == today) }
        days += future.map { CleanDay(date: $0, status: .future, trackedHabits: 0, cleanHabits: 0, isToday: false) }

        var columns: [[CleanDay]] = []
        var start = 0
        while start < days.count {
            let end = min(start + Self.daysPerWeek, days.count)
            columns.append(Array(days[start..<end]))
            start = end
        }
        weeks = columns
        monthLabels = Self.monthLabels(for: columns, calendar: calendar)
        habitCount = habits.count
    }

    // MARK: Summary

    /// Every day in the calendar, oldest first.
    var days: [CleanDay] { weeks.flatMap { $0 } }

    /// Today's square.
    var today: CleanDay? { days.first { $0.isToday } }

    var cleanDayCount: Int { days.filter { $0.status == .clean }.count }

    var slipDayCount: Int { days.filter { $0.status == .slip }.count }

    /// Days on which at least one habit was being tracked.
    var trackedDayCount: Int { days.filter { $0.trackedHabits > 0 }.count }

    /// Clean days among the last `count` days, today included.
    func cleanDays(inLast count: Int) -> Int {
        days.filter { $0.status != .future }
            .suffix(max(count, 0))
            .filter { $0.status == .clean }
            .count
    }

    /// How brightly a day glows, 0...1: for a clean day, the share of all habits that stayed clean; 0 otherwise.
    func intensity(of day: CleanDay) -> Double {
        guard day.status == .clean, day.cleanHabits > 0 else { return 0 }
        let total = max(habitCount, day.trackedHabits, 1)
        return min(1, Double(day.cleanHabits) / Double(total))
    }

    // MARK: Day helpers

    /// Start of the first of the last `days` days, today included (today's start for 1 or fewer).
    static func firstDay(ofLast days: Int, now: Date = .now, calendar: Calendar = .current) -> Date {
        var start = calendar.startOfDay(for: now)
        var remaining = days - 1
        while remaining > 0 {
            start = calendar.startOfPreviousDay(before: start)
            remaining -= 1
        }
        return start
    }

    /// How many of `dates` fall on the last `days` days, today included.
    static func count(_ dates: [Date], inLast days: Int, now: Date = .now, calendar: Calendar = .current) -> Int {
        guard days > 0 else { return 0 }
        let start = firstDay(ofLast: days, now: now, calendar: calendar)
        let end = startOfNextDay(after: calendar.startOfDay(for: now), calendar: calendar)
        return dates.filter { $0 >= start && $0 < end }.count
    }

    /// The calendar row of a day: 0 for Monday through 6 for Sunday.
    static func weekdayRow(of date: Date, calendar: Calendar) -> Int {
        // Calendar weekdays run from 1 (Sunday) to 7 (Saturday).
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    // MARK: Private

    private struct PreparedHabit {
        let startDay: Date
        let slipDays: Set<Date>

        init(_ habit: CleanDaysHabit, calendar: Calendar) {
            startDay = calendar.startOfDay(for: habit.start)
            slipDays = Set(habit.slips.map { calendar.startOfDay(for: $0) })
        }
    }

    private static func day(_ date: Date, habits: [PreparedHabit], isToday: Bool) -> CleanDay {
        var tracked = 0
        var clean = 0
        for habit in habits {
            if habit.slipDays.contains(date) {
                tracked += 1
            } else if habit.startDay <= date {
                tracked += 1
                clean += 1
            }
        }
        let status: CleanDay.Status
        if tracked == 0 {
            status = .untracked
        } else if clean < tracked {
            status = .slip
        } else {
            status = .clean
        }
        return CleanDay(date: date, status: status, trackedHabits: tracked, cleanHabits: clean, isToday: isToday)
    }

    /// Start of the day after the day that starts at `dayStart`.
    private static func startOfNextDay(after dayStart: Date, calendar: Calendar) -> Date {
        if let interval = calendar.dateInterval(of: .day, for: dayStart) {
            return calendar.startOfDay(for: interval.end)
        }
        // A day lasts 23 to 25 hours, so 36 hours on always lands inside the next one.
        return calendar.startOfDay(for: dayStart.addingTimeInterval(36 * 3_600))
    }

    /// The column holding a month's first day (one that has already happened) gets that month's name. The first
    /// column is named too, unless the next label is too close to fit.
    private static func monthLabels(for weeks: [[CleanDay]], calendar: Calendar) -> [MonthLabel] {
        var labels: [MonthLabel] = []
        for (column, week) in weeks.enumerated() {
            let firstOfMonth = week.first { day in
                day.status != .future && calendar.component(.day, from: day.date) == 1
            }
            if let firstOfMonth {
                labels.append(MonthLabel(column: column, date: firstOfMonth.date))
            }
        }
        let nextColumn = labels.first?.column ?? weeks.count
        if nextColumn >= minimumLabelSpacing, let firstDay = weeks.first?.first {
            labels.insert(MonthLabel(column: 0, date: firstDay.date), at: 0)
        }
        return labels
    }
}
