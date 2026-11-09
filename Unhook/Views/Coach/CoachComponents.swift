import SwiftUI

/// The coach sheet's header: a glowing avatar, the coach's name, the privacy promise and a Done button.
struct CoachHeader: View {
    let usesOnDeviceAI: Bool
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                CoachAvatar(size: 46, glows: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Unhook coach")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    subtitle
                        .font(.footnote)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                doneButton
            }
            CoachPrivacyChip()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    /// Says which engine answers: Apple's on-device model, or the built-in coach.
    @ViewBuilder private var subtitle: some View {
        if usesOnDeviceAI {
            Label("On-device AI", systemImage: "cpu")
        } else {
            Text("Here for you, day or night")
        }
    }

    private var doneButton: some View {
        Button(action: onDone) {
            Text("Done")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Palette.surfaceRaised.opacity(0.7), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// The coach's avatar: sparkles in a dawn-gold circle. `glows` adds a soft halo, for the header.
struct CoachAvatar: View {
    var size: CGFloat = 28
    var glows = false

    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(Palette.inkText)
            .frame(width: size, height: size)
            .background(Brand.gradient, in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            .background {
                if glows {
                    Circle()
                        .fill(Palette.amber.opacity(0.45))
                        .frame(width: size * 1.6, height: size * 1.6)
                        .blur(radius: size * 0.3)
                }
            }
            .shadow(color: Palette.amber.opacity(glows ? 0.5 : 0.25), radius: glows ? 12 : 4)
            .accessibilityHidden(true)
    }
}

/// The privacy promise, always visible under the coach's name.
struct CoachPrivacyChip: View {
    var body: some View {
        Label("Private: nothing leaves your iPhone", systemImage: "lock.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Shown after a crisis message: how to reach real help right now. Never paywalled.
struct CoachCrisisBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("You don't have to face this alone", systemImage: "heart.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.rose)
            Text("If you're in danger or thinking about hurting yourself, call your local emergency number now or contact a crisis line.")
                .font(.footnote)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let url = CoachSafety.helplineURL {
                Link(destination: url) {
                    Label("Find a free helpline", systemImage: "phone.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Palette.inkText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Brand.sos, in: Capsule())
                        .contentShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(cornerRadius: 20, tint: Palette.rose, highlighted: true)
        .accessibilityElement(children: .contain)
    }
}

/// One chat bubble: the user's on the right in dawn gold with dark text, the coach's on the left in glass.
struct CoachMessageBubble: View {
    let message: CoachMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 48)
            } else {
                CoachAvatar()
            }
            bubble
            if !isUser {
                Spacer(minLength: 32)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// Rounded everywhere except the corner nearest the speaker.
    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 20,
            bottomLeadingRadius: isUser ? 20 : 6,
            bottomTrailingRadius: isUser ? 6 : 20,
            topTrailingRadius: 20,
            style: .continuous
        )
    }

    private var bubble: some View {
        Text(message.text)
            .font(.body)
            .foregroundStyle(isUser ? Palette.inkText : Palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background { bubbleBackground }
            .textSelection(.enabled)
    }

    @ViewBuilder private var bubbleBackground: some View {
        if isUser {
            bubbleShape
                .fill(Brand.gradient)
                .shadow(color: Palette.amber.opacity(0.25), radius: 10, y: 4)
        } else {
            CoachGlassFill(shape: bubbleShape)
        }
    }

    private var accessibilityText: String {
        isUser ? String(localized: "You: \(message.text)") : String(localized: "Coach: \(message.text)")
    }
}

/// Three dawn-gold dots rising and falling in a wave while the coach is "typing". Still with Reduce Motion.
struct CoachTypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 20,
            bottomLeadingRadius: 6,
            bottomTrailingRadius: 20,
            topTrailingRadius: 20,
            style: .continuous
        )
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            CoachAvatar()
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                dots(at: timeline.date.timeIntervalSinceReferenceDate)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background { CoachGlassFill(shape: bubbleShape) }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Coach is typing")
    }

    private func dots(at time: TimeInterval) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Brand.gradient)
                    .frame(width: 8, height: 8)
                    .opacity(0.4 + 0.6 * wave(index, at: time))
                    .offset(y: -4 * wave(index, at: time))
            }
        }
        .frame(height: 12, alignment: .bottom)
    }

    /// 0…1 for dot `index`, each dot a little behind the one before it.
    private func wave(_ index: Int, at time: TimeInterval) -> Double {
        guard !reduceMotion else { return 0.5 }
        return (sin(time * 2 * Double.pi / 1.1 - Double(index) * 0.7) + 1) / 2
    }
}

/// A suggested message the user can send with one tap.
struct CoachQuickReplyChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background { CoachGlassFill(shape: Capsule()) }
                .contentShape(Capsule())
        }
        .buttonStyle(PressableCardStyle())
    }
}

/// Frosted glass in any shape, for coach bubbles and chips.
private struct CoachGlassFill<GlassShape: Shape>: View {
    let shape: GlassShape

    var body: some View {
        ZStack {
            shape.fill(Palette.surface.opacity(0.8))
            shape.fill(LinearGradient(colors: [Color.white.opacity(0.08), .clear], startPoint: .top, endPoint: .center))
            shape.stroke(
                LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        CoachHeader(usesOnDeviceAI: false) {}
        CoachCrisisBanner()
        CoachMessageBubble(message: CoachMessage(role: .coach, text: "Hey — 12 days free from Smoking. That's huge. What's going on right now?"))
        CoachMessageBubble(message: CoachMessage(role: .user, text: "I'm at a party"))
        CoachTypingIndicator()
        CoachQuickReplyChip(text: "I'm stressed") {}
    }
    .padding()
    .background { DawnBackground() }
    .previewEnvironment()
}
