import SwiftUI
import SwiftData

@main
struct UnhookApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = AppRouter.shared
    @State private var store = Store.shared

    init() {
        NotificationManager.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(store)
                .task { store.start() }
        }
        .modelContainer(AppModelContainer.shared)
        .onChange(of: scenePhase) { _, phase in
            // Expiries and refunds don't always arrive as transaction updates, so re-check on every return.
            if phase == .active {
                Task { await store.refreshEntitlements() }
            }
        }
    }
}
