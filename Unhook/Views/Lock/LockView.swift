import SwiftUI
import UIKit

/// Full-screen lock shown while Face ID (or the passcode) protects Unhook: a calm dawn orb on the night sky.
struct LockView: View {
    let isAuthenticating: Bool
    let errorMessage: String?
    let onUnlock: () -> Void

    @State private var method = AppLockSettings.currentMethod()

    private static let helplineURL = URL(string: "https://findahelpline.com")!

    init(isAuthenticating: Bool = false, errorMessage: String? = nil, onUnlock: @escaping () -> Void) {
        self.isAuthenticating = isAuthenticating
        self.errorMessage = errorMessage
        self.onUnlock = onUnlock
    }

    var body: some View {
        ZStack {
            DawnBackground(glow: 0.14)

            VStack(spacing: 0) {
                Spacer(minLength: 24)
                AppLockEmblem()
                header
                    .padding(.top, 18)
                Spacer(minLength: 24)
                footer
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: 480)
        }
        .environment(\.colorScheme, .dark)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .animation(.easeInOut(duration: 0.2), value: isAuthenticating)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("Unhook is locked")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Your progress stays private. Unlock with \(method.inlineName) to continue.")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        VStack(spacing: 16) {
            if let errorMessage {
                Label {
                    Text(errorMessage)
                } icon: {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Palette.rose)
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassSurface(cornerRadius: 16, tint: Palette.rose)
                .transition(.opacity)
            }

            Button(action: onUnlock) {
                ZStack {
                    Label("Unlock", systemImage: method.systemImage)
                        .opacity(isAuthenticating ? 0 : 1)
                    if isAuthenticating {
                        ProgressView()
                            .tint(Palette.inkText)
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isAuthenticating)

            // Crisis help never sits behind the lock: it reveals nothing about the user's data.
            Link(destination: Self.helplineURL) {
                Label("Need help right now? Find a helpline", systemImage: "lifepreserver.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}

/// Covers the app while it's in the app switcher or briefly inactive, so its snapshot never shows the user's data.
/// Same night sky and orb as the lock screen, held still.
struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            DawnBackground(glow: 0.14)
            VStack(spacing: 16) {
                AppLockEmblem(animated: false)
                Text("Unhook")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.textPrimary)
            }
        }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Unhook")
    }
}

/// What covers the app while the lock is on: the lock screen when locked, otherwise the privacy shield.
struct AppLockCover: View {
    let lock: AppLock

    var body: some View {
        if lock.isLocked {
            LockView(isAuthenticating: lock.isAuthenticating, errorMessage: lock.errorMessage) {
                Task { await lock.unlock() }
            }
        } else {
            PrivacyShieldView()
        }
    }
}

/// The lock screen's centerpiece: a calm dawn orb with a lock resting on it. Breathes gently unless
/// `animated` is false or Reduce Motion is on.
struct AppLockEmblem: View {
    let animated: Bool

    @ScaledMetric(relativeTo: .largeTitle) private var scaledSize: CGFloat = 128

    init(animated: Bool = true) {
        self.animated = animated
    }

    private var size: CGFloat { min(scaledSize, 180) }

    var body: some View {
        ZStack {
            DawnOrb(progress: 0.32, size: size, animated: animated)
            Image(systemName: "lock.fill")
                .font(.system(size: size * 0.26, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Locked") {
    LockView {}
        .previewEnvironment()
}

#Preview("Failed") {
    LockView(errorMessage: "Unhook couldn't confirm it's you. Please try again.") {}
        .previewEnvironment()
}

#Preview("Shield") {
    PrivacyShieldView()
        .previewEnvironment()
}
