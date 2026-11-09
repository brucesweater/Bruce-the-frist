import Foundation

/// A short, practical tip. One a day.
struct DailyTip: Equatable {
    let title: String
    let body: String
    let systemImage: String
}

enum DailyTips {
    static let all: [DailyTip] = [
        tip("Cravings are waves", "Most urges peak and fade within minutes. Breathe and let this one pass.", "water.waves"),
        tip("Delay, don't decide", "Tell yourself \"not now, maybe in 10 minutes.\" Often the urge is gone by then.", "timer"),
        tip("Check the basics", "Hungry, angry, lonely or tired? Take care of that first. Cravings often follow those feelings.", "checklist"),
        tip("Change your scene", "Move to another room or step outside. A new place breaks the loop.", "door.left.hand.open"),
        tip("Name it to tame it", "Saying \"this is a craving\" puts a little space between you and the urge.", "text.bubble.fill"),
        tip("Water first", "A glass of water gives your hands and mouth something to do while the urge passes.", "drop.fill"),
        tip("Slips aren't the end", "One slip doesn't erase your progress. Learn what happened and keep going.", "heart.fill"),
        tip("Make it harder", "Add friction: delete the app, toss the stash, take the long way home.", "lock.fill"),
        tip("Make the good stuff easy", "Keep your swap within reach: gum in your pocket, shoes by the door.", "hand.thumbsup.fill"),
        tip("If-then plans work", "Decide ahead: \"If I feel stressed after school or work, then I'll go for a walk.\"", "arrow.branch"),
        tip("Sleep is a superpower", "Tired brains crave more. An earlier night makes tomorrow easier.", "bed.double.fill"),
        tip("Breathe out longer", "Make each breath out longer than the breath in. It helps your body settle.", "wind"),
        tip("Every win counts", "Each craving you ride out is proof you can do it again.", "trophy.fill"),
        tip("Move for two minutes", "A short burst of movement can take the edge off restlessness.", "figure.walk"),
        tip("Text a friend", "You don't have to explain. \"Hey, thinking of you\" is enough.", "message.fill"),
        tip("Know your hours", "Most people have a time of day when cravings peak. Plan something for yours.", "clock.fill"),
        tip("Be your own friend", "Talk to yourself the way you'd talk to a friend who's trying hard.", "face.smiling"),
        tip("Keep your why close", "Reread your reasons when it gets hard. They're why you started.", "note.text"),
        tip("Don't skip meals", "Being really hungry can feel a lot like a craving. Regular meals help.", "fork.knife"),
        tip("Swap the ritual", "Keep the moment, change the habit: same break, new drink; same couch, new hobby.", "arrow.triangle.2.circlepath"),
        tip("Get some daylight", "Morning light helps your mood and your sleep. Even a few minutes counts.", "sun.max.fill"),
        tip("Busy hands help", "Doodle, knit, squeeze a stress ball. Give your hands a job.", "hand.raised.fill"),
        tip("\"Just one\" is the habit talking", "You can hear that thought without doing what it says.", "quote.bubble.fill"),
        tip("Plan for big events", "Before a party or a trip, decide what you'll say and do, and how you'll leave if you need to.", "calendar"),
        tip("Look back", "Things that felt impossible on day one get easier. Look back to see how far you've come.", "chart.line.uptrend.xyaxis"),
        tip("Boredom is a trigger", "Keep a short list of things to do when you're bored. Pick one and start small.", "list.bullet"),
        tip("Give stress somewhere to go", "Music, a run, a hot shower, writing it out. Find a release that works for you.", "music.note"),
        tip("Reward yourself", "Put the money you're saving toward something you really want.", "gift.fill"),
        tip("Tidy space, calmer mind", "Clearing one small space can make you feel more in control.", "wand.and.stars"),
        tip("An urge isn't an order", "You can feel a craving and still choose not to act on it.", "brain.head.profile"),
        tip("Laugh it off", "A funny video or a goofy friend can break a craving's spell.", "theatermasks.fill"),
        tip("Cold water reset", "Splashing cold water on your face can calm a racing moment.", "snowflake"),
        tip("One day at a time", "You don't have to quit forever today. Just today.", "sunrise.fill"),
        tip("Ask for help", "Reaching out is a strength. A friend, a group or a professional can help.", "person.2.fill"),
        tip("Phone-free zones", "Keep your phone out of the bedroom and off the dinner table.", "iphone.slash"),
        tip("Learn from slips", "After a slip, ask what happened just before. That's your next plan.", "magnifyingglass"),
        tip("Fresh air helps", "A walk outside can lift your mood and reset your focus.", "leaf.fill"),
        tip("Notice the good", "Writing down one good thing a day helps you see your progress.", "heart.text.square.fill"),
        tip("Your clean time is yours", "Time you've stayed free never disappears. Every day still counts.", "star.fill"),
        tip("Celebrate small", "Mark the little milestones. Progress you notice is progress you keep.", "party.popper.fill"),
    ]

    static func tip(for day: Date, calendar: Calendar = .current) -> DailyTip {
        tip(forDayIndex: EngagementCalendar.dayIndex(for: day, calendar: calendar))
    }

    static func tip(forDayIndex day: Int) -> DailyTip {
        all[EngagementCalendar.positiveModulo(day, all.count)]
    }

    private static func tip(_ title: String.LocalizationValue, _ body: String.LocalizationValue, _ symbol: String) -> DailyTip {
        DailyTip(title: String(localized: title), body: String(localized: body), systemImage: symbol)
    }
}
