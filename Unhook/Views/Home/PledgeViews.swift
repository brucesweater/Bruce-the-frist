import SwiftUI
import SwiftData

/// Today's pledge on the Today screen: an invitation until the user pledges, then a quiet "done" with their pledge
/// streak.
struct PledgeCard: View {
    let pledgedToday: Bool
    let streak: Int
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                badge
                VStack(alignment: .leading, spacing: 3) {
                    Text(pledgedToday ? "Pledge complete" : "Take today's pledge")
                        .font(.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: 24, tint: Palette.amber, highlighted: !pledgedToday)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
        // Once today's pledge is done the card just reports it.
        .allowsHitTesting(!pledgedToday)
        .accessibilityHint(pledgedToday ? Text(verbatim: "") : Text("Opens today's pledge"))
    }

    private var subtitle: String {
        if pledgedToday {
            return String(localized: "See you tomorrow. Stay strong today.")
        }
        return streak > 0
            ? String(localized: "Keep your \(streak)-day streak alive.")
            : String(localized: "Commit to one clean day. Just today.")
    }

    private var badge: some View {
        ZStack {
            Circle()
                .fill(pledgedToday ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Palette.amber.opacity(0.16)))
            Circle()
                .strokeBorder(Palette.amber.opacity(pledgedToday ? 0 : 0.35), lineWidth: 1)
            Image(systemName: pledgedToday ? "checkmark" : "hand.raised.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(pledgedToday ? Palette.inkText : Palette.amber)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: 46, height: 46)
        .shadow(color: Palette.amber.opacity(pledgedToday ? 0.45 : 0), radius: 10)
        .symbolEffect(.bounce, value: reduceMotion ? false : pledgedToday)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var trailing: some View {
        if pledgedToday {
            if streak > 0 {
                TodayPledgeStreakChip(streak: streak)
            }
        } else {
            Image(systemName: "arrow.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.inkText)
                .frame(width: 34, height: 34)
                .background(Brand.gradient, in: Circle())
                .shadow(color: Palette.amber.opacity(0.4), radius: 8)
                .accessibilityHidden(true)
        }
    }
}

/// The pledge streak: a flame and the number of days in a row.
private struct TodayPledgeStreakChip: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
            Text("\(streak)")
                .monospacedDigit()
        }
        .font(.system(.subheadline, design: .rounded).weight(.bold))
        .foregroundStyle(Palette.streak)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Palette.streak.opacity(0.16), in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.streak.opacity(0.3), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(streak)-day pledge streak"))
    }
}

struct PledgeSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mood = 3
    @State private var pledged = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                moodPicker
                pledgeButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)
            .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDragIndicator(.visible)
        .presentationBackground {
            // The sky brightens the moment you pledge.
            DawnBackground(glow: pledged ? 0.8 : 0.45)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Palette.amber.opacity(0.4), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 46
                    ))
                    .frame(width: 92, height: 92)
                Circle()
                    .fill(Palette.amber.opacity(0.14))
                    .overlay(Circle().strokeBorder(Palette.amber.opacity(0.35), lineWidth: 1))
                    .frame(width: 56, height: 56)
                Image(systemName: pledged ? "checkmark.seal.fill" : "hand.raised.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Brand.dawn)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(height: 64)
            .accessibilityHidden(true)
            Text("Today's pledge")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.textPrimary)
            Text("I choose to stay free today. Not forever, just today.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var moodPicker: some View {
        VStack(spacing: 14) {
            Text("How are you feeling?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { value in
                    moodButton(value)
                }
            }
            Text(Self.moodWord(mood))
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.amber)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .glassSurface(cornerRadius: 24)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: mood)
    }

    private func moodButton(_ value: Int) -> some View {
        let isSelected = mood == value
        return Button {
            mood = value
            Haptics.selection()
        } label: {
            Text(MoodScale.emoji(for: value))
                .font(.system(size: 30))
                .frame(width: 50, height: 50)
                .background(Circle().fill(isSelected ? Palette.amber.opacity(0.2) : Palette.surfaceRaised.opacity(0.55)))
                .overlay(Circle().strokeBorder(isSelected ? Palette.amber : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1))
                .shadow(color: Palette.amber.opacity(isSelected ? 0.4 : 0), radius: 10)
                .scaleEffect(isSelected ? 1.08 : 1)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mood \(value) of 5")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var pledgeButton: some View {
        Button(action: pledge) {
            Label(
                pledged ? "Pledged!" : "I pledge for today",
                systemImage: pledged ? "checkmark.seal.fill" : "hand.raised.fill"
            )
        }
        .buttonStyle(PrimaryButtonStyle())
        .allowsHitTesting(!pledged)
    }

    private static func moodWord(_ mood: Int) -> LocalizedStringKey {
        switch mood {
        case 1: return "Rough day"
        case 2: return "Not great"
        case 3: return "Okay"
        case 4: return "Good"
        default: return "Great"
        }
    }

    private func pledge() {
        guard !pledged else { return }
        context.insert(Pledge(day: .now, mood: mood))
        if reduceMotion {
            pledged = true
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                pledged = true
            }
        }
        Haptics.success()
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            dismiss()
        }
    }
}

#Preview("Pledge card") {
    VStack(spacing: 16) {
        PledgeCard(pledgedToday: false, streak: 4) {}
        PledgeCard(pledgedToday: true, streak: 30) {}
    }
    .padding()
    .frame(maxHeight: .infinity)
    .background(DawnBackground())
}

#Preview {
    PledgeSheet()
        .previewEnvironment()
}
