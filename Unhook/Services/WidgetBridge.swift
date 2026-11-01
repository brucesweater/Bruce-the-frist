import Foundation
import WidgetKit

/// Keeps the Home Screen and Lock Screen widgets in step with the app.
enum WidgetBridge {
    /// Shares the few settings widgets can't read from the store, then asks WidgetKit to redraw.
    /// Called when the app moves to the background, after the user's changes for the session are saved.
    static func publish() {
        if let defaults = AppModelContainer.sharedDefaults {
            defaults.set(AppSettings.currencyCode, forKey: AppModelContainer.SharedKeys.currencyCode)
            defaults.set(AppLockSettings.isEnabled, forKey: AppModelContainer.SharedKeys.hidesDetails)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
