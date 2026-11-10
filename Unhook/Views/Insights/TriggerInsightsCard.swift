import SwiftUI
import SwiftData
import Charts

/// Progress-tab section that shows when and why cravings hit: the #1 trigger, the toughest time and day, the top
/// triggers and a 24-hour chart.
struct TriggerInsightsCard: View {
    @Query private var urges: [Urge]
    @Query private var relapses: [Relapse]

    /// With fewer events than this the patterns would be noise, so the card explains how to fill it in instead.
    static let minimumEvents = 3

    private var events: [CravingEvent] {
        urges.map(CravingEvent.init(urge:)) + relapses.map(CravingEvent.init(relapse:))
    }

    var body: some View {
        let insights = TriggerInsights(events: events)
        InsightsSection(title: "Craving patterns", systemImage: "waveform.path.ecg", tint: Palette.rose) {
            if insights.totalCount < Self.minimumEvents {
                emptyState
            } else {
                TopTriggerSummary(insights: insights)
                TriggerInsightsDetails(insights: insights)
            }
        }
    }

    private var emptyState: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemImage: "tag.fill", tint: Palette.rose, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text("Learn what sets off your cravings")
                    .font(.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                Text("After you beat a craving in SOS, tap what set it off. Log a few and your top triggers and toughest times show up here.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - #1 trigger

/// "#1 trigger: 😤 Stress", with the share of tagged cravings and slips it was behind.
private struct TopTriggerSummary: View {
    let insights: TriggerInsights

    @ScaledMetric(relativeTo: .largeTitle) private var badgeSize: CGFloat = 60

    var body: some View {
        if let top = insights.topTrigger {
            HStack(spacing: 14) {
                Text(top.trigger.emoji)
                    .font(.largeTitle)
                    .frame(width: badgeSize, height: badgeSize)
                    .background {
                        Circle().fill(RadialGradient(
                            colors: [Palette.amber.opacity(0.38), Palette.ember.opacity(0.06)],
                            center: .center,
                            startRadius: 0,
                            endRadius: badgeSize * 0.6
                        ))
                    }
                    .overlay(Circle().strokeBorder(Palette.amber.opacity(0.4), lineWidth: 1))
                    .shadow(color: Palette.amber.opacity(0.3), radius: 10)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("#1 trigger")
                        .microLabel(Palette.amber)
                    Text(top.trigger.title)
                        .font(.display(28))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("Behind \(percent(insights.share(of: top))) of the cravings and slips you tagged.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else {
            Text("Tap what set off a craving after you beat it in SOS to find your #1 trigger.")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}

// MARK: - Details

private struct TriggerInsightsDetails: View {
    let insights: TriggerInsights

    /// A peak needs at least this many events in one bucket before it's worth pointing out.
    private static let minimumPeakCount = 2
    /// Every hour of the day, so hours without cravings keep their place on the chart.
    private static let hourDomain: [String] = (0..<TriggerInsights.hoursPerDay).map { String($0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            timingInsights
            topTriggerBars
            hourChart
        }
    }

    // MARK: Timing

    private var timingInsights: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let hour = insights.peakHour, insights.peakHourCount >= Self.minimumPeakCount {
                InsightLine(systemImage: "clock.fill", tint: Palette.time) {
                    Text("Cravings peak around \(TriggerInsights.hourLabel(hour)) — plan something for then.")
                }
            } else {
                InsightLine(systemImage: "clock", tint: Palette.time) {
                    Text("No clear peak time yet. Keep logging and it will show up.")
                }
            }
            if let weekday = insights.peakWeekday,
               insights.peakWeekdayCount >= Self.minimumPeakCount,
               let name = TriggerInsights.weekdayName(weekday) {
                InsightLine(systemImage: "calendar", tint: Palette.violet) {
                    Text("Toughest day: \(name). A little extra support then goes a long way.")
                }
            }
        }
    }

    // MARK: Top triggers

    /// Hidden until something is tagged; the summary above already explains how to tag.
    @ViewBuilder
    private var topTriggerBars: some View {
        if let top = insights.topTrigger {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top triggers")
                    .microLabel()
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(insights.topTriggers.prefix(3))) { item in
                    TriggerBarRow(
                        item: item,
                        rank: insights.topTriggers.firstIndex(of: item) ?? 0,
                        share: insights.share(of: item),
                        fraction: top.count > 0 ? Double(item.count) / Double(top.count) : 0
                    )
                }
            }
        }
    }

    // MARK: Time of day

    /// Bars only for the hours that had cravings, on a full 24-hour axis.
    private var hourChart: some View {
        let bars = insights.hourlyCounts.filter { $0.count > 0 }
        let top = max(insights.peakHourCount, 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Cravings by time of day")
                .microLabel()
                .accessibilityAddTraits(.isHeader)
            Chart(bars) { item in
                BarMark(
                    x: .value("Hour", String(item.hour)),
                    y: .value("Cravings", item.count)
                )
                .foregroundStyle(barStyle(for: item.hour))
                .cornerRadius(4, style: .continuous)
                .accessibilityLabel(Text(TriggerInsights.hourLabel(item.hour)))
                .accessibilityValue(Text("Cravings: \(item.count)"))
            }
            .chartXScale(domain: Self.hourDomain)
            .chartYScale(domain: 0...top)
            .chartYAxis {
                AxisMarks(position: .trailing, values: InsightsChartStyle.ticks(upTo: top)) { _ in
                    AxisGridLine(stroke: InsightsChartStyle.gridStroke)
                        .foregroundStyle(Palette.hairline)
                    AxisValueLabel()
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .chartXAxis {
                AxisMarks(values: ["0", "6", "12", "18"]) { value in
                    AxisValueLabel {
                        if let raw = value.as(String.self), let hour = Int(raw) {
                            Text(TriggerInsights.hourLabel(hour))
                                .foregroundStyle(Palette.textTertiary)
                        }
                    }
                }
            }
            .frame(height: 150)
        }
    }

    /// Only highlights the peak bar when the text above calls out a peak, so the chart never contradicts it.
    private func barStyle(for hour: Int) -> AnyShapeStyle {
        if hour == insights.peakHour, insights.peakHourCount >= Self.minimumPeakCount {
            return AnyShapeStyle(InsightsChartStyle.dawnBar)
        }
        return AnyShapeStyle(InsightsChartStyle.violetBar)
    }
}

/// A tinted icon plus one sentence of insight.
private struct InsightLine<Content: View>: View {
    let systemImage: String
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            IconBadge(systemImage: systemImage, tint: tint, size: 30)
            content
                .font(.subheadline)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One of the top triggers: its share of tagged cravings, as a bar in the palette (warmest for the #1).
private struct TriggerBarRow: View {
    let item: TriggerCount
    /// 0 for the #1 trigger.
    let rank: Int
    /// Share of all tagged events, for the label.
    let share: Double
    /// Length relative to the top trigger, for the bar.
    let fraction: Double

    private var percent: String {
        share.formatted(.percent.precision(.fractionLength(0)))
    }

    private var barColors: [Color] {
        switch rank {
        case 0: [Palette.amber, Palette.ember]
        case 1: [Palette.rose, Palette.violet]
        default: [Palette.violet, Palette.sky]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("\(item.trigger.emoji) \(item.trigger.title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: 8)
                Text(percent)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textSecondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: barColors, startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, proxy.size.width * CGFloat(min(max(fraction, 0), 1))))
                        .shadow(color: rank == 0 ? Palette.amber.opacity(0.45) : .clear, radius: 6)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.trigger.title))
        .accessibilityValue(Text("\(percent) of tagged cravings, \(item.count) in total"))
    }
}

// MARK: - Trigger picker (shared by the SOS screen and the slip sheet)

/// A wrapping set of trigger chips. Single choice and optional: tapping the selected chip clears it.
/// Glass chips on the night background; the selected one fills with `tint`.
struct CravingTriggerPicker: View {
    @Binding var selection: CravingTrigger?
    var tint: LinearGradient = Brand.gradient

    var body: some View {
        TriggerChipFlowLayout(spacing: 8) {
            ForEach(CravingTrigger.allCases) { trigger in
                chip(for: trigger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selection)
    }

    private func chip(for trigger: CravingTrigger) -> some View {
        let isSelected = selection == trigger
        return Button {
            selection = isSelected ? nil : trigger
            Haptics.selection()
        } label: {
            HStack(spacing: 6) {
                Text(trigger.emoji)
                Text(trigger.title)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(Palette.textPrimary)
            .shadow(color: .black.opacity(isSelected ? 0.25 : 0), radius: 1, y: 1)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(Color.white.opacity(0.08)),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(isSelected ? 0.3 : 0.12), lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        // Plain style keeps each chip its own tap target inside a Form row.
        .buttonStyle(.plain)
        .accessibilityLabel(trigger.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Lays chips out left to right and wraps them onto new rows, like words in a paragraph.
private struct TriggerChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(of: subviews, maxWidth: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrangement(of: subviews, maxWidth: bounds.width).frames
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrangement(of subviews: Subviews, maxWidth: CGFloat) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        frames.reserveCapacity(subviews.count)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            if size.width > maxWidth {
                // Too wide for a row on its own (very large text): let it wrap within the width.
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            }
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width
            widest = max(widest, x)
            x += spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (frames, CGSize(width: widest, height: y + rowHeight))
    }
}

#Preview {
    ScrollView {
        TriggerInsightsCard()
            .padding()
    }
    .dawnScreenBackground()
    .previewEnvironment()
}
