import SwiftUI

/// The top of the Today screen: a big dawn orb for the habit with the longest current streak. The orb's sky moves
/// from night toward sunrise as that streak nears its next milestone, around the day count, with a live clock, the
/// user's rank and how long until the next milestone.
struct TodayHeroView: View {
    let habits: [Habit]

    /// The habit with the longest current streak: the one whose streak started first.
    static func heroHabit(in habits: [Habit]) -> Habit? {
        habits.min { $0.streakStart < $1.streakStart }
    }

    var body: some View {
        if let habit = Self.heroHabit(in: habits) {
            TodayHeroContent(habit: habit)
        }
    }
}

private struct TodayHeroContent: View {
    let habit: Habit

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 16) {
            // Only this part ticks every second; the chips below stay put.
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                TodayHeroLive(elapsed: habit.stats(at: timeline.date).currentStreak)
            }
            chips
        }
        .frame(maxWidth: .infinity)
    }

    private var chips: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            NavigationLink(value: habit) {
                Chip(text: Text(verbatim: "\(habit.emoji) \(habit.name)"), tint: habit.theme.accent)
                    .lineLimit(1)
            }
            .buttonStyle(PressableCardStyle())
            .accessibilityHint("Opens this habit")
            XPSummaryReader { summary in
                RankChip(summary: summary)
            }
        }
    }
}

/// Everything in the hero that changes with the clock.
private struct TodayHeroLive: View {
    let elapsed: TimeInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let parts = DurationFormatter.parts(elapsed)
        // Rounded so the orb only redraws when its sky visibly changes, not every second.
        let orbProgress = (Milestone.progress(toward: elapsed) * 400).rounded() / 400
        VStack(spacing: 12) {
            TodayHeroOrb(progress: orbProgress, headline: TodayHeroHeadline(parts: parts))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Free for \(parts.days) days, \(parts.hours) hours and \(parts.minutes) minutes"))
            TodayHeroClock(parts: parts)
                .accessibilityHidden(true)
            TodayNextMilestoneLine(elapsed: elapsed)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: parts)
    }
}

/// The big number in the orb: days once the streak passes a day, and hours or minutes before that, so a new streak
/// opens on how far it has come rather than on "0 days".
private struct TodayHeroHeadline: Equatable {
    enum Kind: Equatable {
        case days, hours, minutes
    }

    let value: Int
    let kind: Kind

    init(parts: DurationFormatter.Parts) {
        if parts.days > 0 {
            value = parts.days
            kind = .days
        } else if parts.hours > 0 {
            value = parts.hours
            kind = .hours
        } else {
            value = parts.minutes
            kind = .minutes
        }
    }

    var label: LocalizedStringKey {
        switch kind {
        case .days:
            return value == 1 ? "day free" : "days free"
        case .hours:
            return value == 1 ? "hour free" : "hours free"
        case .minutes:
            return value == 1 ? "minute free" : "minutes free"
        }
    }
}

private struct TodayHeroOrb: View {
    let progress: Double
    let headline: TodayHeroHeadline

    static let orbSize: CGFloat = 230

    /// The orb breathes, except in UI test runs (an endless animation keeps the app from ever looking idle).
    static var breathes: Bool {
        #if DEBUG
        return !UITestSupport.isActive
        #else
        return true
        #endif
    }

    var body: some View {
        let size = Self.orbSize
        let horizon = Palette.skyColors(progress: progress)[2]
        ZStack {
            // Faint light spilling from the orb into the night around it.
            Circle()
                .fill(RadialGradient(
                    colors: [horizon.opacity(0.26), .clear],
                    center: .center,
                    startRadius: size * 0.3,
                    endRadius: size * 0.85
                ))
                .frame(width: size * 1.7, height: size * 1.7)
                .allowsHitTesting(false)
            TodayMilestoneOrbit(progress: progress, diameter: size + 32)
            DawnOrb(progress: progress, size: size, animated: Self.breathes)
            headlineText
        }
        .frame(width: size * 1.3, height: size * 1.3)
        .padding(.vertical, -12)
    }

    private var headlineText: some View {
        VStack(spacing: 0) {
            Text("\(headline.value)")
                .font(.display(76))
                .foregroundStyle(Palette.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
            Text(headline.label)
                .font(.footnote.weight(.heavy))
                .tracking(2.2)
                .textCase(.uppercase)
                .foregroundStyle(Palette.textPrimary.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: Self.orbSize * 0.74)
        .shadow(color: Palette.ink.opacity(0.55), radius: 12, y: 3)
        .offset(y: -6)
    }
}

/// A thin orbit around the orb: the arc fills toward the next milestone, with a small sun traveling along it.
private struct TodayMilestoneOrbit: View {
    let progress: Double
    let diameter: CGFloat

    var body: some View {
        let clamped = min(max(progress, 0.002), 1)
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(clamped))
                .stroke(
                    AngularGradient(
                        colors: [Palette.amber.opacity(0.05), Palette.amber, Palette.sun],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * clamped)
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(Palette.sun)
                .frame(width: 10, height: 10)
                .shadow(color: Palette.sun.opacity(0.9), radius: 5)
                .shadow(color: Palette.amber.opacity(0.7), radius: 12)
                .offset(y: -diameter / 2)
                .rotationEffect(.degrees(360 * clamped))
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

/// Hours, minutes and seconds of the current day of the streak, ticking live.
private struct TodayHeroClock: View {
    let parts: DurationFormatter.Parts

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            unit(parts.hours, label: "hrs")
            separator
            unit(parts.minutes, label: "min")
            separator
            unit(parts.seconds, label: "sec")
        }
    }

    private func unit(_ value: Int, label: LocalizedStringKey) -> some View {
        VStack(spacing: 3) {
            Text(String(format: "%02d", value))
                .font(.display(30, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .microLabel()
        }
        .frame(minWidth: 54)
    }

    private var separator: some View {
        Text(verbatim: ":")
            .font(.display(26, weight: .semibold))
            .foregroundStyle(Palette.textTertiary)
    }
}

private struct TodayNextMilestoneLine: View {
    let elapsed: TimeInterval

    var body: some View {
        if let next = Milestone.next(after: elapsed) {
            Label {
                Text("\(DurationFormatter.compact(next.seconds - elapsed)) to \(next.title)")
                    .foregroundStyle(Palette.textSecondary)
            } icon: {
                Image(systemName: next.symbol)
                    .foregroundStyle(Palette.amber)
            }
            .font(.subheadline.weight(.semibold))
        } else {
            Label {
                Text("Every milestone unlocked")
                    .foregroundStyle(Palette.textSecondary)
            } icon: {
                Image(systemName: "crown.fill")
                    .foregroundStyle(Palette.sun)
            }
            .font(.subheadline.weight(.semibold))
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            TodayHeroView(habits: [PreviewData.sampleHabit])
                .padding()
        }
        .dawnScreenBackground(glow: 0.35)
    }
    .previewEnvironment()
}
