import Foundation

/// Inputs that unlock achievements. Kept separate from SwiftData so the rules are easy to test.
struct AchievementInput {
    var habitCount = 0
    var bestStreak: TimeInterval = 0
    var cravingsBeaten = 0
    var moneySaved: Double = 0
    /// The currency `moneySaved` is in; the money thresholds scale with it.
    var currencyCode = "USD"
    var pledgeStreak = 0
    var totalPledges = 0
}

struct Achievement: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let theme: HabitTheme
    let isUnlocked: Bool

    static func evaluate(_ input: AchievementInput) -> [Achievement] {
        let day: TimeInterval = 86_400
        // About $100 and $1,000 in the user's currency, so in yen or dong the money badges don't unlock in minutes.
        let saverGoal = LocalPrice.threshold(fromUSD: 100, currencyCode: input.currencyCode)
        let bigSaverGoal = LocalPrice.threshold(fromUSD: 1_000, currencyCode: input.currencyCode)
        return [
            Achievement(id: "first-step", title: String(localized: "First Step"), detail: String(localized: "Start a streak"), symbol: "figure.walk", theme: .ocean, isUnlocked: input.habitCount > 0),
            Achievement(id: "day-1", title: String(localized: "24 Hours"), detail: String(localized: "One full day free"), symbol: "sun.max.fill", theme: .gold, isUnlocked: input.bestStreak >= day),
            Achievement(id: "week-1", title: String(localized: "Week Warrior"), detail: String(localized: "7 days free"), symbol: "star.fill", theme: .sunset, isUnlocked: input.bestStreak >= 7 * day),
            Achievement(id: "month-1", title: String(localized: "Monthly Master"), detail: String(localized: "30 days free"), symbol: "moon.stars.fill", theme: .grape, isUnlocked: input.bestStreak >= 30 * day),
            Achievement(id: "day-100", title: String(localized: "Centurion"), detail: String(localized: "100 days free"), symbol: "trophy.fill", theme: .fire, isUnlocked: input.bestStreak >= 100 * day),
            Achievement(id: "year-1", title: String(localized: "Year of Freedom"), detail: String(localized: "365 days free"), symbol: "crown.fill", theme: .gold, isUnlocked: input.bestStreak >= 365 * day),
            Achievement(id: "craving-1", title: String(localized: "Wave Rider"), detail: String(localized: "Beat a craving"), symbol: "water.waves", theme: .ocean, isUnlocked: input.cravingsBeaten >= 1),
            Achievement(id: "craving-25", title: String(localized: "Unshakeable"), detail: String(localized: "Beat 25 cravings"), symbol: "shield.lefthalf.filled", theme: .midnight, isUnlocked: input.cravingsBeaten >= 25),
            Achievement(id: "saved-100", title: String(localized: "Saver"), detail: String(localized: "Save \(MoneyFormatter.rounded(saverGoal, code: input.currencyCode))"), symbol: "banknote.fill", theme: .forest, isUnlocked: input.moneySaved >= saverGoal),
            Achievement(id: "saved-1000", title: String(localized: "Big Saver"), detail: String(localized: "Save \(MoneyFormatter.rounded(bigSaverGoal, code: input.currencyCode))"), symbol: "chart.line.uptrend.xyaxis", theme: .mint, isUnlocked: input.moneySaved >= bigSaverGoal),
            Achievement(id: "pledge-7", title: String(localized: "Committed"), detail: String(localized: "7-day pledge streak"), symbol: "hand.raised.fill", theme: .candy, isUnlocked: input.pledgeStreak >= 7),
            Achievement(id: "pledge-30", title: String(localized: "Devoted"), detail: String(localized: "30 pledges taken"), symbol: "heart.fill", theme: .candy, isUnlocked: input.totalPledges >= 30),
        ]
    }
}
