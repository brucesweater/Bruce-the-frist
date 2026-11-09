import Foundation
import SwiftData

/// A daily mission the user checked off by hand. Missions that complete on their own (taking the pledge, beating
/// a craving with SOS) are read from `Pledge` and `Urge` instead, so they only appear here when checked manually.
@Model
final class MissionCompletion {
    /// Start of the day the mission belongs to.
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
    /// Start of the challenge's first day.
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
