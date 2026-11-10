import Foundation
import SwiftData

/// A copy of the fields a widget needs, read from the shared store.
struct HabitSnapshot: Hashable {
    let name: String
    let emoji: String
    let theme: HabitTheme
    let streakStart: Date
    let bankedSeconds: Double
    let bestStreakSeconds: Double
    let dailyCost: Double
    let dailyMinutes: Double
    let unitsPerDay: Double

    init(habit: Habit, hidesDetails: Bool) {
        // With the app lock on, the widget shows the streak but not what the user is quitting.
        name = hidesDetails ? String(localized: "Your streak") : habit.name
        emoji = hidesDetails ? "✨" : habit.emoji
        theme = hidesDetails ? .grape : habit.theme
        streakStart = habit.streakStart
        bankedSeconds = habit.bankedSeconds
        bestStreakSeconds = habit.bestStreakSeconds
        dailyCost = habit.dailyCost
        dailyMinutes = habit.dailyMinutes
        unitsPerDay = habit.unitsPerDay
    }

    init(name: String, emoji: String, theme: HabitTheme, streakStart: Date, dailyCost: Double, dailyMinutes: Double) {
        self.name = name
        self.emoji = emoji
        self.theme = theme
        self.streakStart = streakStart
        self.bankedSeconds = 0
        self.bestStreakSeconds = 0
        self.dailyCost = dailyCost
        self.dailyMinutes = dailyMinutes
        self.unitsPerDay = 0
    }

    func stats(at date: Date) -> HabitStats {
        HabitStats(
            streakStart: streakStart,
            bankedSeconds: bankedSeconds,
            bestStreakSeconds: bestStreakSeconds,
            dailyCost: dailyCost,
            dailyMinutes: dailyMinutes,
            unitsPerDay: unitsPerDay,
            now: date
        )
    }

    /// Shown in the widget gallery.
    static let sample = HabitSnapshot(
        name: String(localized: "Smoking"),
        emoji: "🚬",
        theme: .fire,
        streakStart: .now.addingTimeInterval(-12 * 86_400 - 4 * 3_600),
        dailyCost: 10,
        dailyMinutes: 60
    )
}

enum WidgetDataLoader {
    /// The habit widgets show: the first one in the user's list.
    static func primaryHabit() -> HabitSnapshot? {
        let context = ModelContext(AppModelContainer.make())
        var descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortIndex)])
        descriptor.fetchLimit = 1
        guard let habit = (try? context.fetch(descriptor))?.first else { return nil }
        let hidesDetails = AppModelContainer.sharedDefaults?.bool(forKey: AppModelContainer.SharedKeys.hidesDetails) ?? false
        return HabitSnapshot(habit: habit, hidesDetails: hidesDetails)
    }

    static var currencyCode: String {
        AppModelContainer.sharedDefaults?.string(forKey: AppModelContainer.SharedKeys.currencyCode)
            ?? Locale.current.currency?.identifier
            ?? "USD"
    }
}
