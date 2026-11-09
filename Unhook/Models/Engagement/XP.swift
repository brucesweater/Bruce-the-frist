import Foundation

/// How much XP each kind of progress earns.
enum XPRewards {
    static let perCleanDay = 10
    static let perPledge = 15
    static let perCravingBeaten = 20
    static let perMission = 10
    static let perPerfectDay = 15
    static let perChallengeDay = 25
    static let perAchievement = 50
    /// Beaten cravings that earn XP each day, so opening SOS over and over can't farm XP.
    static let maxCravingsPerDay = 5
}

/// One way of earning XP and how often the user has done it, for "How to earn XP".
struct XPSource: Identifiable, Equatable {
    enum Kind: String, CaseIterable {
        case cleanDays, pledges, cravings, missions, perfectDays, challengeDays, achievements
    }

    let kind: Kind
    let count: Int

    var id: String { kind.rawValue }
    var xpEach: Int { kind.xpEach }
    var xp: Int { count * kind.xpEach }
}

extension XPSource.Kind {
    var xpEach: Int {
        switch self {
        case .cleanDays: XPRewards.perCleanDay
        case .pledges: XPRewards.perPledge
        case .cravings: XPRewards.perCravingBeaten
        case .missions: XPRewards.perMission
        case .perfectDays: XPRewards.perPerfectDay
        case .challengeDays: XPRewards.perChallengeDay
        case .achievements: XPRewards.perAchievement
        }
    }

    var title: String {
        switch self {
        case .cleanDays: String(localized: "Each clean day")
        case .pledges: String(localized: "Each daily pledge")
        case .cravings: String(localized: "Each craving you beat, up to \(XPRewards.maxCravingsPerDay) a day")
        case .missions: String(localized: "Each daily mission")
        case .perfectDays: String(localized: "All 3 missions in a day")
        case .challengeDays: String(localized: "Each 30-Day Reset step")
        case .achievements: String(localized: "Each achievement")
        }
    }

    var systemImage: String {
        switch self {
        case .cleanDays: "flame.fill"
        case .pledges: "hand.raised.fill"
        case .cravings: "shield.lefthalf.filled"
        case .missions: "target"
        case .perfectDays: "sparkles"
        case .challengeDays: "sunrise.fill"
        case .achievements: "rosette"
        }
    }
}

/// The user's XP total, rank and progress toward the next rank.
struct XPSummary: Equatable {
    let total: Int
    let rank: Rank
    let nextRank: Rank?
    /// Progress from the current rank toward the next one, in 0...1 (1 at the top rank).
    let progressToNext: Double
    /// XP still needed for the next rank, or nil at the top rank.
    let xpToNext: Int?
    /// Where the XP came from. Empty when the summary was made from a total alone.
    var sources: [XPSource] = []
}

extension XPSummary {
    /// The rank and progress for `total` XP.
    init(total: Int, sources: [XPSource] = []) {
        let clamped = max(total, 0)
        let rank = Rank.rank(for: clamped)
        let next = Rank.next(after: rank)
        var progress = 1.0
        var remaining: Int?
        if let next {
            let span = max(next.minXP - rank.minXP, 1)
            progress = min(max(Double(clamped - rank.minXP) / Double(span), 0), 1)
            remaining = max(next.minXP - clamped, 0)
        }
        self.init(total: clamped, rank: rank, nextRank: next, progressToNext: progress, xpToNext: remaining, sources: sources)
    }
}

/// Computes XP from what the user has done. XP is never stored, so nothing can erase it: a slip banks the streak's
/// clean time instead of deleting it, and pledges, beaten cravings, missions and challenge steps stay on record.
enum XPCalculator {
    static func summary(
        habits: [Habit],
        pledges: [Pledge],
        urges: [Urge],
        missions: [MissionCompletion],
        challenges: [ChallengeProgress],
        unlockedAchievementCount: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> XPSummary {
        let cleanSeconds = habits.reduce(0.0) { $0 + $1.stats(at: now).lifetimeClean }
        let cleanDays = (cleanSeconds / 86_400).rounded(.down).clampedWholeNumber

        let pledgeDays = Set(pledges.map { EngagementCalendar.dayIndex(ofStored: $0.day) })
        var cravingsByDay: [Int: Int] = [:]
        for urge in urges where urge.resisted {
            cravingsByDay[EngagementCalendar.dayIndex(for: urge.date, calendar: calendar), default: 0] += 1
        }
        let cravingDays = Set(cravingsByDay.keys)
        let countedCravings = cravingsByDay.values.reduce(0) { $0 + min($1, XPRewards.maxCravingsPerDay) }
        var checkedByDay: [Int: Set<String>] = [:]
        for completion in missions {
            let day = EngagementCalendar.dayIndex(ofStored: completion.day)
            checkedByDay[day, default: []].insert(completion.missionID)
        }
        let tally = missionTally(pledgeDays: pledgeDays, cravingDays: cravingDays, checkedByDay: checkedByDay)
        let challengeDays = challenges.reduce(0) { $0 + ResetChallenge.completedCount(in: $1) }

        let sources = [
            XPSource(kind: .cleanDays, count: cleanDays),
            XPSource(kind: .pledges, count: pledgeDays.count),
            XPSource(kind: .cravings, count: countedCravings),
            XPSource(kind: .missions, count: tally.missions),
            XPSource(kind: .perfectDays, count: tally.perfectDays),
            XPSource(kind: .challengeDays, count: challengeDays),
            XPSource(kind: .achievements, count: max(unlockedAchievementCount, 0)),
        ]
        return XPSummary(total: sources.reduce(0) { $0 + $1.xp }, sources: sources)
    }

    /// Missions completed and perfect days, counted day by day from what happened on each day. Counts don't depend
    /// on which pool missions a day showed, so a future change to the pool can never take XP away.
    static func missionTally(
        pledgeDays: Set<Int>,
        cravingDays: Set<Int>,
        checkedByDay: [Int: Set<String>]
    ) -> (missions: Int, perfectDays: Int) {
        let activeDays = pledgeDays.union(cravingDays).union(checkedByDay.keys)
        var missions = 0
        var perfectDays = 0
        for day in activeDays {
            let done = DailyMissions.completedCount(
                onDayIndex: day,
                pledged: pledgeDays.contains(day),
                beatCraving: cravingDays.contains(day),
                checkedIDs: checkedByDay[day] ?? []
            )
            missions += done
            if done >= DailyMissions.missionsPerDay {
                perfectDays += 1
            }
        }
        return (missions, perfectDays)
    }
}
