import Foundation
import UIKit

/// Works out whether the user has actually enabled the keyboard yet, so
/// onboarding can tell them what's left to do (US-005).
enum KeyboardInstallState {

    static let extensionBundleIdentifier = "com.gabrielaboy.steady.keyboard"

    /// The system's list of enabled keyboards, which is readable from inside
    /// our own sandbox. Returns nil when the list isn't available at all.
    private static var enabledKeyboardIdentifiers: [String]? {
        UserDefaults.standard.object(forKey: "AppleKeyboards") as? [String]
    }

    /// True when our extension appears in the enabled-keyboards list.
    static var isEnabledInSettings: Bool {
        guard let identifiers = enabledKeyboardIdentifiers else { return false }
        return identifiers.contains { $0.contains(extensionBundleIdentifier) }
    }

    /// True once the extension has run at least once — it writes a timestamp
    /// into the app group on appear, which also proves the group is wired up.
    static var hasKeyboardRun: Bool {
        SharedStore.shared.keyboardLastRun != nil
    }

    /// Either signal is good enough to call it enabled.
    static var isEnabled: Bool {
        isEnabledInSettings || hasKeyboardRun
    }

    /// Opens this app's page in iOS Settings — the only destination apps are
    /// allowed to deep-link to. Keyboards live one level in, under Keyboards.
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
