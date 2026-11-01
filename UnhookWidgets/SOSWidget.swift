import SwiftUI
import WidgetKit

/// One-tap craving help from the Home Screen or Lock Screen.
struct SOSWidget: Widget {
    let kind = "UnhookSOSWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SOSProvider()) { _ in
            SOSWidgetView()
                .widgetURL(URL(string: "unhook://sos"))
        }
        .configurationDisplayName("Craving SOS")
        .description("Open guided breathing the moment a craving hits.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct SOSEntry: TimelineEntry {
    let date: Date
}

struct SOSProvider: TimelineProvider {
    func placeholder(in context: Context) -> SOSEntry { SOSEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (SOSEntry) -> Void) {
        completion(SOSEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SOSEntry>) -> Void) {
        completion(Timeline(entries: [SOSEntry(date: .now)], policy: .never))
    }
}

struct SOSWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "wind")
                        .font(.title3.weight(.semibold))
                    Text("SOS")
                        .font(.caption2.weight(.heavy))
                }
            }
            .containerBackground(for: .widget) { Color.clear }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "wind")
                    .font(.title.weight(.semibold))
                Spacer(minLength: 0)
                Text("Craving?")
                    .font(.headline)
                Text("Tap to breathe through it")
                    .font(.caption.weight(.semibold))
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { HabitTheme.fire.gradient }
        }
    }
}
