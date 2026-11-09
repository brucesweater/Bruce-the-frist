import SwiftUI

/// Invisible until the user's rank rises, then shows a short rank-up celebration. The first time it sees the rank it
/// only remembers it, so nobody gets a surprise "Level 7" on updating. Waits while SOS or a milestone celebration
/// is on screen. Put it in an overlay above the tabs.
struct RankUpObserver: View {
    init() {}

    var body: some View {
        XPSummaryReader { summary in
            RankUpPresenter(summary: summary)
        }
    }
}

private struct RankUpPresenter: View {
    let summary: XPSummary

    @Environment(AppRouter.self) private var router
    @AppStorage(EngagementKeys.lastSeenRankLevel) private var lastSeenRankLevel = 0
    @State private var risenTo: Rank?
    #if DEBUG
    @State private var didApplyUITestScreen = false
    #endif

    private var canShow: Bool {
        !router.isShowingSOS && router.celebration == nil
    }

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .overlay {
                if let rank = risenTo, canShow {
                    RankUpCelebrationView(rank: rank, onDone: acknowledge)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: risenTo?.level)
            .animation(.easeInOut(duration: 0.35), value: canShow)
            .onAppear(perform: evaluate)
            .onChange(of: summary.rank.level) {
                evaluate()
            }
            .onChange(of: lastSeenRankLevel) {
                evaluate()
            }
    }

    private func evaluate() {
        let level = summary.rank.level
        #if DEBUG
        if UITestSupport.isActive {
            // Screenshots stay clean unless the rank-up screen itself was asked for.
            if UITestSupport.initialScreen == "rankup" && !didApplyUITestScreen {
                didApplyUITestScreen = true
                risenTo = summary.rank
            }
            return
        }
        #endif
        guard lastSeenRankLevel > 0 else {
            lastSeenRankLevel = level
            return
        }
        if level > lastSeenRankLevel && (risenTo?.level ?? 0) < level {
            risenTo = summary.rank
        }
    }

    private func acknowledge() {
        if let rank = risenTo {
            lastSeenRankLevel = max(lastSeenRankLevel, rank.level)
        }
        risenTo = nil
    }
}

private struct RankUpCelebrationView: View {
    let rank: Rank
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var spinning = false

    var body: some View {
        ZStack {
            DawnBackground(glow: 0.45 + 0.55 * rank.skyProgress)
            VStack(spacing: 28) {
                Spacer(minLength: 0)
                medallion
                headline
                Spacer(minLength: 0)
                Button {
                    Haptics.tap()
                    onDone()
                } label: {
                    Text("Keep going")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 520)
            if !reduceMotion {
                ConfettiView()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            Haptics.success()
            withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.55).delay(0.1)) {
                appeared = true
            }
            if !reduceMotion {
                withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) {
                    spinning = true
                }
            }
        }
    }

    private var medallion: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(
                    colors: [
                        Palette.sun.opacity(0), Palette.sun.opacity(0.35), Palette.sun.opacity(0),
                        Palette.amber.opacity(0.3), Palette.sun.opacity(0), Palette.ember.opacity(0.25), Palette.sun.opacity(0),
                    ],
                    center: .center
                ))
                .frame(width: 320, height: 320)
                .mask {
                    RadialGradient(colors: [.black, .clear], center: .center, startRadius: 50, endRadius: 160)
                }
                .rotationEffect(.degrees(spinning ? 360 : 0))
            RankMedallion(rank: rank, size: 150)
        }
        .frame(height: 260)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.4)
        .opacity(appeared || reduceMotion ? 1 : 0)
        .accessibilityHidden(true)
    }

    private var headline: some View {
        VStack(spacing: 12) {
            Text("Rank up!")
                .font(.display(44, weight: .heavy))
                .foregroundStyle(Brand.dawn)
            Text("Level \(rank.level) · \(rank.title)")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text(rank.encouragement)
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(appeared || reduceMotion ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 16)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    RankUpCelebrationView(rank: Rank.all[4]) {}
}
