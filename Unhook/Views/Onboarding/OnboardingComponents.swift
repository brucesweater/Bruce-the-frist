import SwiftUI

/// Shared layout for the question screens: a heading, scrollable content and an optional footer for buttons
/// that stays pinned above the keyboard.
struct OnboardingStepLayout<Content: View, Footer: View>: View {
    private let title: Text
    private let subtitle: Text?
    private let content: Content
    private let footer: Footer?

    init(
        title: Text,
        subtitle: Text? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    content
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 24)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)

            if let footer {
                VStack(spacing: 12) {
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            title
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                subtitle
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension OnboardingStepLayout where Footer == EmptyView {
    /// A screen without footer buttons (for example, one where tapping an option moves on).
    init(title: Text, subtitle: Text? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        self.footer = nil
    }
}

/// Back button plus a slim dawn-colored bar showing how far through the questions the user is.
struct OnboardingTopBar: View {
    let questionNumber: Int
    let questionCount: Int
    let onBack: () -> Void

    private var progress: Double {
        guard questionCount > 0 else { return 0 }
        return min(max(Double(questionNumber) / Double(questionCount), 0), 1)
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(Palette.surface.opacity(0.74), in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(PressableCardStyle())
            .accessibilityLabel("Back")

            OnboardingProgressBar(progress: progress)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Question \(questionNumber) of \(questionCount)"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

/// A track with a sun-to-ember gradient revealed from the leading edge, so the bar warms as it fills.
private struct OnboardingProgressBar: View {
    let progress: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(progress: Double) {
        self.progress = progress
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(
                        colors: [Palette.sun, Palette.amber, Palette.ember],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .mask(alignment: .leading) {
                        Capsule()
                            .frame(width: max(proxy.size.height, proxy.size.width * CGFloat(progress)))
                    }
                    .shadow(color: Palette.amber.opacity(0.55), radius: 6)
            }
        }
        .frame(height: 6)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: progress)
    }
}

/// A large tappable glass option with a radio indicator, for single-choice questions.
struct OnboardingChoiceRow: View {
    let title: Text
    let subtitle: Text
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconBadge(systemImage: systemImage, tint: isSelected ? Palette.amber : Palette.textSecondary, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    title
                        .font(.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                    subtitle
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
                OnboardingRadio(isOn: isSelected)
            }
            .padding(16)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onboardingPanel(isHighlighted: isSelected)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// An empty ring, or a dawn-gold disc with a check mark when selected.
private struct OnboardingRadio: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(isOn ? 0 : 0.3), lineWidth: 1.5)
            if isOn {
                Circle()
                    .fill(Brand.gradient)
                Image(systemName: "checkmark")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Palette.inkText)
            }
        }
        .frame(width: 26, height: 26)
        .accessibilityHidden(true)
    }
}

extension View {
    /// The frosted glass panel used for tiles, rows and inputs in onboarding and "New habit". Highlighted panels
    /// (the selected option, the focused field) get a warm tint, a glowing outline and a soft halo.
    func onboardingPanel(
        cornerRadius: CGFloat = 20,
        isHighlighted: Bool = false,
        tint: Color = Palette.amber
    ) -> some View {
        modifier(OnboardingPanel(cornerRadius: cornerRadius, isHighlighted: isHighlighted, tint: tint))
    }
}

private struct OnboardingPanel: ViewModifier {
    let cornerRadius: CGFloat
    let isHighlighted: Bool
    let tint: Color

    func body(content: Content) -> some View {
        content
            .glassSurface(cornerRadius: cornerRadius, tint: isHighlighted ? tint : nil, highlighted: isHighlighted)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .opacity(isHighlighted ? 1 : 0)
            }
            .shadow(color: tint.opacity(isHighlighted ? 0.28 : 0), radius: 14)
    }
}
