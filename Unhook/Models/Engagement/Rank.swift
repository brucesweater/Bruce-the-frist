import Foundation

/// A level on the night-to-day path, from Midnight to Legend. XP only ever goes up, so a rank is never lost to a slip.
struct Rank: Identifiable, Equatable {
    let level: Int
    let title: String
    let symbol: String
    let minXP: Int

    var id: Int { level }

    static let all: [Rank] = [
        Rank(level: 1, title: String(localized: "Midnight", comment: "Rank 1 of 12"), symbol: "moon.stars.fill", minXP: 0),
        Rank(level: 2, title: String(localized: "Starlight", comment: "Rank 2 of 12"), symbol: "sparkles", minXP: 100),
        Rank(level: 3, title: String(localized: "Moonrise", comment: "Rank 3 of 12"), symbol: "moon.haze.fill", minXP: 250),
        Rank(level: 4, title: String(localized: "First Light", comment: "Rank 4 of 12"), symbol: "sun.horizon.fill", minXP: 500),
        Rank(level: 5, title: String(localized: "Dawn", comment: "Rank 5 of 12"), symbol: "sunrise.fill", minXP: 900),
        Rank(level: 6, title: String(localized: "Sunrise", comment: "Rank 6 of 12"), symbol: "sun.min.fill", minXP: 1_500),
        Rank(level: 7, title: String(localized: "Morning Sun", comment: "Rank 7 of 12"), symbol: "sun.max.fill", minXP: 2_400),
        Rank(level: 8, title: String(localized: "Daylight", comment: "Rank 8 of 12"), symbol: "sun.max.circle.fill", minXP: 3_600),
        Rank(level: 9, title: String(localized: "Golden Hour", comment: "Rank 9 of 12"), symbol: "sun.and.horizon.fill", minXP: 5_200),
        Rank(level: 10, title: String(localized: "Radiant", comment: "Rank 10 of 12"), symbol: "rays", minXP: 7_500),
        Rank(level: 11, title: String(localized: "Unhooked", comment: "Rank 11 of 12"), symbol: "star.circle.fill", minXP: 10_500),
        Rank(level: 12, title: String(localized: "Legend", comment: "Rank 12 of 12"), symbol: "crown.fill", minXP: 15_000),
    ]

    /// The highest rank `xp` has reached.
    static func rank(for xp: Int) -> Rank {
        all.last { $0.minXP <= xp } ?? all[0]
    }

    /// The rank after `rank`, or nil at the top.
    static func next(after rank: Rank) -> Rank? {
        all.first { $0.level == rank.level + 1 }
    }

    /// A warm line for the rank-up moment that grows with the rank.
    var encouragement: String {
        switch level {
        case ..<5:
            return String(localized: "The night is lifting. Every small win brought you here.")
        case ..<9:
            return String(localized: "Your sky keeps getting brighter. Look how far you've come.")
        default:
            return String(localized: "You're glowing. This is who you are now.")
        }
    }
}
