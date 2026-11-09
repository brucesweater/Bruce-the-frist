import SwiftUI

/// The payoff: what a year free gives back, counting up from zero, plus how close the first milestone is.
struct OnboardingProjectionStep: View {
    let answers: OnboardingAnswers
    let onContinue: () -> Void

    @AppStorage(AppSettings.Keys.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var heroFontSize: CGFloat = 64

    /// Share (0...1) of the final numbers currently shown, driven by the count-up.
    @State private var progress: Double = 0
    @State private var now = Date.now

    private static let countUpSteps = 30

    init(answers: OnboardingAnswers, onContinue: @escaping () -> Void) {
        self.answers = answers
        self.onContinue = onContinue
    }

    private var projection: OnboardingProjection { answers.projection }
    private var showsMoney: Bool { projection.yearlyMoney >= 1 }
    private var showsHours: Bool { projection.yearlyHours >= 1 }
    private var showsUnits: Bool { projection.yearlyUnits >= 1 && !answers.draft.unitName.isEmpty }

    var body: some View {
        OnboardingStepLayout(
            title: Text("Your first year free"),
            subtitle: Text("Here's what quitting gives back, based on your answers.")
        ) {
            VStack(spacing: 12) {
                if showsMoney {
                    moneyCard
                }
                if showsHours || showsUnits {
                    tiles
                }
                // Also covers tiny inputs that round to nothing, so the screen never shows only the milestone.
                if !showsMoney && !showsHours && !showsUnits {
                    uncountableCard
                }
                milestoneCard
            }
        } footer: {
            Button("Let's do this") {
                Haptics.tap()
                onContinue()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .task { await countUp() }
    }

    // MARK: Cards

    /// The yearly money as one huge dawn-gold numeral.
    private var moneyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("In one year you'll save")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
            Text(MoneyFormatter.rounded(projection.yearlyMoney * progress, code: currencyCode))
                .font(.system(size: heroFontSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText())
                .foregroundStyle(Brand.dawn)
                .shadow(color: Palette.amber.opacity(0.35), radius: 18, y: 4)
            Text("That's \(MoneyFormatter.precise(projection.dailyCost, code: currencyCode)) a day back in your pocket.")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background {
            RadialGradient(
                colors: [Palette.amber.opacity(0.22), .clear],
                center: UnitPoint(x: 0.2, y: 0.55),
                startRadius: 0,
                endRadius: 260
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .glassSurface(cornerRadius: 28, tint: Palette.amber, highlighted: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("In one year you'll save \(MoneyFormatter.rounded(projection.yearlyMoney, code: currencyCode))"))
    }

    private var tiles: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            if showsHours {
                hoursTile
            }
            if showsUnits {
                unitsTile
            }
        }
    }

    private var hoursTile: some View {
        ProjectionTile(
            systemImage: "clock.fill",
            caption: Text("You'll win back"),
            value: (projection.yearlyHours * progress).clampedWholeNumber.formatted(),
            unit: Text("hours"),
            tint: Palette.time,
            accessibilityText: Text("You'll win back \(projection.yearlyHours.clampedWholeNumber) hours")
        )
    }

    private var unitsTile: some View {
        ProjectionTile(
            systemImage: "hand.raised.fill",
            caption: Text("You'll skip"),
            value: (projection.yearlyUnits * progress).clampedWholeNumber.formatted(),
            unit: Text(answers.draft.unitName),
            tint: Palette.units,
            accessibilityText: Text("You'll skip \(projection.yearlyUnits.clampedWholeNumber) \(answers.draft.unitName)")
        )
    }

    private var uncountableCard: some View {
        HStack(alignment: .top, spacing: 14) {
            IconBadge(systemImage: "sparkles", tint: Palette.violet, size: 40)
            VStack(alignment: .leading, spacing: 6) {
                Text("Some wins can't be counted")
                    .font(.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                Text("More calm, more control, and proof you can do hard things. Every day free adds up.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .glassSurface(cornerRadius: 26, tint: Palette.violet)
        .accessibilityElement(children: .combine)
    }

    private var milestoneCard: some View {
        let preview = answers.milestonePreview(now: now)
        return HStack(spacing: 14) {
            Image(systemName: preview?.milestone.symbol ?? "crown.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(Palette.inkText)
                .frame(width: 48, height: 48)
                .background(Brand.gradient, in: Circle())
                .shadow(color: Palette.amber.opacity(0.45), radius: 10)
                .accessibilityHidden(true)
            Text(milestoneText(preview))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassSurface(cornerRadius: 22)
        .accessibilityElement(children: .combine)
    }

    private func milestoneText(_ preview: OnboardingMilestonePreview?) -> String {
        guard let preview else {
            return String(localized: "You've already passed every milestone. That's incredible.")
        }
        let wait = OnboardingCopy.timeUntil(preview.remaining)
        if preview.isFirst {
            return String(localized: "Your first milestone, \(preview.milestone.title), unlocks in \(wait).")
        }
        return String(localized: "You're already on your way. Next up: \(preview.milestone.title), in \(wait).")
    }

    // MARK: Count-up

    /// Rolls the numbers up from zero with an ease-out curve. Reduce Motion shows the totals straight away.
    private func countUp() async {
        guard progress < 1 else { return }
        guard !reduceMotion, showsMoney || showsHours || showsUnits else {
            progress = 1
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(350))
            for index in 1...Self.countUpSteps {
                let linear = Double(index) / Double(Self.countUpSteps)
                withAnimation(.easeOut(duration: 0.1)) {
                    progress = 1 - pow(1 - linear, 3)
                }
                try await Task.sleep(for: .milliseconds(40))
            }
        } catch {
            // The screen went away mid-count; nothing left to animate.
            return
        }
        progress = 1
        Haptics.soft()
    }
}

/// A yearly figure in its role color (time is sky, units are amber) on a glass tile.
private struct ProjectionTile: View {
    let systemImage: String
    let caption: Text
    let value: String
    let unit: Text
    let tint: Color
    let accessibilityText: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            IconBadge(systemImage: systemImage, tint: tint, size: 32)
            caption
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
            Text(value)
                .font(.display(34))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .foregroundStyle(tint)
            unit
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(cornerRadius: 22, tint: tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}

#Preview {
    ZStack {
        DawnBackground(glow: 0.5)
        OnboardingProjectionStep(answers: .preview) {}
    }
    .environment(\.colorScheme, .dark)
    .previewEnvironment()
}
