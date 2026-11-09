import Foundation

/// A small, kind action for today. Three a day, the same all day.
struct Mission: Identifiable, Equatable {
    /// Stable identifier, stored in `MissionCompletion`. Never change an existing one.
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let kind: Kind

    enum Kind: Equatable {
        /// The user checks it off themselves.
        case selfReported
        /// Done automatically when today's pledge is taken.
        case pledge
        /// Done automatically when a craving is beaten (SOS or the Siri shortcut). It can also be checked off by
        /// hand, so a day without cravings never stands between the user and a perfect day.
        case sos
    }
}

/// Today's three missions: always the pledge first, then two from a rotating pool of small actions. Every third day
/// the last one is "Beat one craving with SOS".
enum DailyMissions {
    static let missionsPerDay = 3

    static let pledgeMission = Mission(
        id: "pledge",
        title: String(localized: "Take today's pledge"),
        detail: String(localized: "Commit to one clean day. Just today."),
        systemImage: "hand.raised.fill",
        kind: .pledge
    )

    static let sosMission = Mission(
        id: "sos",
        title: String(localized: "Beat one craving with SOS"),
        detail: String(localized: "When a craving hits, open SOS and ride it out."),
        systemImage: "wind",
        kind: .sos
    )

    /// Self-reported missions, walked in a different order on each pass. Append new ones at the end; never reuse an id.
    static let pool: [Mission] = [
        mission("water", "Drink a full glass of water", "Best the moment a craving hits. Sip it slowly.", "drop.fill"),
        mission("walk", "Take a 10-minute walk", "No destination needed. Moving takes the edge off.", "figure.walk"),
        mission("reason", "Write one reason you're quitting", "One sentence is enough. Read it again tonight.", "square.and.pencil"),
        mission("text", "Text someone you trust", "Just say hi. Connection makes cravings quieter.", "message.fill"),
        mission("toughest-hour", "Plan your toughest hour", "Pick the time cravings hit hardest and decide what you'll do instead.", "calendar.badge.clock"),
        mission("daylight", "Get 5 minutes of daylight", "Step outside or sit by a window. Light lifts your mood.", "sun.max.fill"),
        mission("stretch", "Stretch for 3 minutes", "Neck, shoulders, back. Let the tension go.", "figure.flexibility"),
        mission("tidy", "Tidy one small space", "A drawer, your desk, your bag. Small order, clearer head.", "wand.and.stars"),
        mission("meal", "Eat a real meal, slowly", "Put the phone away and actually taste it.", "fork.knife"),
        mission("breaths", "Take 10 slow breaths before bed", "In through your nose, out through your mouth. Let the day go.", "wind"),
        mission("phone-away", "Put your phone in another room for an hour", "Notice how the urge to check fades.", "iphone.slash"),
        mission("grateful", "Write one thing you're grateful for", "Big or tiny, it counts.", "heart.text.square.fill"),
        mission("song", "Listen to a song you love", "Really listen, start to finish.", "music.note"),
        mission("share", "Tell someone about your streak", "Saying it out loud makes it real.", "person.2.fill"),
        mission("swap-cue", "Swap one cue for something new", "Change the moment the habit usually starts: a new route, a new mug, a new spot.", "arrow.triangle.2.circlepath"),
        mission("cold-water", "Splash cold water on your face", "A quick reset when stress builds.", "snowflake"),
        mission("early-night", "Go to bed 30 minutes earlier", "Tired brains crave more. Give yours a head start.", "bed.double.fill"),
        mission("snack", "Keep a healthy snack within reach", "Something crunchy helps when a craving hits.", "carrot.fill"),
        mission("future-you", "Picture yourself a year from now", "Free, calmer, proud. Spend one minute there.", "binoculars.fill"),
        mission("remove-trigger", "Move one reminder of the habit out of sight", "Out of sight really does help.", "archivebox.fill"),
        mission("kindness", "Do one kind thing for someone", "Hold a door, send a compliment. It lifts you too.", "gift.fill"),
        mission("move", "Move for 2 minutes", "Squats, a dance, a few flights of stairs. Anything that gets you going.", "figure.run"),
        mission("savings", "Check what you've won back", "Look at the money and time you've saved. That's all you.", "banknote.fill"),
        mission("offline-hour", "Spend one hour offline", "Read, cook, build, draw. Anything without a screen.", "book.fill"),
        mission("name-feeling", "Name today's feeling", "Write it down in one word. Naming it softens it.", "face.smiling"),
        mission("outside", "Step outside without your phone", "Even 5 minutes. Notice three things you can hear.", "leaf.fill"),
        mission("warm-drink", "Make yourself a warm drink", "Tea, cocoa, warm water with lemon. A small ritual just for you.", "cup.and.saucer.fill"),
        mission("reward", "Plan a small reward for this week", "Something you'll enjoy with the money or time you've freed up.", "star.fill"),
        mission("learn", "Learn something new for 10 minutes", "A video, an article, a few pages. Feed your curiosity.", "lightbulb.fill"),
        mission("win", "Write down one win from today", "Big or small, it counts.", "checkmark.seal.fill"),
    ]

    static func missions(for day: Date, calendar: Calendar = .current) -> [Mission] {
        missions(forDayIndex: EngagementCalendar.dayIndex(for: day, calendar: calendar))
    }

    /// The three missions for a day index (see `EngagementCalendar.dayIndex(for:calendar:)`).
    static func missions(forDayIndex day: Int) -> [Mission] {
        let first = poolMission(at: 2 * day)
        if isSOSDay(day) {
            return [pledgeMission, first, sosMission]
        }
        var second = poolMission(at: 2 * day + 1)
        if second.id == first.id {
            second = poolMission(at: 2 * day + 2)
        }
        return [pledgeMission, first, second]
    }

    /// Every third day the last slot is the SOS mission.
    static func isSOSDay(_ day: Int) -> Bool {
        EngagementCalendar.positiveModulo(day, 3) == 0
    }

    static func isCompleted(
        _ mission: Mission,
        on day: Date,
        completions: [MissionCompletion],
        pledges: [Pledge],
        urges: [Urge],
        calendar: Calendar = .current
    ) -> Bool {
        let checked = completions.contains { $0.missionID == mission.id && calendar.isDate($0.day, inSameDayAs: day) }
        switch mission.kind {
        case .selfReported:
            return checked
        case .pledge:
            return pledges.contains { calendar.isDate($0.day, inSameDayAs: day) }
        case .sos:
            return checked || urges.contains { $0.resisted && calendar.isDate($0.date, inSameDayAs: day) }
        }
    }

    /// How many of a day's missions are done, from what happened that day.
    static func completedCount(onDayIndex day: Int, pledged: Bool, beatCraving: Bool, checkedIDs: Set<String>) -> Int {
        let sosDay = isSOSDay(day)
        let selfChecked = checkedIDs.subtracting([pledgeMission.id, sosMission.id]).count
        var done = min(selfChecked, sosDay ? 1 : 2)
        if pledged {
            done += 1
        }
        if sosDay && (beatCraving || checkedIDs.contains(sosMission.id)) {
            done += 1
        }
        return done
    }

    /// Walks the pool two missions a day. Each pass of the pool uses a different stride, so the same missions
    /// don't always come in the same pairs, and nothing repeats within a pass (about two weeks).
    private static func poolMission(at position: Int) -> Mission {
        let count = pool.count
        let pass = EngagementCalendar.floorDivision(position, count)
        let offset = EngagementCalendar.positiveModulo(position, count)
        let steps = strides
        let step = steps[EngagementCalendar.positiveModulo(pass, steps.count)]
        return pool[EngagementCalendar.positiveModulo(offset * step + pass * 11, count)]
    }

    /// Strides that visit every pool position exactly once per pass (coprime with the pool size).
    private static let strides: [Int] = {
        let count = DailyMissions.pool.count
        let coprime = (1..<max(count, 2)).filter { DailyMissions.greatestCommonDivisor($0, count) == 1 }
        return coprime.isEmpty ? [1] : coprime
    }()

    private static func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        var x = abs(a)
        var y = abs(b)
        while y != 0 {
            (x, y) = (y, x % y)
        }
        return x
    }

    private static func mission(_ id: String, _ title: String.LocalizationValue, _ detail: String.LocalizationValue, _ symbol: String) -> Mission {
        Mission(id: id, title: String(localized: title), detail: String(localized: detail), systemImage: symbol, kind: .selfReported)
    }
}
