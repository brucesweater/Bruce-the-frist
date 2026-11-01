import Foundation

/// One-tap starting points so a new user is tracking within seconds.
struct HabitPreset: Identifiable, Hashable {
    let id: String
    let title: String
    let emoji: String
    let theme: HabitTheme
    var dailyCost: Double = 0
    var dailyMinutes: Double = 0
    var unitsPerDay: Double = 0
    var unitName: String = ""
    var suggestedReasons: [String] = []

    static let customID = "custom"

    var defaultName: String { id == Self.customID ? "" : title }

    static func preset(id: String) -> HabitPreset? {
        all.first { $0.id == id }
    }

    static let all: [HabitPreset] = [
        HabitPreset(
            id: "smoking", title: String(localized: "Smoking"), emoji: "🚬", theme: .fire,
            dailyCost: 10, dailyMinutes: 60, unitsPerDay: 12, unitName: String(localized: "cigarettes"),
            suggestedReasons: [String(localized: "Breathe easier and taste food again"), String(localized: "Be around longer for the people I love"), String(localized: "Stop burning money")]
        ),
        HabitPreset(
            id: "vaping", title: String(localized: "Vaping"), emoji: "💨", theme: .grape,
            dailyCost: 4, dailyMinutes: 45, unitsPerDay: 150, unitName: String(localized: "puffs"),
            suggestedReasons: [String(localized: "Break the nicotine loop"), String(localized: "Stop feeling anxious without it"), String(localized: "Clear lungs, clear head")]
        ),
        HabitPreset(
            id: "alcohol", title: String(localized: "Alcohol"), emoji: "🍺", theme: .sunset,
            dailyCost: 12, dailyMinutes: 120, unitsPerDay: 3, unitName: String(localized: "drinks"),
            suggestedReasons: [String(localized: "Wake up clear-headed"), String(localized: "Sleep better"), String(localized: "Be fully present")]
        ),
        HabitPreset(
            id: "social", title: String(localized: "Social Media"), emoji: "📱", theme: .ocean,
            dailyMinutes: 150,
            suggestedReasons: [String(localized: "Be present with the people around me"), String(localized: "Stop comparing myself to others"), String(localized: "Get my focus back")]
        ),
        HabitPreset(
            id: "porn", title: String(localized: "Porn"), emoji: "🔞", theme: .midnight,
            dailyMinutes: 30,
            suggestedReasons: [String(localized: "Build real connection"), String(localized: "Get my energy and focus back"), String(localized: "Feel in control again")]
        ),
        HabitPreset(
            id: "sugar", title: String(localized: "Sugar"), emoji: "🍭", theme: .candy,
            dailyCost: 3, dailyMinutes: 10, unitsPerDay: 3, unitName: String(localized: "sweets"),
            suggestedReasons: [String(localized: "Steady energy all day"), String(localized: "Feel better in my body"), String(localized: "Stop the crash")]
        ),
        HabitPreset(
            id: "junkfood", title: String(localized: "Junk Food"), emoji: "🍔", theme: .gold,
            dailyCost: 9, dailyMinutes: 20, unitsPerDay: 1, unitName: String(localized: "meals"),
            suggestedReasons: [String(localized: "Feel lighter and stronger"), String(localized: "Save money for things I love"), String(localized: "Take care of my health")]
        ),
        HabitPreset(
            id: "caffeine", title: String(localized: "Caffeine"), emoji: "☕️", theme: .sunset,
            dailyCost: 5, dailyMinutes: 15, unitsPerDay: 3, unitName: String(localized: "cups"),
            suggestedReasons: [String(localized: "Sleep deeply again"), String(localized: "Calmer mornings"), String(localized: "Energy that doesn't crash")]
        ),
        HabitPreset(
            id: "cannabis", title: String(localized: "Cannabis"), emoji: "🌿", theme: .forest,
            dailyCost: 10, dailyMinutes: 60, unitsPerDay: 2, unitName: String(localized: "sessions"),
            suggestedReasons: [String(localized: "Sharper memory and motivation"), String(localized: "Remember my dreams"), String(localized: "Feel like myself")]
        ),
        HabitPreset(
            id: "gambling", title: String(localized: "Gambling"), emoji: "🎰", theme: .gold,
            dailyCost: 25, dailyMinutes: 60,
            suggestedReasons: [String(localized: "Protect my savings"), String(localized: "Rebuild trust"), String(localized: "Stop chasing losses")]
        ),
        HabitPreset(
            id: "gaming", title: String(localized: "Gaming"), emoji: "🎮", theme: .candy,
            dailyMinutes: 180,
            suggestedReasons: [String(localized: "Spend time on real goals"), String(localized: "Sleep on time"), String(localized: "See friends in person")]
        ),
        HabitPreset(
            id: "shopping", title: String(localized: "Impulse Buys"), emoji: "🛍️", theme: .candy,
            dailyCost: 15, dailyMinutes: 20,
            suggestedReasons: [String(localized: "Build my savings"), String(localized: "Want less, live more"), String(localized: "Get out of debt")]
        ),
        HabitPreset(
            id: "nailbiting", title: String(localized: "Nail Biting"), emoji: "💅", theme: .mint,
            suggestedReasons: [String(localized: "Healthy, good-looking nails"), String(localized: "Less anxiety on autopilot"), String(localized: "Feel confident with my hands")]
        ),
        HabitPreset(id: customID, title: String(localized: "Something else"), emoji: "✨", theme: .grape),
    ]
}
