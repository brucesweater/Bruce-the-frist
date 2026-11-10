import Foundation
import SwiftData

/// A daily mission the user checked off by hand. Missions that complete on their own (taking the pledge, beating
/// a craving with SOS) are read from `Pledge` and `Urge` instead, so they only appear here when checked manually.
@Model
final class MissionCompletion {
    /// The day the mission belongs to, as a `StoredDay`.
    var day: Date = Date.now
    /// The `Mission.id` that was completed.
    var missionID: String = ""
    var completedAt: Date = Date.now

    init(day: Date, missionID: String, completedAt: Date = .now) {
        self.day = day
        self.missionID = missionID
        self.completedAt = completedAt
    }
}

/// One run through a multi-day challenge (the 30-Day Reset). Finished and left runs are kept, so the XP their
/// steps earned is never taken away.
@Model
final class ChallengeProgress {
    var challengeID: String = ""
    /// The challenge's first day, as a `StoredDay`.
    var startDay: Date = Date.now
    /// The challenge days (1-based) the user has completed.
    var completedDays: [Int] = []
    var joinedAt: Date = Date.now
    /// Set once every day is complete.
    var finishedAt: Date? = nil
    /// Set when the user leaves before finishing: the run stops showing, but its completed steps keep their XP.
    var leftAt: Date? = nil

    init(challengeID: String, startDay: Date) {
        self.challengeID = challengeID
        self.startDay = startDay
        self.joinedAt = .now
    }
}

/// A day saved without a time zone: the date the user was on, kept as 00:00 UTC on that (Gregorian) date. It reads
/// back as the same date in every time zone, so moving east or west never moves a pledge, a mission check-off or
/// the start of a 30-Day Reset to another day. Compare stored days by `EngagementCalendar.dayIndex(ofStored:)`,
/// never as a moment in the phone's current time zone.
enum StoredDay {
    /// The calendar stored days are written in.
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// The day containing `date` in `calendar`'s time zone, as a stored day.
    static func make(for date: Date, calendar: Calendar = .current) -> Date {
        let parts = gregorian(in: calendar.timeZone).dateComponents([.year, .month, .day], from: date)
        return utc.date(from: parts) ?? calendar.startOfDay(for: date)
    }

    /// The year, month and day of a stored day. It is read 12 hours on, so rows saved before stored days existed
    /// (at local midnight) still read as their own date if they were saved anywhere from UTC-11 to UTC+12.
    static func components(of day: Date) -> DateComponents {
        utc.dateComponents([.year, .month, .day], from: day.addingTimeInterval(12 * 3_600))
    }

    /// Start of a stored day in `calendar`'s time zone, for streaks, weekly counts and charts. Works from noon on
    /// that date, because in time zones that switch to daylight saving at midnight some days start at 01:00.
    static func localStart(of day: Date, calendar: Calendar = .current) -> Date {
        var parts = components(of: day)
        parts.hour = 12
        guard let noon = gregorian(in: calendar.timeZone).date(from: parts) else { return day }
        return calendar.startOfDay(for: noon)
    }

    private static func gregorian(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
