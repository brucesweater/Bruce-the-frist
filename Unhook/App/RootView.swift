import StoreKit
import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage(AppSettings.Keys.hasOnboarded) private var hasOnboarded = false
    /// Bumped when the user erases their data so every navigation stack starts fresh.
    @AppStorage(AppSettings.Keys.dataResetCount) private var dataResetCount = 0
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query private var habits: [Habit]

    var body: some View {
        @Bindable var router = router
        ZStack {
            if hasOnboarded {
                AppLockContainer {
                    MainTabView()
                }
                .id(dataResetCount)
                .transition(.opacity)
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.4)) { hasOnboarded = true }
                }
                .transition(.opacity)
            }
        }
        // At the root so SOS works from Siri or the Action button even before onboarding is finished.
        .fullScreenCover(isPresented: $router.isShowingSOS) {
            SOSView(habit: nil)
        }
        // The 30-Day Reset, opened from the Today card or a link (unhook://challenge/reset30).
        .sheet(isPresented: $router.isShowingChallenge) {
            ChallengeView()
        }
        .task {
            // Onboarding saves the first habit just before its paywall. If the app was closed there,
            // don't run onboarding again (and create a duplicate habit) on the next launch.
            if !hasOnboarded && !habits.isEmpty {
                hasOnboarded = true
            }
        }
        // "Erase all data" in Settings bumps the reset count: clear the engagement records too
        // (mission check-offs, challenge runs, remembered achievements and rank).
        .onChange(of: dataResetCount) {
            EngagementData.eraseAll(in: context)
        }
        .onChange(of: hasOnboarded) { _, done in
            guard done, router.pendingChallenge else { return }
            router.pendingChallenge = false
            Task {
                // Let the onboarding cross-fade finish before the sheet slides up.
                try? await Task.sleep(for: .milliseconds(600))
                router.showChallenge()
            }
        }
        // Widget and notification links: unhook://sos opens SOS, unhook://challenge/reset30 opens the
        // 30-Day Reset, anything else goes to Today.
        .onOpenURL { url in
            guard url.scheme == "unhook" else { return }
            switch url.host ?? "" {
            case "sos":
                Task { await router.requestSOS() }
            case "challenge":
                router.selectedTab = .today
                if hasOnboarded {
                    router.showChallenge()
                } else {
                    // Someone who installs from the event page lands in onboarding first: open the challenge after.
                    router.pendingChallenge = true
                }
            default:
                router.selectedTab = .today
            }
        }
    }
}

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @Environment(AppRouter.self) private var router
    @Query private var habits: [Habit]
    @Query private var challengeRuns: [ChallengeProgress]

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(AppRouter.Tab.today)
            InsightsView()
                .tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }
                .tag(AppRouter.Tab.progress)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppRouter.Tab.settings)
        }
        .sheet(item: $router.paywallReason) { reason in
            PaywallView(reason: reason)
        }
        // An overlay rather than a full-screen cover: if a sheet is open when a milestone unlocks, the
        // celebration simply waits underneath instead of failing to present and getting stuck.
        .overlay {
            if let celebration = router.celebration, celebration.isStillValid {
                MilestoneCelebrationView(celebration: celebration) {
                    router.celebration = nil
                    requestReviewIfAppropriate()
                }
                .transition(.opacity)
                .zIndex(1)
                .accessibilityAddTraits(.isModal)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: router.celebration?.id)
        // Rank-up moments; they wait while SOS or a milestone celebration is showing.
        .overlay {
            RankUpObserver()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            // Only the next few milestone alerts are scheduled at a time, so top them up whenever the app opens.
            for habit in habits {
                NotificationManager.scheduleMilestones(for: habit)
            }
            // The daily reminder mentions the 30-Day Reset only while one is running.
            NotificationManager.setChallengeActive(ResetChallenge.activeRun(in: challengeRuns) != nil)
            presentPendingCelebration()
        }
        #if DEBUG
        .task {
            UITestSupport.applyInitialScreen(router: router, habits: habits)
        }
        #endif
        .task {
            // Catch milestones that unlock while the app is open (the first hour, for example).
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if scenePhase == .active && router.selectedTab == .today {
                    presentPendingCelebration()
                }
            }
        }
    }

    private func presentPendingCelebration() {
        if let queued = router.celebration, !queued.isStillValid {
            router.celebration = nil
        }
        guard router.celebration == nil, !router.isShowingSOS, router.paywallReason == nil else { return }
        guard let celebration = CelebrationCenter.pendingCelebration(for: habits) else { return }
        CelebrationCenter.markCelebrated(celebration)
        ReviewPrompter.standard.recordPositiveMoment()
        router.celebration = celebration
    }

    /// Asks for an App Store rating right after a high point, at most a few times a year.
    private func requestReviewIfAppropriate() {
        let prompter = ReviewPrompter.standard
        guard prompter.shouldRequestReview() else { return }
        prompter.markRequested()
        requestReview()
    }
}

#Preview {
    MainTabView()
        .previewEnvironment()
}
