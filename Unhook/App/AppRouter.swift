import Observation
import SwiftUI
import UIKit

/// App-wide navigation state: the selected tab and the screens any part of the app (or a Siri Shortcut)
/// can ask to present. Injected into the environment by `UnhookApp`.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum Tab: Hashable {
        case today, progress, settings
    }

    var selectedTab: Tab = .today
    /// Shows the SOS breathing screen over everything.
    var isShowingSOS = false
    /// Shows the Unhook Pro paywall.
    var paywallReason: PaywallReason?
    /// Shows a full-screen milestone celebration.
    var celebration: MilestoneCelebration?
    /// Shows the 30-Day Reset challenge (presented by `RootView`).
    var isShowingChallenge = false
    /// A challenge link (unhook://challenge/…) that arrived before onboarding finished; opened once it does.
    var pendingChallenge = false

    func showPaywall(_ reason: PaywallReason) {
        guard Monetization.isProEnabled else { return }
        paywallReason = reason
    }

    /// Opens the 30-Day Reset from anywhere (the Today card, a link). A sheet that's already open would block it,
    /// so that closes first. SOS always stays on top, so nothing happens while it's showing.
    func showChallenge() {
        guard !isShowingSOS, !isShowingChallenge else { return }
        if Self.dismissPresentedScreens() {
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                guard !self.isShowingSOS else { return }
                self.isShowingChallenge = true
            }
        } else {
            isShowingChallenge = true
        }
    }

    /// Shows SOS from anywhere (Siri, the Action button, a widget). A sheet that's already open would block
    /// the SOS screen from presenting, so close it first: crisis help must never silently fail to appear.
    func requestSOS() async {
        guard !isShowingSOS else { return }
        paywallReason = nil
        isShowingChallenge = false
        if Self.dismissPresentedScreens() {
            try? await Task.sleep(for: .milliseconds(450))
        }
        isShowingSOS = true
    }

    /// Dismisses every sheet or cover presented in the app's windows. Returns true if anything was open.
    private static func dismissPresentedScreens() -> Bool {
        var dismissed = false
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                guard let root = window.rootViewController, root.presentedViewController != nil else { continue }
                root.dismiss(animated: false)
                dismissed = true
            }
        }
        return dismissed
    }
}

/// A milestone reached since the user last opened the app.
struct MilestoneCelebration: Identifiable {
    let habit: Habit
    let milestone: Milestone
    /// Captured up front so reading it never touches a habit that has since been deleted.
    let id: String

    init(habit: Habit, milestone: Milestone) {
        self.habit = habit
        self.milestone = milestone
        self.id = "\(habit.uuid.uuidString)-\(milestone.id)"
    }

    /// False once the habit is deleted, or a slip (or an edited quit date) means the streak no longer
    /// covers the milestone. A celebration queued under a sheet is checked again before it shows.
    @MainActor var isStillValid: Bool {
        guard !habit.isDeleted, habit.modelContext != nil else { return false }
        return habit.stats().currentStreak >= milestone.seconds
    }
}
