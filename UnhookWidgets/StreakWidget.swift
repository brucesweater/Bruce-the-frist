import SwiftUI
import WidgetKit

struct StreakEntry: TimelineEntry {
    let date: Date
    let habit: HabitSnapshot?
    let currencyCode: String
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, habit: .sample, currencyCode: "USD")
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(StreakEntry(date: .now, habit: WidgetDataLoader.primaryHabit(), currencyCode: WidgetDataLoader.currencyCode))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let now = Date.now
        let habit = WidgetDataLoader.primaryHabit()
        let currencyCode = WidgetDataLoader.currencyCode
        let entries = Self.entryDates(from: now, streakStart: habit?.streakStart).map { date in
            StreakEntry(date: date, habit: habit, currencyCode: currencyCode)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// When the widget redraws: now, then just after each of the streak's next 24 whole hours. Lining the entries up
    /// with the streak (rather than with "now") makes the day count, the first day's hour count and the milestone bar
    /// change the moment they should, instead of up to an hour after the live timer text (which ticks on its own).
    /// The extra second keeps floating-point rounding from landing an entry a hair before a boundary.
    static func entryDates(from now: Date, streakStart: Date?, hours: Int = 24) -> [Date] {
        let hour: TimeInterval = 3_600
        let count = max(hours, 1)
        guard let streakStart else {
            return (0..<count).map { now.addingTimeInterval(Double($0) * hour) }
        }
        let wholeHours = (now.timeIntervalSince(streakStart) / hour).rounded(.down)
        let boundaries = (1...count).map { offset in
            streakStart.addingTimeInterval((wholeHours + Double(offset)) * hour + 1)
        }
        return [now] + boundaries
    }
}

struct StreakWidget: Widget {
    let kind = "UnhookStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
                .widgetURL(URL(string: "unhook://today"))
        }
        .configurationDisplayName("Streak")
        .description("See how long you've been free and what you've saved.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct StreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakEntry

    var body: some View {
        if let habit = entry.habit {
            content(for: habit)
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private func content(for habit: HabitSnapshot) -> some View {
        let stats = habit.stats(at: entry.date)
        let count = StreakCount(elapsed: stats.currentStreak)
        // Progress toward the next milestone: fills the Lock Screen ring and raises the dawn glow behind the numbers.
        let progress = Milestone.progress(toward: stats.currentStreak)
        switch family {
        case .accessoryCircular:
            CircularStreakView(habit: habit, count: count, progress: progress)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            RectangularStreakView(habit: habit, stats: stats, currencyCode: entry.currencyCode)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            count.inlineText(emoji: habit.emoji)
                .widgetAccentable()
                .containerBackground(for: .widget) { Color.clear }
        case .systemMedium:
            MediumStreakView(habit: habit, stats: stats, count: count, currencyCode: entry.currencyCode)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .containerBackground(for: .widget) { WidgetNightSky(glow: progress) }
        default:
            SmallStreakView(habit: habit, stats: stats, count: count, currencyCode: entry.currencyCode)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .containerBackground(for: .widget) { WidgetNightSky(glow: progress) }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "sunrise.fill")
                    .font(.title2.weight(.semibold))
                    .widgetAccentable()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Open Unhook"))
            .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text(verbatim: "Unhook")
                } icon: {
                    Image(systemName: "sunrise.fill")
                }
                .font(.system(.headline, design: .rounded))
                .widgetAccentable()
                Text("Start your first streak in Unhook")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            Text("Open Unhook")
                .containerBackground(for: .widget) { Color.clear }
        default:
            EmptyStreakView()
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .containerBackground(for: .widget) { WidgetNightSky(glow: 0.35) }
        }
    }
}

// MARK: - Counting

/// The number the streak widgets lead with: whole days, or whole hours during the first day (so a brand-new streak
/// reads "5 hours free" rather than "0 days").
private struct StreakCount {
    let value: Int
    let isHours: Bool

    init(elapsed: TimeInterval) {
        let parts = DurationFormatter.parts(elapsed)
        let firstDay = parts.days == 0
        isHours = firstDay
        value = firstDay ? parts.hours : parts.days
    }

    /// The label under the big numeral, shown uppercased ("DAYS FREE").
    var unitText: Text {
        switch (isHours, value == 1) {
        case (false, true): Text("day free")
        case (false, false): Text("days free")
        case (true, true): Text("hour free")
        case (true, false): Text("hours free")
        }
    }

    /// "47 days free", read by VoiceOver.
    var fullText: Text {
        switch (isHours, value == 1) {
        case (false, true): Text("\(value) day free")
        case (false, false): Text("\(value) days free")
        case (true, true): Text("\(value) hour free")
        case (true, false): Text("\(value) hours free")
        }
    }

    /// "47d" or "5h", in the round Lock Screen widget.
    var shortText: Text {
        isHours
            ? Text("\(value)h", comment: "Duration: hours, abbreviated")
            : Text("\(value)d", comment: "Duration: days, abbreviated")
    }

    /// "🚬 47 days free", in the inline Lock Screen widget.
    func inlineText(emoji: String) -> Text {
        switch (isHours, value == 1) {
        case (false, true): Text("\(emoji) \(value) day free")
        case (false, false): Text("\(emoji) \(value) days free")
        case (true, true): Text("\(emoji) \(value) hour free")
        case (true, false): Text("\(emoji) \(value) hours free")
        }
    }
}

private enum StreakFormat {
    /// Time left until a milestone, rounded up to the hour: "12d 19h", "5h". Entries land on the streak's whole
    /// hours, so a whole-hour figure is never stale.
    static func timeLeft(_ seconds: TimeInterval) -> String {
        // One second of slack: entries land a second after the hour, and that shouldn't round up a whole extra hour.
        let hours = max(1, ((seconds - 1) / 3_600).rounded(.up).clampedWholeNumber)
        let days = hours / 24
        let rest = hours % 24
        if days > 0 {
            return String(localized: "\(days)d \(rest)h", comment: "Duration: days and hours, abbreviated")
        }
        return String(localized: "\(rest)h", comment: "Duration: hours, abbreviated")
    }
}

// MARK: - Home Screen

private struct SmallStreakView: View {
    let habit: HabitSnapshot
    let stats: HabitStats
    let count: StreakCount
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HabitTag(habit: habit)
            Spacer(minLength: 2)
            StreakHero(count: count, numeralSize: 54)
            bottomLine
                .font(.system(.caption, design: .rounded).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// Money saved if the habit cost money, else time reclaimed, else the next milestone.
    @ViewBuilder
    private var bottomLine: some View {
        if stats.moneySaved >= 1 {
            Text("\(MoneyFormatter.rounded(stats.moneySaved, code: currencyCode)) saved")
                .foregroundStyle(Palette.money)
        } else if stats.minutesReclaimed >= 1 {
            Text("\(DurationFormatter.minutes(stats.minutesReclaimed)) reclaimed")
                .foregroundStyle(Palette.time)
        } else if let next = Milestone.next(after: stats.currentStreak) {
            Text("Next: \(next.title)")
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

private struct MediumStreakView: View {
    let habit: HabitSnapshot
    let stats: HabitStats
    let count: StreakCount
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                HabitTag(habit: habit)
                Spacer(minLength: 4)
                // The live timer: WidgetKit keeps this text ticking between timeline entries.
                Text(habit.streakStart, style: .relative)
                    .font(.system(.caption2, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            HStack(alignment: .bottom, spacing: 12) {
                StreakHero(count: count, numeralSize: 48)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                savings
            }
            Spacer(minLength: 4)
            MilestoneProgressView(elapsed: stats.currentStreak)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var savings: some View {
        HStack(alignment: .bottom, spacing: 14) {
            if stats.moneySaved >= 1 {
                StatBlock(value: MoneyFormatter.rounded(stats.moneySaved, code: currencyCode), label: "saved", tint: Palette.money)
            }
            if stats.minutesReclaimed >= 1 {
                StatBlock(value: DurationFormatter.minutes(stats.minutesReclaimed), label: "reclaimed", tint: Palette.time)
            }
            if stats.moneySaved < 1 && stats.minutesReclaimed < 1 {
                StatBlock(
                    value: Milestone.latest(reachedBy: stats.currentStreak)?.title ?? String(localized: "Day one"),
                    label: "milestone",
                    tint: Palette.celebrate
                )
            }
        }
    }
}

/// The habit's emoji in a softly tinted circle, then its name. With the app lock on, the snapshot already holds a
/// neutral emoji, name and theme instead of what the user is quitting.
private struct HabitTag: View {
    let habit: HabitSnapshot

    var body: some View {
        HStack(spacing: 6) {
            Text(habit.emoji)
                .font(.system(size: 12))
                .frame(width: 20, height: 20)
                .background(habit.theme.accent.opacity(0.22), in: Circle())
                .overlay {
                    Circle().strokeBorder(habit.theme.accent.opacity(0.4), lineWidth: 1)
                }
                .accessibilityHidden(true)
            Text(habit.name)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
        }
    }
}

/// The big rounded count with its amber label tucked underneath.
private struct StreakHero: View {
    let count: StreakCount
    let numeralSize: CGFloat

    var body: some View {
        // Negative spacing tucks the label into the empty space below the digits.
        VStack(alignment: .leading, spacing: -4) {
            Text("\(count.value)")
                .font(.widgetNumeral(numeralSize))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .shadow(color: Palette.amber.opacity(0.35), radius: 12)
                .widgetAccentable()
            count.unitText
                .widgetMicroLabel(Palette.amber)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count.fullText)
    }
}

/// A value in its role color over a micro label ("$470 / SAVED").
private struct StatBlock: View {
    let value: String
    let label: LocalizedStringKey
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .widgetMicroLabel()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The next milestone, the time left to it and a slim dawn bar.
private struct MilestoneProgressView: View {
    let elapsed: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            caption
            WidgetDawnBar(progress: Milestone.progress(toward: elapsed))
        }
    }

    @ViewBuilder
    private var caption: some View {
        if let next = Milestone.next(after: elapsed) {
            HStack(spacing: 4) {
                Image(systemName: next.symbol)
                    .foregroundStyle(Palette.amber)
                    .accessibilityHidden(true)
                Text("Next: \(next.title)")
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 6)
                Text("\(StreakFormat.timeLeft(next.seconds - elapsed)) to go")
                    .foregroundStyle(Palette.textSecondary)
            }
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .lineLimit(1)
            .accessibilityElement(children: .combine)
        } else {
            Label("Every milestone unlocked", systemImage: "crown.fill")
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.sun)
                .lineLimit(1)
        }
    }
}

/// No habit yet (or no App Group on this build): an invitation on the night sky.
private struct EmptyStreakView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sunrise.fill")
                .font(.title.weight(.semibold))
                .foregroundStyle(Brand.dawn)
                .shadow(color: Palette.amber.opacity(0.55), radius: 10)
                .accessibilityHidden(true)
            Text("Start your first streak in Unhook")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Lock Screen (tinted by iOS, so system styles only)

private struct CircularStreakView: View {
    let habit: HabitSnapshot
    let count: StreakCount
    let progress: Double

    var body: some View {
        Gauge(value: progress) {
            Text(habit.emoji)
        } currentValueLabel: {
            count.shortText
        }
        .gaugeStyle(.accessoryCircular)
        .fontDesign(.rounded)
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count.fullText)
    }
}

private struct RectangularStreakView: View {
    let habit: HabitSnapshot
    let stats: HabitStats
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "\(habit.emoji) \(habit.name)")
                .font(.system(.headline, design: .rounded))
                .widgetAccentable()
                .lineLimit(1)
            Text(habit.streakStart, style: .relative)
                .font(.system(.body, design: .rounded).weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            detail
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var detail: some View {
        if stats.moneySaved >= 1 {
            Text("\(MoneyFormatter.rounded(stats.moneySaved, code: currencyCode)) saved")
        } else if let next = Milestone.next(after: stats.currentStreak) {
            Text("Next: \(next.title)")
        }
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    StreakWidget()
} timeline: {
    StreakEntry(date: .now, habit: .sample, currencyCode: "USD")
    StreakEntry(date: .now, habit: nil, currencyCode: "USD")
}

#Preview(as: .systemMedium) {
    StreakWidget()
} timeline: {
    StreakEntry(date: .now, habit: .sample, currencyCode: "USD")
}

#Preview(as: .accessoryRectangular) {
    StreakWidget()
} timeline: {
    StreakEntry(date: .now, habit: .sample, currencyCode: "USD")
}
