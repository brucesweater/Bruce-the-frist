import Foundation
import SwiftData

/// One day of the 30-Day Reset.
struct ChallengeStep: Identifiable, Equatable {
    let day: Int
    let title: String
    let detail: String
    let systemImage: String

    var id: Int { day }
}

/// The 30-Day Reset: one small, practical step a day for 30 days. Today's step and any earlier missed step can be
/// done at any time; later steps unlock day by day. Nothing expires and a slip never resets it.
enum ResetChallenge {
    static let id = "reset30"
    static let length = 30

    enum DayState: Equatable {
        case done
        /// Today's step, or an earlier one that can still be done.
        case open
        /// A later step that hasn't unlocked yet.
        case locked
    }

    static let steps: [ChallengeStep] = [
        step(1, "Write your why", "List your reasons for quitting and keep them somewhere you'll see every day.", "square.and.pencil"),
        step(2, "Map your triggers", "Notice the times, places, people and feelings that come right before an urge.", "map.fill"),
        step(3, "Clear your space", "Remove or hide one thing that makes the habit easy.", "archivebox.fill"),
        step(4, "Pick your go-to swap", "Choose one thing you'll do instead when an urge hits: a walk, water, gum, a song.", "arrow.triangle.swap"),
        step(5, "Tell one person", "Share your goal with someone you trust. Support makes it easier.", "person.2.fill"),
        step(6, "Practice urge surfing", "When a craving comes, rate it from 1 to 10 and watch it rise and fall like a wave.", "water.waves"),
        step(7, "Celebrate week one", "Look back at this week and give yourself real credit.", "party.popper.fill"),
        step(8, "Move your body", "Take a 15-minute walk, or any movement you enjoy.", "figure.walk"),
        step(9, "Protect your sleep", "Pick a wind-down time tonight and keep your phone out of bed.", "bed.double.fill"),
        step(10, "Plan your toughest hour", "Choose the hardest time of your day and plan exactly what you'll do then.", "calendar.badge.clock"),
        step(11, "Make an if-then plan", "Write \"If [trigger] happens, then I will [action].\" A plan made ahead is easier to follow.", "arrow.branch"),
        step(12, "Eat and drink well", "Have regular meals and plenty of water. Hunger and thirst can feel a lot like cravings.", "fork.knife"),
        step(13, "Try a breathing reset", "Breathe in for 4, hold for 4, breathe out for 6. Repeat five times.", "wind"),
        step(14, "Count your wins", "Look at the money and time you've won back in two weeks.", "banknote.fill"),
        step(15, "Rewrite one thought", "Catch an \"I can't\" thought and rewrite it kindly: \"This is hard, and I'm doing it.\"", "brain.head.profile"),
        step(16, "Find your people", "Look for a friend, group or community on the same path.", "person.3.fill"),
        step(17, "Learn your patterns", "Open Progress and look at when your cravings show up. What do you notice?", "chart.bar.fill"),
        step(18, "Be kind to yourself", "A long shower, a favorite meal, an early night. You deserve care.", "heart.fill"),
        step(19, "Make a slip plan", "Decide now what you'll do if you slip: be kind, learn what happened, keep going.", "lifepreserver.fill"),
        step(20, "Get outside", "Spend 20 minutes in daylight or nature.", "leaf.fill"),
        step(21, "Say thank you", "Thank someone who has supported you, even in a small way.", "envelope.fill"),
        step(22, "Start something new", "Begin a small hobby or project to fill the time the habit used to take.", "paintbrush.fill"),
        step(23, "Design your evenings", "Plan a calm evening routine you'll actually look forward to.", "moon.stars.fill"),
        step(24, "Notice what's easier", "Write down three things that feel easier now than they did a month ago.", "chart.line.uptrend.xyaxis"),
        step(25, "Plan for a big day", "Think of an upcoming party, trip or stressful day and plan how you'll handle it.", "calendar"),
        step(26, "Write to future you", "Leave a short note for yourself to read a year from now.", "envelope.open.fill"),
        step(27, "Encourage someone", "Cheer on someone working on something hard. Helping others strengthens you too.", "heart.circle.fill"),
        step(28, "Treat yourself", "Spend some of what you've saved on something that makes you happy.", "gift.fill"),
        step(29, "Name who you're becoming", "Finish the sentence \"I'm someone who…\" and keep it close.", "person.crop.circle.badge.checkmark"),
        step(30, "Celebrate and choose your next 30", "Look how far you've come, then pick one goal for the next 30 days.", "trophy.fill"),
    ]

    /// The step for `day`, clamped to 1...30.
    static func step(for day: Int) -> ChallengeStep {
        steps[min(max(day, 1), steps.count) - 1]
    }

    /// The challenge day it is now: days since `startDay` plus one, capped at 30.
    static func currentDay(for progress: ChallengeProgress, now: Date = .now, calendar: Calendar = .current) -> Int {
        let elapsed = EngagementCalendar.dayIndex(for: now, calendar: calendar)
            - EngagementCalendar.dayIndex(for: progress.startDay, calendar: calendar)
        return min(max(elapsed + 1, 1), length)
    }

    static func isFinished(_ progress: ChallengeProgress) -> Bool {
        progress.finishedAt != nil || completedCount(in: progress) >= length
    }

    /// Distinct, valid days completed (also what the run's XP is counted from).
    static func completedCount(in progress: ChallengeProgress) -> Int {
        Set(progress.completedDays.filter { (1...length).contains($0) }).count
    }

    static func state(ofDay day: Int, in progress: ChallengeProgress, now: Date = .now, calendar: Calendar = .current) -> DayState {
        if progress.completedDays.contains(day) || progress.finishedAt != nil {
            return .done
        }
        return day <= currentDay(for: progress, now: now, calendar: calendar) ? .open : .locked
    }

    /// Earlier days that weren't done and still can be.
    static func openEarlierDays(in progress: ChallengeProgress, now: Date = .now, calendar: Calendar = .current) -> [Int] {
        let today = currentDay(for: progress, now: now, calendar: calendar)
        guard today > 1, !isFinished(progress) else { return [] }
        return (1..<today).filter { !progress.completedDays.contains($0) }
    }

    /// Marks today's step or an earlier one done, and finishes the run once all 30 are done. Returns false when
    /// nothing changed (already done, a locked day, or a run that was left).
    @discardableResult
    static func markDone(day: Int, in progress: ChallengeProgress, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard progress.leftAt == nil,
              (1...length).contains(day),
              !progress.completedDays.contains(day),
              day <= currentDay(for: progress, now: now, calendar: calendar)
        else { return false }
        progress.completedDays = (progress.completedDays + [day]).sorted()
        if progress.finishedAt == nil && completedCount(in: progress) >= length {
            progress.finishedAt = now
        }
        return true
    }

    /// Un-checks today's step (tapped by mistake). Earlier days and finished runs stay as they are.
    @discardableResult
    static func unmark(day: Int, in progress: ChallengeProgress, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard progress.leftAt == nil,
              !isFinished(progress),
              day == currentDay(for: progress, now: now, calendar: calendar),
              progress.completedDays.contains(day)
        else { return false }
        progress.completedDays = progress.completedDays.filter { $0 != day }
        return true
    }

    /// The unfinished run the user is on, if any (there's at most one).
    static func activeRun(in runs: [ChallengeProgress]) -> ChallengeProgress? {
        runs.filter { $0.challengeID == id && $0.leftAt == nil && !isFinished($0) }
            .max { $0.joinedAt < $1.joinedAt }
    }

    /// The run to show: the active one, or else the latest run if it was finished (not left). Nil means "not joined".
    static func current(in runs: [ChallengeProgress]) -> ChallengeProgress? {
        if let active = activeRun(in: runs) {
            return active
        }
        guard let latest = runs.filter({ $0.challengeID == id }).max(by: { $0.joinedAt < $1.joinedAt }),
              latest.leftAt == nil
        else { return nil }
        return latest
    }

    /// Starts a new run today, unless one is already active (then that one is returned).
    @discardableResult
    static func start(existing runs: [ChallengeProgress], in context: ModelContext, now: Date = .now, calendar: Calendar = .current) -> ChallengeProgress {
        if let active = activeRun(in: runs) {
            return active
        }
        let run = ChallengeProgress(challengeID: id, startDay: calendar.startOfDay(for: now))
        run.joinedAt = now
        context.insert(run)
        return run
    }

    /// Leaves a run. A run with completed steps is kept (marked as left) so its XP stays; an empty one is deleted.
    static func leave(_ progress: ChallengeProgress, in context: ModelContext, now: Date = .now) {
        if completedCount(in: progress) == 0 {
            context.delete(progress)
        } else {
            progress.leftAt = now
        }
    }

    private static func step(_ day: Int, _ title: String.LocalizationValue, _ detail: String.LocalizationValue, _ symbol: String) -> ChallengeStep {
        ChallengeStep(day: day, title: String(localized: title), detail: String(localized: detail), systemImage: symbol)
    }
}
