import SwiftUI
import SwiftData

/// Today's three numbers across every habit, ticking up live: money saved, time reclaimed and cravings beaten.
struct SavingsBanner: View {
    let habits: [Habit]
    let currencyCode: String

    @Query private var urges: [Urge]

    var body: some View {
        let cravingsBeaten = urges.filter(\.resisted).count
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let totals = HabitTotals(habits: habits, at: timeline.date)
            HStack(spacing: 10) {
                TodayStatTile(
                    value: MoneyFormatter.precise(totals.moneySaved, code: currencyCode),
                    title: "Money saved",
                    systemImage: "banknote.fill",
                    tint: Palette.money
                )
                TodayStatTile(
                    value: DurationFormatter.minutes(totals.minutesReclaimed),
                    title: "Time reclaimed",
                    systemImage: "clock.fill",
                    tint: Palette.time
                )
                TodayStatTile(
                    value: cravingsBeaten.formatted(),
                    title: "Cravings beaten",
                    systemImage: "shield.lefthalf.filled",
                    tint: Palette.cravings
                )
            }
            // Same height for all three tiles.
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One glass tile in the row, washed in its number's color.
private struct TodayStatTile: View {
    let value: String
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            IconBadge(systemImage: systemImage, tint: tint, size: 30)
            Spacer(minLength: 4)
            Text(value)
                .font(.display(22))
                .foregroundStyle(Palette.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: value)
            Text(title)
                .microLabel()
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .glassSurface(cornerRadius: 22, tint: tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value))
    }
}

#Preview {
    SavingsBanner(habits: [PreviewData.sampleHabit], currencyCode: "USD")
        .padding()
        .frame(maxHeight: .infinity)
        .background(DawnBackground())
        .previewEnvironment()
}
