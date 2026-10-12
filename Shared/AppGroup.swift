import Foundation

/// The app group shared by the container app and the keyboard extension.
///
/// Everything the user configures in the app (settings, names, phrases) is
/// written here so the extension can read it. Nothing leaves the device.
enum AppGroup {

    static let identifier = "group.com.gabrielaboy.steady"

    /// True when the app group entitlement is actually present and usable.
    ///
    /// `UserDefaults(suiteName:)` hands back a non-nil instance even when the
    /// entitlement is missing — it just silently stops being shared — so we
    /// probe the container URL instead, which *does* return nil in that case.
    static var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }

    /// Shared defaults when the app group is wired up, falling back to this
    /// process's own defaults so development builds still function.
    static var defaults: UserDefaults {
        if isAvailable, let shared = UserDefaults(suiteName: identifier) {
            return shared
        }
        return .standard
    }
}
