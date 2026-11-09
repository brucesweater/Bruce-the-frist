import SwiftUI

/// Bruce's links and Unhook's support pages. Shared by Settings, the founder page and the privacy policy.
enum FounderLinks {
    static let emailAddress = "gaojiaxuan2@gmail.com"
    /// Opens Mail with "Unhook support" as the subject.
    static let supportEmail = URL(string: "mailto:gaojiaxuan2@gmail.com?subject=Unhook%20support")!
    /// A note to Bruce from the founder page.
    static let helloEmail = URL(string: "mailto:gaojiaxuan2@gmail.com?subject=Hi%20Bruce")!
    static let instagram = URL(string: "https://www.instagram.com/brucesweater/")!
    static let website = URL(string: "https://brucesweater.github.io")!
    static let supportPage = URL(string: "https://onyx-payment-888.notion.site/Unhook-Support-413b68ad1a0f8155a50eea137d02086a")!
    static let privacyPolicy = URL(string: "https://onyx-payment-888.notion.site/Unhook-Privacy-Policy-413b68ad1a0f818bb77dd8f06dfb3919")!
    static let helplines = URL(string: "https://findahelpline.com")!
}

/// Bruce's portrait in a circle, framed by a glowing dawn ring. On the Settings founder card and the founder page.
struct FounderAvatar: View {
    /// The photo's diameter. The ring and its glow sit just outside it.
    var size: CGFloat
    /// Slowly turns the ring's colors. Stays still when Reduce Motion is on.
    var animated = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let ringColors: [Color] = [
        Palette.sun, Palette.amber, Palette.ember, Palette.rose, Palette.violet, Palette.sky, Palette.sun,
    ]

    private var ringWidth: CGFloat { max(2, size * 0.035) }
    private var gap: CGFloat { max(2, size * 0.035) }
    private var outerSize: CGFloat { size + 2 * (ringWidth + gap) }

    var body: some View {
        ZStack {
            halo
            photo
        }
        .frame(width: outerSize, height: outerSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Photo of Bruce Gao"))
        .accessibilityAddTraits(.isImage)
    }

    private var photo: some View {
        Image("FounderPhoto")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
    }

    @ViewBuilder
    private var halo: some View {
        if animated && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                ring(angle: Self.angle(at: context.date))
            }
        } else {
            ring(angle: .degrees(0))
        }
    }

    private func ring(angle: Angle) -> some View {
        let gradient = AngularGradient(colors: Self.ringColors, center: .center, angle: angle)
        return ZStack {
            Circle()
                .fill(gradient)
                .frame(width: size, height: size)
                .blur(radius: size * 0.14)
                .opacity(0.75)
            Circle()
                .strokeBorder(gradient, lineWidth: ringWidth)
                .frame(width: outerSize, height: outerSize)
        }
    }

    /// One slow turn every 18 seconds.
    private static func angle(at date: Date) -> Angle {
        let period = 18.0
        let turns = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        return .degrees(turns * 360)
    }
}

extension View {
    /// Darkens the status bar and a see-through navigation bar, so content scrolling underneath fades out instead of
    /// running into the title. Pair with `.toolbarBackground(.hidden, for: .navigationBar)`.
    func fadesContentUnderNavigationBar() -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: 0)
                .background(
                    LinearGradient(
                        colors: [Palette.ink.opacity(0.9), Palette.ink.opacity(0.55), Palette.ink.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    ignoresSafeAreaEdges: .top
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        FounderAvatar(size: 140, animated: true)
        FounderAvatar(size: 52)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DawnBackground(glow: 0.5))
}
