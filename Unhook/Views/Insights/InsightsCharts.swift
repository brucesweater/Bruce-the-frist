import SwiftUI
import Charts

// Building blocks of the Progress tab: titled glass sections and the charts drawn in the Dawn palette.

/// A titled section of the Progress tab: a section header over a frosted glass card.
struct InsightsSection<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    var tint: Color = Palette.amber
    var trailing: Text?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, systemImage: systemImage, tint: tint, trailing: trailing)
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: 24)
        }
    }
}

/// What a section shows before there's anything to chart.
struct InsightsPlaceholder: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    }
}

/// The one number a chart is about, with a short label beside it ("12 beaten in the last two weeks").
struct InsightsHeadline: View {
    let value: Text
    let label: Text
    var tint: Color = Palette.amber

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            value
                .font(.display(34))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The shared chart look: quiet dashed grid lines, tertiary axis labels and palette gradients.
enum InsightsChartStyle {
    static let gridStroke = StrokeStyle(lineWidth: 0.5, dash: [3, 4])

    /// Cravings are violet everywhere; bars brighten toward the top.
    static let violetBar = LinearGradient(
        colors: [Palette.violet.opacity(0.45), Palette.violet],
        startPoint: .bottom,
        endPoint: .top
    )

    /// The highlighted bar: the warm dawn colors.
    static let dawnBar = LinearGradient(colors: [Palette.ember, Palette.amber, Palette.sun], startPoint: .bottom, endPoint: .top)

    static let moodLine = LinearGradient(colors: [Palette.amber, Palette.sun], startPoint: .leading, endPoint: .trailing)

    static let moodArea = LinearGradient(
        colors: [Palette.amber.opacity(0.32), Palette.amber.opacity(0.0)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Whole-number ticks from 0 to `top`, with a middle tick when it falls on a whole number.
    static func ticks(upTo top: Int) -> [Int] {
        let top = max(top, 1)
        return top.isMultiple(of: 2) ? [0, top / 2, top] : [0, top]
    }
}

/// Cravings beaten per day: violet bars with rounded tops.
struct InsightsCravingsChart: View {
    let data: [DayCount]

    var body: some View {
        let top = max(data.map(\.count).max() ?? 0, 1)
        Chart(data) { item in
            BarMark(
                x: .value("Day", item.day, unit: .day),
                y: .value("Cravings", item.count)
            )
            .foregroundStyle(InsightsChartStyle.violetBar)
            .cornerRadius(6, style: .continuous)
        }
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
            AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .frame(height: 170)
    }
}

/// Mood from the daily pledges: a sun-gold line over a soft gradient, with today's mood glowing at the end.
struct InsightsMoodChart: View {
    /// Oldest first.
    let pledges: [Pledge]

    var body: some View {
        Chart {
            ForEach(pledges) { pledge in
                AreaMark(
                    x: .value("Day", StoredDay.localStart(of: pledge.day), unit: .day),
                    yStart: .value("Mood", 1),
                    yEnd: .value("Mood", pledge.mood)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(InsightsChartStyle.moodArea)

                LineMark(
                    x: .value("Day", StoredDay.localStart(of: pledge.day), unit: .day),
                    y: .value("Mood", pledge.mood)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(InsightsChartStyle.moodLine)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            if let latest = pledges.last {
                PointMark(
                    x: .value("Day", StoredDay.localStart(of: latest.day), unit: .day),
                    y: .value("Mood", latest.mood)
                )
                .foregroundStyle(Palette.sun.opacity(0.25))
                .symbolSize(300)

                PointMark(
                    x: .value("Day", StoredDay.localStart(of: latest.day), unit: .day),
                    y: .value("Mood", latest.mood)
                )
                .foregroundStyle(Palette.sun)
                .symbolSize(60)
            }
        }
        .chartYScale(domain: 1...5)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [1, 3, 5]) { value in
                AxisGridLine(stroke: InsightsChartStyle.gridStroke)
                    .foregroundStyle(Palette.hairline)
                AxisValueLabel {
                    if let mood = value.as(Int.self) {
                        Text(MoodScale.emoji(for: mood))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .frame(height: 170)
    }
}
