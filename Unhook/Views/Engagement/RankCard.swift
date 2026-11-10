import SwiftUI

/// The big rank card for the Progress tab: the rank in a glowing medallion, the level and title, a bar to the next
/// rank, and "How to earn XP" with the user's own counts.
struct RankCard: View {
    init() {}

    var body: some View {
        XPSummaryReader { summary in
            RankCardContent(summary: summary)
        }
    }
}

private struct RankCardContent: View {
    let summary: XPSummary

    @State private var showsRewards = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            progress
            Divider()
                .overlay(Palette.hairline)
            rewardsToggle
            if showsRewards {
                rewardsList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 28, tint: Palette.amber, highlighted: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("rankCard")
    }

    private var header: some View {
        HStack(spacing: 18) {
            RankMedallion(rank: summary.rank, size: 76)
                .padding(6)
            VStack(alignment: .leading, spacing: 4) {
                Text("Level \(summary.rank.level)")
                    .microLabel(Palette.amber)
                Text(summary.rank.title)
                    .font(.display(28, weight: .heavy))
                    .foregroundStyle(Brand.dawn)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(summary.total.formatted()) XP")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            XPProgressBar(progress: summary.progressToNext, height: 10)
            HStack(spacing: 8) {
                if let next = summary.nextRank, let remaining = summary.xpToNext {
                    Text("\(remaining.formatted()) XP to \(next.title)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        Image(systemName: next.symbol)
                            .accessibilityHidden(true)
                        Text("Lv \(next.level)")
                    }
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.textTertiary)
                } else {
                    Text("You've reached the top rank. Legendary.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.sun)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var rewardsToggle: some View {
        Button {
            Haptics.selection()
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                showsRewards.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Palette.amber)
                    .accessibilityHidden(true)
                Text("How to earn XP")
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.textTertiary)
                    .rotationEffect(.degrees(showsRewards ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.semibold))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(showsRewards ? Text("Expanded") : Text("Collapsed"))
    }

    private var rewardsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(rewardRows) { source in
                XPRewardRow(source: source)
            }
            Label {
                Text("XP only goes up. A slip never takes any of it away.")
            } icon: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Palette.rose)
            }
            .font(.footnote)
            .foregroundStyle(Palette.textSecondary)
            .padding(.top, 2)
        }
    }

    /// The user's own counts, or every way to earn XP at zero when the summary has no breakdown.
    private var rewardRows: [XPSource] {
        if summary.sources.isEmpty {
            return XPSource.Kind.allCases.map { XPSource(kind: $0, count: 0) }
        }
        return summary.sources
    }
}

private struct XPRewardRow: View {
    let source: XPSource

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(systemImage: source.kind.systemImage, tint: source.kind.tint, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.kind.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text("\(source.count.formatted()) so far · \(source.xp.formatted()) XP")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            Chip(text: Text("+\(source.xpEach) XP"), tint: Palette.amber)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension XPSource.Kind {
    var tint: Color {
        switch self {
        case .cleanDays: Palette.streak
        case .pledges: Palette.amber
        case .cravings: Palette.cravings
        case .missions: Palette.rose
        case .perfectDays: Palette.sun
        case .challengeDays: Palette.amber
        case .achievements: Palette.celebrate
        }
    }
}

#Preview {
    ScrollView {
        RankCard()
            .padding()
    }
    .dawnScreenBackground()
    .previewEnvironment()
}
