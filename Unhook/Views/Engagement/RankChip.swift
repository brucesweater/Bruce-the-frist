import SwiftUI

/// A compact rank badge: the rank's symbol in dawn gold, "Lv 4 · First Light", and a thin bar to the next rank.
struct RankChip: View {
    let summary: XPSummary

    init(summary: XPSummary) {
        self.summary = summary
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: summary.rank.symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Brand.dawn)
            VStack(alignment: .leading, spacing: 4) {
                Text("Lv \(summary.rank.level) · \(summary.rank.title)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                XPProgressBar(progress: summary.progressToNext, height: 3)
                    .frame(width: 64)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .background(Palette.surfaceRaised.opacity(0.78), in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.amber.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Level \(summary.rank.level), \(summary.rank.title)"))
        .accessibilityValue(valueText)
    }

    private var valueText: Text {
        if let next = summary.nextRank, let remaining = summary.xpToNext {
            return Text("\(remaining.formatted()) XP to \(next.title)")
        }
        return Text("Top rank reached")
    }
}

#Preview {
    RankChip(summary: XPSummary(total: 640))
        .padding()
        .background(DawnBackground())
}
