import SwiftUI

/// Unhook's privacy policy in plain words. Push it inside a `NavigationStack`, or present
/// `PrivacyPolicySheet` when there isn't one.
///
/// Keep it in step with the policy on the web (`FounderLinks.privacyPolicy`) and the App Privacy answers.
struct PrivacyPolicyView: View {
    private static let applePrivacyURL = URL(string: "https://www.apple.com/legal/privacy/")!

    /// When this version of the policy took effect.
    private static let effectiveDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 9
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                shortVersion
                Group {
                    onDeviceCard
                    widgetsCard
                    coachCard
                    notificationsCard
                    lockCard
                    sharingCard
                    linksCard
                }
                Group {
                    doesNotDoCard
                    childrenCard
                    deletingCard
                    healthCard
                    appleCard
                    changesCard
                    contactCard
                }
            }
            .padding(20)
            .padding(.bottom, 12)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .dawnScreenBackground(glow: 0.3)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .fadesContentUnderNavigationBar()
    }

    // MARK: Summary

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            IconBadge(systemImage: "lock.shield.fill", tint: Palette.mint, size: 52)
                .shadow(color: Palette.mint.opacity(0.35), radius: 14)
            Text("Your privacy, in plain words")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Chip(
                text: Text("Effective \(Self.effectiveDate, format: Date.FormatStyle(date: .long, time: .omitted))"),
                tint: Palette.amber
            )
            Text("Unhook is an app for quitting bad habits, made by Bruce Gao. This policy explains what the app keeps, what it sends over the internet, and how to delete your data.")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 4)
    }

    private var shortVersion: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The short version")
                .microLabel(Palette.sun)
            Text("No account, no ads, no analytics, no tracking, no in-app purchases, and nothing you enter ever leaves your iPhone.")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassSurface(cornerRadius: 24, tint: Palette.amber, highlighted: true)
        .accessibilityElement(children: .combine)
    }

    // MARK: What the app keeps

    private var onDeviceCard: some View {
        Card(title: "What stays on your device", systemImage: "iphone", tint: Palette.mint) {
            Text("Everything you add to Unhook is saved only on your own iPhone: the habits you're quitting, your quit dates and streaks, slips and their notes, the cravings you beat (with what set them off and how strong they were), daily pledges and moods, savings goals, challenges, missions, achievements and your settings. Unhook has no server. None of it is sent to me or to anyone else.")
                .policyBody()
        }
    }

    private var widgetsCard: some View {
        Card(title: "Widgets and Siri", systemImage: "square.grid.2x2.fill", tint: Palette.sky) {
            Text("Unhook's widgets and Siri shortcuts read the same data on your iPhone, from a storage area shared only between Unhook and its widgets. If you turn on the app lock, widgets and notifications leave out what you're quitting.")
                .policyBody()
        }
    }

    private var coachCard: some View {
        Card(title: "The craving coach", systemImage: "bubble.left.and.bubble.right.fill", tint: Palette.violet) {
            Text("On iPhones with Apple Intelligence, the coach uses Apple's on-device language model. On other iPhones it uses replies built into the app. Either way, your messages are handled on your iPhone, are never sent anywhere, and are not saved: the conversation is gone when you close the coach. The coach is automated, not a person.")
                .policyBody()
        }
    }

    private var notificationsCard: some View {
        Card(title: "Notifications", systemImage: "bell.badge.fill", tint: Palette.amber) {
            Text("Reminders and milestone alerts are scheduled on your iPhone by the app itself. No push notification service is used, and Unhook never sends marketing.")
                .policyBody()
        }
    }

    private var lockCard: some View {
        Card(title: "Face ID and passcode lock", systemImage: "faceid", tint: Palette.mint) {
            Text("If you turn on the app lock, iOS checks your Face ID, Touch ID or passcode and only tells Unhook whether it worked. Unhook never sees your face data, fingerprint or passcode.")
                .policyBody()
        }
    }

    private var sharingCard: some View {
        Card(title: "Sharing and exporting", systemImage: "square.and.arrow.up", tint: Palette.sky) {
            Text("When you share a progress card or export your data (as JSON or CSV), Unhook hands the file to the iOS share sheet, and you choose where it goes. The app itself doesn't send it anywhere.")
                .policyBody()
        }
    }

    private var linksCard: some View {
        Card(title: "Links", systemImage: "arrow.up.right.square.fill", tint: Palette.ember) {
            Text("Unhook links to findahelpline.com (free helplines near you) and to its support and privacy pages, and its founder page links to my Instagram, my website and my other apps on the App Store. These open outside the app, and their own privacy policies apply.")
                .policyBody()
        }
    }

    // MARK: What it doesn't do

    private var doesNotDoCard: some View {
        Card(title: "What Unhook does not do", systemImage: "hand.raised.fill", tint: Palette.rose) {
            VStack(alignment: .leading, spacing: 10) {
                PolicyBullet(text: "No account or sign-up", systemImage: "nosign", tint: Palette.rose)
                PolicyBullet(text: "No ads", systemImage: "nosign", tint: Palette.rose)
                PolicyBullet(text: "No analytics, no tracking, and no third-party code (SDKs)", systemImage: "nosign", tint: Palette.rose)
                PolicyBullet(text: "No in-app purchases: Unhook is free", systemImage: "nosign", tint: Palette.rose)
                PolicyBullet(text: "No access to your camera, microphone, photo library, contacts, location or health data", systemImage: "nosign", tint: Palette.rose)
                PolicyBullet(text: "No selling or sharing of data with anyone", systemImage: "nosign", tint: Palette.rose)
            }
        }
    }

    private var childrenCard: some View {
        Card(title: "Children", systemImage: "person.2.fill", tint: Palette.sky) {
            Text("Unhook is a self-help app for teens and adults. It isn't made for children and isn't in the App Store's Kids category. It collects nothing from anyone.")
                .policyBody()
        }
    }

    private var deletingCard: some View {
        Card(title: "Keeping and deleting your data", systemImage: "trash.fill", tint: Palette.rose) {
            VStack(alignment: .leading, spacing: 10) {
                PolicyBullet(
                    text: "Your data stays on your iPhone until you delete it. Settings > Erase all data deletes everything at once, and deleting the app deletes it too.",
                    systemImage: "iphone",
                    tint: Palette.mint
                )
                PolicyBullet(
                    text: "Backups of your iPhone to iCloud or a computer are handled by Apple, under Apple's privacy policy.",
                    systemImage: "icloud.fill",
                    tint: Palette.sky
                )
                Text("Because I never receive your data, I can't see, change or delete it for you, but I'm happy to answer any question about it.")
                    .policyBody()
            }
        }
    }

    // MARK: Health, Apple and contact

    private var healthCard: some View {
        Card(title: "Health", systemImage: "heart.text.square.fill", tint: Palette.rose) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Unhook is a self-help tool. It is not medical advice and not a substitute for professional care. If you are in crisis, call your local emergency number or find a free, confidential helpline at findahelpline.com.")
                    .policyBody()
                Link(destination: FounderLinks.helplines) {
                    Label("Find a free helpline", systemImage: "lifepreserver.fill")
                }
                .policyLink()
            }
        }
    }

    private var appleCard: some View {
        Card(title: "Apple", systemImage: "apps.iphone", tint: Palette.violet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Apple Intelligence, widgets, Siri and Face ID are run by iOS. How Apple handles data is covered by Apple's privacy policy.")
                    .policyBody()
                Link(destination: Self.applePrivacyURL) {
                    Label("Apple's privacy policy", systemImage: "arrow.up.right.square")
                }
                .policyLink()
            }
        }
    }

    private var changesCard: some View {
        Card(title: "Changes to this policy", systemImage: "arrow.triangle.2.circlepath", tint: Palette.sky) {
            Text("If this policy changes, the new version will be posted here and on the web, with a new effective date.")
                .policyBody()
        }
    }

    private var contactCard: some View {
        Card(title: "Contact", systemImage: "envelope.fill", tint: Palette.amber) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Questions about this policy? Email me. I'm happy to help.")
                    .policyBody()
                Link(destination: FounderLinks.supportEmail) {
                    Label {
                        Text(verbatim: FounderLinks.emailAddress)
                    } icon: {
                        Image(systemName: "envelope")
                    }
                }
                .policyLink()
                Link(destination: FounderLinks.privacyPolicy) {
                    Label("Read this policy on the web", systemImage: "globe")
                }
                .policyLink()
            }
        }
    }
}

/// One line of a policy list, with a small leading symbol.
private struct PolicyBullet: View {
    let text: LocalizedStringKey
    let systemImage: String
    var tint: Color = Palette.textTertiary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.bold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .policyBody()
        }
        .accessibilityElement(children: .combine)
    }
}

/// `PrivacyPolicyView` in its own navigation stack with a Done button, for presenting as a sheet.
struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PrivacyPolicyView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

private extension View {
    /// Body text inside a policy card.
    func policyBody() -> some View {
        font(.subheadline)
            .foregroundStyle(Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A link inside a policy card.
    func policyLink() -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.amber)
    }
}

#Preview {
    PrivacyPolicySheet()
        .previewEnvironment()
}
