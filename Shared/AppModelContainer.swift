import Foundation
import SwiftData

/// The app's SwiftData store, shared by the UI, App Intents and the widget extension.
enum AppModelContainer {
    static let modelTypes: [any PersistentModel.Type] = [
        Habit.self, Relapse.self, Urge.self, Pledge.self, SavingsGoal.self,
    ]

    static var schema: Schema { Schema(modelTypes) }

    @MainActor static let shared: ModelContainer = make()

    /// True when the on-disk store couldn't be opened and the app is running on a temporary in-memory
    /// store. The Today screen warns the user, because nothing they enter will be kept.
    private(set) static var isUsingTemporaryStore = false

    /// "group.<app bundle ID>", shared by the app and its widget extension ("<app bundle ID>.widgets").
    static var appGroupID: String? {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let widgetSuffix = ".widgets"
        let appBundleID = bundleID.hasSuffix(widgetSuffix) ? String(bundleID.dropLast(widgetSuffix.count)) : bundleID
        return "group.\(appBundleID)"
    }

    /// The App Group container, or nil when this build has no App Group entitlement. Debug builds for a
    /// device leave it out so a free Apple ID can still run the app; widgets then show a placeholder.
    static var groupContainerURL: URL? {
        guard let id = appGroupID else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    /// Small values the widget needs and can't read from the store (currency, privacy), written by the app.
    static var sharedDefaults: UserDefaults? {
        guard groupContainerURL != nil, let id = appGroupID else { return nil }
        return UserDefaults(suiteName: id)
    }

    enum SharedKeys {
        static let currencyCode = "widget.currencyCode"
        /// Mirrors the app lock: widgets then leave out what the user is quitting.
        static let hidesDetails = "widget.hidesDetails"
    }

    /// Opens the on-disk store, falling back to memory so the app still launches if the store can't open.
    static func make(inMemory: Bool = false) -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let storeURL = sharedStoreURL {
            migrateLegacyStoreIfNeeded(to: storeURL)
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .none)
        }

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            assertionFailure("Could not open the Unhook store: \(error)")
            if !inMemory {
                isUsingTemporaryStore = true
            }
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // An in-memory store with a known-good schema can only fail on programmer error.
            return try! ModelContainer(for: schema, configurations: fallback)
        }
    }

    /// The store inside the App Group container, at the path SwiftData itself would pick for a group store.
    private static var sharedStoreURL: URL? {
        guard let container = groupContainerURL else { return nil }
        let directory = container.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "default.store")
    }

    /// Builds made before the App Group existed kept the store in the app's own container. Copy it into the
    /// shared container the first time, so turning on widgets never hides anyone's progress.
    private static func migrateLegacyStoreIfNeeded(to sharedURL: URL) {
        let fileManager = FileManager.default
        guard let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let legacyURL = applicationSupport.appending(path: "default.store")
        guard legacyURL.standardizedFileURL != sharedURL.standardizedFileURL,
              fileManager.fileExists(atPath: legacyURL.path),
              !fileManager.fileExists(atPath: sharedURL.path)
        else { return }

        // SQLite keeps recent writes in the -wal file, so copy all three parts together.
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: legacyURL.path + suffix)
            let destination = URL(fileURLWithPath: sharedURL.path + suffix)
            if fileManager.fileExists(atPath: source.path) {
                try? fileManager.copyItem(at: source, to: destination)
            }
        }
    }
}
