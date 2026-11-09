import SwiftUI

/// The Progress tab's heat map of the last 12 weeks: one square per day, glowing amber on days every habit stayed
/// clean (brighter the more habits that was), a dim rose on a day with a slip, and empty before the first habit.
/// Rows run Monday to Sunday; today, outlined, is in the last column.
struct CleanDaysCalendar: View {
    let model: CleanDays

    @ScaledMetric(relativeTo: .caption2) private var monthRowHeight: CGFloat = 14

    private let spacing: CGFloat = 4
    private static let legendLevels: [Double] = [0.25, 0.5, 0.75, 1]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            summary
            VStack(alignment: .leading, spacing: 6) {
                monthRow
                grid
            }
            legend
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Clean days, last 12 weeks"))
        .accessibilityValue(accessibilitySummary)
    }

    // MARK: Summary

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.cleanDayCount, format: .number)
                    .font(.display(40))
                    .monospacedDigit()
                    .foregroundStyle(Brand.dawn)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text(unitLabel)
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: 0)
            }
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var unitLabel: LocalizedStringKey {
        model.cleanDayCount == 1 ? "clean day" : "clean days"
    }

    private var caption: LocalizedStringKey {
        model.trackedDayCount == 0
            ? "Your clean days will light up here, one square at a time."
            : "Each square is a day. The more habits you keep clean, the brighter it glows."
    }

    // MARK: Grid

    /// Month names over the columns. The first slot lines up with the weekday labels.
    private var monthRow: some View {
        HStack(spacing: spacing) {
            Color.clear
                .frame(maxWidth: .infinity)
            ForEach(model.weeks.indices, id: \.self) { column in
                Color.clear
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) {
                        if let label = model.monthLabels.first(where: { $0.column == column }) {
                            Text(label.date, format: .dateTime.month(.abbreviated))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Palette.textTertiary)
                                .fixedSize()
                        }
                    }
            }
        }
        .frame(height: monthRowHeight)
        .accessibilityHidden(true)
    }

    /// Thirteen equal columns: the weekday letters, then one column per week, oldest first.
    private var grid: some View {
        HStack(alignment: .top, spacing: spacing) {
            VStack(spacing: spacing) {
                ForEach(0..<CleanDays.daysPerWeek, id: \.self) { row in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Text(weekdaySymbol(row: row))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Palette.textTertiary)
                                .fixedSize()
                        }
                }
            }
            .frame(maxWidth: .infinity)
            ForEach(model.weeks.indices, id: \.self) { column in
                VStack(spacing: spacing) {
                    ForEach(model.weeks[column]) { day in
                        CleanDaySquare(day: day, intensity: model.intensity(of: day))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// The very short name of a weekday row (0 is Monday) in the user's language.
    private func weekdaySymbol(row: Int) -> String {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let index = (row + 1) % CleanDays.daysPerWeek
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    // MARK: Legend

    private var legend: some View {
        HStack(spacing: 5) {
            Text("Less")
            ForEach(Self.legendLevels, id: \.self) { level in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(CleanDaySquare.cleanFill(intensity: level))
                    .frame(width: 11, height: 11)
            }
            Text("More")
            Spacer(minLength: 12)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(CleanDaySquare.slipColor)
                .frame(width: 11, height: 11)
            Text("Slip")
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Palette.textTertiary)
        .accessibilityHidden(true)
    }

    // MARK: Accessibility

    /// "41 clean days in the last 12 weeks. 1 day with a slip."
    private var accessibilitySummary: Text {
        let clean = model.cleanDayCount
        let cleanText = clean == 1
            ? Text("1 clean day in the last 12 weeks")
            : Text("\(clean) clean days in the last 12 weeks")
        let slips = model.slipDayCount
        if slips == 0 {
            return cleanText
        }
        let slipText = slips == 1 ? Text("1 day with a slip") : Text("\(slips) days with a slip")
        return cleanText + Text(verbatim: ". ") + slipText
    }
}

/// One day of the calendar.
private struct CleanDaySquare: View {
    let day: CleanDay
    /// 0...1, from `CleanDays.intensity(of:)`.
    let intensity: Double

    static let slipColor = Palette.rose.opacity(0.32)
    private static let cornerRadius: CGFloat = 5

    var body: some View {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
            .fill(fill)
            .overlay {
                if day.isToday {
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                        .strokeBorder(Palette.textPrimary, lineWidth: 1.5)
                }
            }
            .shadow(color: Palette.amber.opacity(day.status == .clean ? 0.5 * intensity : 0), radius: 4 * intensity)
            .aspectRatio(1, contentMode: .fit)
    }

    private var fill: AnyShapeStyle {
        switch day.status {
        case .clean: AnyShapeStyle(Self.cleanFill(intensity: intensity))
        case .slip: AnyShapeStyle(Self.slipColor)
        case .untracked: AnyShapeStyle(Color.white.opacity(0.05))
        case .future: AnyShapeStyle(Color.clear)
        }
    }

    /// Ember when few habits stayed clean, warming to bright gold when all of them did.
    static func cleanFill(intensity: Double) -> LinearGradient {
        let t = min(max(intensity, 0), 1)
        let opacity = 0.4 + 0.6 * t
        return LinearGradient(
            colors: [
                Palette.mix(0xFF7A45, 0xFFB547, t).opacity(opacity),
                Palette.mix(0xFFB547, 0xFFE08A, t).opacity(opacity),
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }
}

#Preview {
    let start = Date.now.addingTimeInterval(-40 * 86_400)
    let model = CleanDays(habits: [
        CleanDaysHabit(start: start, slips: [Date.now.addingTimeInterval(-12 * 86_400)]),
        CleanDaysHabit(start: Date.now.addingTimeInterval(-9 * 86_400), slips: []),
    ])
    return CleanDaysCalendar(model: model)
        .padding()
        .background(DawnBackground())
}
