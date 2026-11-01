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
        // Hourly entries keep the day count and savings fresh; the relative timer text ticks on its own.
        let entries = (0..<24).map { hour in
            StreakEntry(date: now.addingTimeInterval(Double(hour) * 3_600), habit: habit, currencyCode: currencyCode)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
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
        let days = DurationFormatter.parts(stats.currentStreak).days
        switch family {
        case .accessoryCircular:
            Gauge(value: Milestone.progress(toward: stats.currentStreak)) {
                Text(habit.emoji)
            } currentValueLabel: {
                Text("\(days)d")
            }
            .gaugeStyle(.accessoryCircular)
            .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("\(habit.emoji) \(habit.name)")
                    .font(.headline)
                    .lineLimit(1)
                Text(habit.streakStart, style: .relative)
                    .font(.body.monospacedDigit())
                    .lineLimit(1)
                if stats.moneySaved >= 1 {
                    Text("\(MoneyFormatter.rounded(stats.moneySaved, code: entry.currencyCode)) saved")
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            .containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            Text("\(habit.emoji) \(days) days free")
                .containerBackground(for: .widget) { Color.clear }
        case .systemMedium:
            MediumStreakView(habit: habit, stats: stats, days: days, currencyCode: entry.currencyCode)
                .containerBackground(for: .widget) { habit.theme.gradient }
        default:
            SmallStreakView(habit: habit, stats: stats, days: days, currencyCode: entry.currencyCode)
                .containerBackground(for: .widget) { habit.theme.gradient }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            Text("Open Unhook")
                .containerBackground(for: .widget) { Color.clear }
        default:
            VStack(spacing: 6) {
                Image(systemName: "link.badge.plus")
                    .font(.title2)
                Text("Start your first streak in Unhook")
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .containerBackground(for: .widget) { Brand.gradient }
        }
    }
}

private struct SmallStreakView: View {
    let habit: HabitSnapshot
    let stats: HabitStats
    let days: Int
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(habit.emoji)
                    .font(.title3)
                Spacer()
                Text(habit.name)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .opacity(0.85)
            }
            Spacer(minLength: 0)
            Text("\(days)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(days == 1 ? "day free" : "days free")
                .font(.caption.weight(.bold))
                .opacity(0.9)
            if stats.moneySaved >= 1 {
                Text("\(MoneyFormatter.rounded(stats.moneySaved, code: currencyCode)) saved")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
    }
}

private struct MediumStreakView: View {
    let habit: HabitSnapshot
    let stats: HabitStats
    let days: Int
    let currencyCode: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                ProgressRingShape(progress: Milestone.progress(toward: stats.currentStreak))
                Text(habit.emoji)
                    .font(.title)
            }
            .frame(width: 82, height: 82)

            VStack(alignment: .leading, spacing: 4) {
                Text("FREE FROM \(habit.name.uppercased())")
                    .font(.caption2.weight(.heavy))
                    .lineLimit(1)
                    .opacity(0.85)
                Text(habit.streakStart, style: .relative)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 12) {
                    if stats.moneySaved >= 1 {
                        Label(MoneyFormatter.rounded(stats.moneySaved, code: currencyCode), systemImage: "banknote.fill")
                    }
                    if stats.minutesReclaimed >= 1 {
                        Label(DurationFormatter.minutes(stats.minutesReclaimed), systemImage: "clock.fill")
                    }
                }
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                if let next = Milestone.next(after: stats.currentStreak) {
                    Text("Next: \(next.title)")
                        .font(.caption2)
                        .opacity(0.85)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
    }
}

/// A white ring for use on the colored widget background.
private struct ProgressRingShape: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 7)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0.001), 1)))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(4)
    }
}
