import SwiftUI

/// One short, practical tip a day.
struct TipOfTheDayCard: View {
    init() {}

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            TipCardContent(tip: DailyTips.tip(for: timeline.date))
        }
        .accessibilityIdentifier("tipCard")
    }
}

private struct TipCardContent: View {
    let tip: DailyTip

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tip of the day")
                .microLabel(Palette.amber)
            HStack(alignment: .top, spacing: 14) {
                IconBadge(systemImage: tip.systemImage, tint: Palette.sky, size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title)
                        .font(.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tip.body)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 24)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TipOfTheDayCard()
        .padding()
        .background(DawnBackground())
}
