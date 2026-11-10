import Foundation
import Observation

/// Remembers which achievements have ever unlocked (and when), and which ones the user hasn't seen yet, so the
/// Progress tab can mark new badges and an achievement that locks again (a lapsed pledge streak) keeps its XP.
///
/// `XPSummaryReader` records the current achievements whenever they change, and `RankUpObserver` keeps one reader
/// on screen at all times, so `isNew(_:)` is always up to date.
@MainActor
@Observable
final class AchievementTracker {
    static let shared = AchievementTracker(defaults: .standard)

    enum Keys {
        /// JSON object of achievement ID to first-unlock date.
        static let unlocked = "achievementTracker.unlocked"
        /// Array of IDs unlocked but not yet seen.
        static let new = "achievementTracker.new"
    }

    private let defaults: UserDefaults
    /// First-unlock date of every achievement that has ever unlocked.
    private(set) var unlockDates: [String: Date]
    /// Unlocked achievements the user hasn't looked at yet.
    private(set) var newIDs: Set<String>

    init(defaults: UserDefaults) {
        self.defaults = defaults
        unlockDates = Self.loadUnlockDates(from: defaults)
        newIDs = Set(defaults.stringArray(forKey: Keys.new) ?? [])
    }

    /// Every achievement that has ever unlocked.
    var unlockedIDs: Set<String> {
        Set(unlockDates.keys)
    }

    func isNew(_ achievementID: String) -> Bool {
        newIDs.contains(achievementID)
    }

    func unlockDate(for achievementID: String) -> Date? {
        unlockDates[achievementID]
    }

    func markAllSeen() {
        guard !newIDs.isEmpty else { return }
        newIDs = []
        save()
    }

    /// Records the unlocked ones among `achievements`. Returns those unlocked for the first time, which are also
    /// marked new.
    @discardableResult
    func record(_ achievements: [Achievement], now: Date = .now) -> [Achievement] {
        let fresh = achievements.filter { $0.isUnlocked && unlockDates[$0.id] == nil }
        guard !fresh.isEmpty else { return [] }
        var dates = unlockDates
        var unseen = newIDs
        for achievement in fresh {
            dates[achievement.id] = now
            unseen.insert(achievement.id)
        }
        unlockDates = dates
        newIDs = unseen
        save()
        return fresh
    }

    /// Forgets everything (used by "Erase all data").
    func reset() {
        if !unlockDates.isEmpty {
            unlockDates = [:]
        }
        if !newIDs.isEmpty {
            newIDs = []
        }
        defaults.removeObject(forKey: Keys.unlocked)
        defaults.removeObject(forKey: Keys.new)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(unlockDates) {
            defaults.set(data, forKey: Keys.unlocked)
        }
        defaults.set(newIDs.sorted(), forKey: Keys.new)
    }

    private static func loadUnlockDates(from defaults: UserDefaults) -> [String: Date] {
        guard let data = defaults.data(forKey: Keys.unlocked),
              let dates = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return [:] }
        return dates
    }
}
