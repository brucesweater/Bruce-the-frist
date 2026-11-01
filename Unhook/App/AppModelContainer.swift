import Foundation
import SwiftData

/// The app's SwiftData store, shared by the UI and App Intents.
enum AppModelContainer {
    static let modelTypes: [any PersistentModel.Type] = [
        Habit.self, Relapse.self, Urge.self, Pledge.self, SavingsGoal.self,
    ]

    static var schema: Schema { Schema(modelTypes) }

    @MainActor static let shared: ModelContainer = make()

    /// True when the on-disk store couldn't be opened and the app is running on a temporary in-memory
    /// store. The Today screen warns the user, because nothing they enter will be kept.
    private(set) static var isUsingTemporaryStore = false

    /// Opens the on-disk store, falling back to memory so the app still launches if the store can't open.
    static func make(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
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
}
