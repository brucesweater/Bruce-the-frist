import Foundation
import SwiftData

/// Day arithmetic shared by daily missions, tips and the 30-Day Reset.
enum EngagementCalendar {
    /// Whole days from 1 January 2024 to the day containing `date`, in `calendar`'s time zone. Counts calendar
    /// dates rather than elapsed seconds, so days of 23 or 25 hours (daylight saving) never shift it, and the
    /// result is the same whatever calendar system (Gregorian, Buddhist, Japanese…) the user has picked.
    static func dayIndex(for date: Date, calendar: Calendar = .current) -> Int {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        return dayIndex(of: gregorian.dateComponents([.year, .month, .day], from: date))
    }

    /// The day index of a `StoredDay` (a pledge, a mission check-off, the start of a 30-Day Reset). It is the same
    /// in every time zone, and equals `dayIndex(for:calendar:)` of the moment it was saved, in the zone it was saved in.
    static func dayIndex(ofStored day: Date) -> Int {
        dayIndex(of: StoredDay.components(of: day))
    }

    /// Whole days from 1 January 2024 to a Gregorian date.
    private static func dayIndex(of parts: DateComponents) -> Int {
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return 0 }
        return daysFromCivil(year: year, month: month, day: day) - daysFromCivil(year: 2024, month: 1, day: 1)
    }

    /// `value` modulo `divisor`, always in `0..<divisor` (Swift's `%` keeps the sign of `value`).
    static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        guard divisor > 0 else { return 0 }
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }

    /// `value / divisor` rounded toward negative infinity (Swift's `/` rounds toward zero).
    static func floorDivision(_ value: Int, _ divisor: Int) -> Int {
        guard divisor > 0 else { return 0 }
        return value >= 0 ? value / divisor : (value - divisor + 1) / divisor
    }

    /// Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's `days_from_civil`).
    private static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let shiftedMonth = (month + 9) % 12
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }
}

/// UserDefaults keys used by the engagement layer.
enum EngagementKeys {
    /// The highest rank level already celebrated (0 until the app first sees the user's rank).
    static let lastSeenRankLevel = "lastSeenRankLevel"
}

/// Housekeeping for the engagement records.
@MainActor
enum EngagementData {
    /// Clears mission check-offs and challenge runs, and forgets unlocked achievements and the last rank seen.
    /// Runs after "Erase all data" in Settings so a fresh start really starts at Midnight, level 1.
    static func eraseAll(in context: ModelContext) {
        for completion in (try? context.fetch(FetchDescriptor<MissionCompletion>())) ?? [] {
            context.delete(completion)
        }
        for run in (try? context.fetch(FetchDescriptor<ChallengeProgress>())) ?? [] {
            context.delete(run)
        }
        try? context.save()
        AchievementTracker.shared.reset()
        UserDefaults.standard.removeObject(forKey: EngagementKeys.lastSeenRankLevel)
        NotificationManager.setChallengeActive(false)
    }
}
