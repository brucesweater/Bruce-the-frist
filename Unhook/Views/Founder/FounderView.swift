import SwiftUI

/// "Meet the founder": who made Unhook and why, with Bruce's Instagram, his other apps and his website.
/// Pushed from the founder card at the top of Settings.
struct FounderView: View {
    @Environment(\.openURL) private var openURL
    @ScaledMetric(relativeTo: .headline) private var appIconSize: CGFloat = 58

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                hero
                storyCard
                instagramButton
                appsSection
                linksCard
                signOff
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 36)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .dawnScreenBackground(glow: 0.5)
        .navigationTitle("Meet the founder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .fadesContentUnderNavigationBar()
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 16) {
            FounderAvatar(size: 140, animated: true)
            VStack(spacing: 6) {
                Text("Bruce Gao")
                    .font(.screenTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Founder of Unhook · High school senior in West Des Moines, Iowa")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Chip(text: Text("\(Image(systemName: "sparkles")) Built with Claude Code"), tint: Palette.violet)
                .accessibilityLabel(Text("Built with Claude Code"))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: Story

    private var storyCard: some View {
        Card(title: "Why I made Unhook", systemImage: "hand.wave.fill", tint: Palette.amber) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Hi, I'm Bruce. I designed Unhook and built it with AI-assisted coding (Claude Code).")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Palette.textPrimary)
                Text("Breaking a habit is one of the hardest things anyone does, and getting help shouldn't take an account, ads or a subscription. Everything in Unhook is free and stays on your iPhone.")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                Text("If Unhook helps you, I'd love to hear about it.")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Instagram

    private var instagramButton: some View {
        Button {
            Haptics.tap()
            openURL(FounderLinks.instagram)
        } label: {
            Label("Follow @brucesweater on Instagram", systemImage: "camera.fill")
                .multilineTextAlignment(.center)
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityHint(Text("Opens Instagram"))
    }

    // MARK: Apps

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "More apps by Bruce",
                systemImage: "square.grid.2x2.fill",
                tint: Palette.sky,
                trailing: Text("All free")
            )
            VStack(spacing: 0) {
                ForEach(FounderApp.all) { app in
                    appRow(app)
                    if app.id != FounderApp.all.last?.id {
                        hairline(leadingInset: 14 + appIconSize + 14)
                    }
                }
            }
            .glassSurface(cornerRadius: 24)
        }
    }

    private func appRow(_ app: FounderApp) -> some View {
        Button {
            Haptics.tap()
            openURL(app.url)
        } label: {
            HStack(spacing: 14) {
                appIcon(app.imageName)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                    Text(app.blurb)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                getCapsule
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityHint(Text("Opens the App Store"))
    }

    /// The app's icon in the iOS app-icon shape.
    private func appIcon(_ name: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: appIconSize * 0.22, style: .continuous)
        return Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: appIconSize, height: appIconSize)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            .accessibilityHidden(true)
    }

    private var getCapsule: some View {
        Text("Get")
            .font(.system(.subheadline, design: .rounded).weight(.heavy))
            .foregroundStyle(Palette.sun)
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background(Palette.amber.opacity(0.18), in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.amber.opacity(0.35), lineWidth: 1))
            .accessibilityHidden(true)
    }

    // MARK: Links

    private var linksCard: some View {
        VStack(spacing: 0) {
            linkRow(
                title: "Website",
                detail: "brucesweater.github.io",
                systemImage: "globe",
                tint: Palette.sky,
                url: FounderLinks.website
            )
            hairline(leadingInset: 62)
            linkRow(
                title: "Say hi by email",
                detail: FounderLinks.emailAddress,
                systemImage: "envelope.fill",
                tint: Palette.amber,
                url: FounderLinks.helloEmail
            )
        }
        .glassSurface(cornerRadius: 24)
    }

    private func linkRow(title: LocalizedStringKey, detail: String, systemImage: String, tint: Color, url: URL) -> some View {
        Button {
            Haptics.tap()
            openURL(url)
        } label: {
            HStack(spacing: 14) {
                IconBadge(systemImage: systemImage, tint: tint, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                    Text(verbatim: detail)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
    }

    private func hairline(leadingInset: CGFloat) -> some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: 1)
            .padding(.leading, leadingInset)
    }

    // MARK: Sign-off

    private var signOff: some View {
        Text("Thanks for trying Unhook. — Bruce")
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .foregroundStyle(Brand.dawn)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }
}

/// One of Bruce's other apps on the App Store.
private struct FounderApp: Identifiable {
    let id: String
    let name: String
    let blurb: String
    let imageName: String
    let url: URL

    static let all: [FounderApp] = [
        FounderApp(
            id: "bruce-run",
            name: String(localized: "Bruce Run"),
            blurb: String(localized: "An endless rooftop runner starring me. 20+ cities and worlds, one life."),
            imageName: "AppIconBruceRun",
            url: URL(string: "https://apps.apple.com/app/bruce-run/id6827835863")!
        ),
        FounderApp(
            id: "bruce-speech",
            name: String(localized: "Bruce Speech"),
            blurb: String(localized: "Practice all 12 speech and debate events with real timers and prompts."),
            imageName: "AppIconBruceSpeech",
            url: URL(string: "https://apps.apple.com/app/bruce-speech/id6809584775")!
        ),
        FounderApp(
            id: "pocket-court",
            name: String(localized: "Pocket Court"),
            blurb: String(localized: "Tilt your phone to roll the ball into the goal. Six courts, all made in code."),
            imageName: "AppIconPocketCourt",
            url: URL(string: "https://apps.apple.com/app/pocket-court/id6796332115")!
        ),
    ]
}

#Preview {
    NavigationStack {
        FounderView()
    }
    .previewEnvironment()
}
