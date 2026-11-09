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
            SOSCircularView()
                .containerBackground(for: .widget) { Color.clear }
        } else {
            SOSSmallView()
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .containerBackground(for: .widget) {
                    WidgetNightSky(glow: 0.45, glowColors: [Palette.rose, Palette.ember], starSeed: 0x5050)
                }
        }
    }
}

/// Lock Screen: the breathing symbol over "SOS", tinted by iOS.
private struct SOSCircularView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "wind")
                    .font(.title3.weight(.semibold))
                    .widgetAccentable()
                Text("SOS")
                    .font(.system(.caption2, design: .rounded).weight(.heavy))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Craving SOS"))
    }
}

/// Home Screen: a glowing orb, "Craving?" and a warm "Breathe" call to action on the night sky.
private struct SOSSmallView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                SOSOrb(size: 42)
                Spacer(minLength: 4)
                Text("SOS")
                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(Palette.rose)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Palette.rose.opacity(0.16), in: Capsule())
            }
            Spacer(minLength: 4)
            Text("Craving?")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            breatheButton
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Craving SOS"))
        .accessibilityHint(Text("Tap to breathe through it"))
    }

    /// Looks like the app's SOS button; the whole widget is the tap target.
    private var breatheButton: some View {
        HStack(spacing: 5) {
            Text("Breathe")
            Image(systemName: "arrow.forward")
                .font(.caption.weight(.heavy))
        }
        .font(.system(.subheadline, design: .rounded).weight(.bold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Brand.sos, in: Capsule())
        .shadow(color: Palette.rose.opacity(0.45), radius: 8, y: 3)
    }
}

/// A glowing rose-to-ember sphere with the breathing symbol, echoing the orb on the SOS screen. The halo spills past
/// the orb's frame, so it lays out at `size` while glowing wider.
private struct SOSOrb: View {
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Palette.rose.opacity(0.5), Palette.ember.opacity(0.16), Palette.ember.opacity(0)],
                    center: .center,
                    startRadius: size * 0.3,
                    endRadius: size
                ))
                .frame(width: size * 2, height: size * 2)
            sphere
            Image(systemName: "wind")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .widgetAccentable()
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var sphere: some View {
        Circle()
            .fill(LinearGradient(colors: [Palette.rose, Palette.ember], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                // Soft highlight on the upper left, so it reads as a sphere.
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.4), Color.white.opacity(0)],
                        center: UnitPoint(x: 0.3, y: 0.25),
                        startRadius: 0,
                        endRadius: size * 0.6
                    ))
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.5), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
            }
            .frame(width: size, height: size)
            .shadow(color: Palette.rose.opacity(0.6), radius: 10)
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    SOSWidget()
} timeline: {
    SOSEntry(date: .now)
}

#Preview(as: .accessoryCircular) {
    SOSWidget()
} timeline: {
    SOSEntry(date: .now)
}
