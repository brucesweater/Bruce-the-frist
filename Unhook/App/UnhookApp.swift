import SwiftUI
import SwiftData

@main
struct UnhookApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = AppRouter.shared
    @State private var store = Store.shared
    private let container: ModelContainer

    init() {
        NotificationManager.configure()
        #if DEBUG
        container = UITestSupport.isActive ? UITestSupport.makeContainer() : AppModelContainer.shared
        #else
        container = AppModelContainer.shared
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(store)
                .task { store.start() }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Expiries and refunds don't always arrive as transaction updates, so re-check on every return.
                Task { await store.refreshEntitlements() }
            case .background:
                // Today's changes (a slip, a new habit, the app lock) show up in the widgets right away.
                WidgetBridge.publish()
            default:
                break
            }
        }
    }
}
