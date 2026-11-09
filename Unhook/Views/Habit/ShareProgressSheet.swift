import SwiftUI

/// Renders a shareable progress card. Every share is free word-of-mouth marketing.
struct ShareProgressSheet: View {
    let habit: Habit

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.Keys.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode

    @State private var renderedImage: Image?

    /// A 4:5 portrait card, rendered at 1080 × 1350 pixels: the size most feeds show in full.
    private static let cardSize = CGSize(width: 320, height: 400)
    private static let renderScale: CGFloat = 1080 / 320

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 0)
                preview
                shareButton
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DawnBackground(glow: 0.45))
            .navigationTitle("Share your progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: render)
        }
    }

    private var preview: some View {
        card
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Palette.amber.opacity(0.22), radius: 28, y: 12)
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var shareButton: some View {
        if let renderedImage {
            ShareLink(
                item: renderedImage,
                preview: SharePreview("My Unhook streak", image: renderedImage)
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: Self.cardSize.width)
        } else {
            ProgressView()
                .tint(Palette.textPrimary)
        }
    }

    private var card: some View {
        ShareCardView(habit: habit, stats: habit.stats(), currencyCode: currencyCode)
            .frame(width: Self.cardSize.width, height: Self.cardSize.height)
    }

    private func render() {
        // ImageRenderer doesn't inherit this screen's environment, so pin the dark appearance explicitly.
        let renderer = ImageRenderer(content: card.environment(\.colorScheme, .dark))
        renderer.scale = Self.renderScale
        if let uiImage = renderer.uiImage {
            renderedImage = Image(uiImage: uiImage)
        }
    }
}

/// The image people share: a night sky warming into dawn, the day count, what they've won back and the
/// Unhook wordmark. Drawn only with shapes, gradients, text and a Canvas, so ImageRenderer reproduces it
/// exactly; fixed sizes keep the picture the same whatever the text size setting.
struct ShareCardView: View {
    let habit: Habit
    let stats: HabitStats
    let currencyCode: String

    private var days: Int {
        DurationFormatter.parts(stats.currentStreak).days
    }

    /// The sky in the orb is already warm on day one and reaches full sunrise at three months.
    private var orbProgress: Double {
        0.62 + 0.38 * min(1, Double(days) / 90)
    }

    var body: some View {
        VStack(spacing: 0) {
            HabitShareOrb(progress: orbProgress, emoji: habit.emoji)
            dayCount
            daysLabel
                .padding(.top, 4)
            Spacer(minLength: 12)
            metricsRow
            Spacer(minLength: 12)
            wordmark
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { HabitShareBackground() }
    }

    private var dayCount: some View {
        Text(days, format: .number)
            .font(.system(size: 84, weight: .heavy, design: .rounded))
            .foregroundStyle(LinearGradient(colors: [Color.white, Palette.sun], startPoint: .top, endPoint: .bottom))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            // The line box of an 84 pt font is much taller than its digits.
            .padding(.vertical, -8)
    }

    private var daysLabel: some View {
        Group {
            if days == 1 {
                Text("day free from \(habit.name)")
            } else {
                Text("days free from \(habit.name)")
            }
        }
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .tracking(1.6)
        .textCase(.uppercase)
        .foregroundStyle(Palette.amber)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
    }

    private var metrics: [HabitShareMetric] {
        var items: [HabitShareMetric] = []
        if stats.moneySaved >= 1 {
            items.append(HabitShareMetric(
                id: "money",
                value: MoneyFormatter.rounded(stats.moneySaved, code: currencyCode),
                label: "saved",
                color: Palette.money
            ))
        }
        if stats.minutesReclaimed >= 1 {
            items.append(HabitShareMetric(
                id: "time",
                value: DurationFormatter.minutes(stats.minutesReclaimed),
                label: "reclaimed",
                color: Palette.time
            ))
        }
        items.append(HabitShareMetric(
            id: "milestone",
            value: Milestone.latest(reachedBy: stats.currentStreak)?.title ?? String(localized: "Day one"),
            label: "milestone",
            color: Palette.celebrate
        ))
        return items
    }

    private var metricsRow: some View {
        let items = metrics
        return HStack(spacing: 0) {
            ForEach(items) { metric in
                if metric.id != items.first?.id {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1, height: 30)
                }
                HabitShareMetricView(metric: metric)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var wordmark: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(LinearGradient(colors: Palette.skyColors(progress: 0.9), startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 0.5))
                .frame(width: 14, height: 14)
            Text("Unhook")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.dawn)
        }
    }
}

/// One figure on the share card, e.g. "$566" "saved".
private struct HabitShareMetric: Identifiable {
    let id: String
    let value: String
    let label: LocalizedStringKey
    let color: Color
}

private struct HabitShareMetricView: View {
    let metric: HabitShareMetric

    var body: some View {
        VStack(spacing: 3) {
            Text(metric.value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(metric.color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(metric.label)
                .font(.system(size: 9.5, weight: .bold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Color.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}

/// The share card's sky: deep night at the top, warm dawn light rising from the bottom, a scatter of stars.
private struct HabitShareBackground: View {
    var body: some View {
        ZStack {
            Brand.night
            RadialGradient(
                colors: [Palette.violet.opacity(0.36), .clear],
                center: UnitPoint(x: 0.1, y: 0.0),
                startRadius: 0,
                endRadius: 250
            )
            RadialGradient(
                colors: [Palette.amber.opacity(0.48), Palette.rose.opacity(0.2), .clear],
                center: UnitPoint(x: 0.5, y: 1.12),
                startRadius: 0,
                endRadius: 320
            )
            StarField(count: 46, maxHeightFraction: 0.6, seed: 0x5A4E)
        }
    }
}

/// A still version of the dawn orb with the habit's emoji pinned to its edge. Its glow is a radial gradient
/// rather than a blur, so it renders the same on screen and in the shared image.
private struct HabitShareOrb: View {
    let progress: Double
    let emoji: String

    private let size: CGFloat = 100

    var body: some View {
        let colors = Palette.skyColors(progress: progress)
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [colors[2].opacity(0.55), Palette.rose.opacity(0.14), .clear],
                    center: .center,
                    startRadius: size * 0.4,
                    endRadius: size * 0.9
                ))
                .frame(width: size * 1.8, height: size * 1.8)
            sphere(colors)
            Text(emoji)
                .font(.system(size: 19))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Palette.night))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.24), lineWidth: 1))
                .offset(x: size * 0.36, y: size * 0.36)
        }
        .frame(width: size * 1.8, height: size * 1.3)
    }

    private func sphere(_ colors: [Color]) -> some View {
        Circle()
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .overlay {
                // The sun, nearly risen.
                Circle()
                    .fill(RadialGradient(
                        colors: [Palette.sun.opacity(0.95), Palette.amber.opacity(0.5), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.42
                    ))
                    .frame(width: size * 0.84, height: size * 0.84)
                    .offset(y: size * (0.64 - 0.36 * progress))
            }
            .overlay {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.24), .clear],
                        center: UnitPoint(x: 0.3, y: 0.22),
                        startRadius: 0,
                        endRadius: size * 0.5
                    ))
            }
            .clipShape(Circle())
            .overlay(
                Circle().strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.2
                )
            )
            .frame(width: size, height: size)
    }
}

#Preview {
    ShareProgressSheet(habit: PreviewData.sampleHabit)
        .previewEnvironment()
}
