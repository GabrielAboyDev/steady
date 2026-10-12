import Combine
import Foundation

/// Everything the container app and the keyboard extension share, persisted as
/// JSON in the app group. Offline only — no accounts, no network, no sync.
final class SharedStore: ObservableObject {

    static let shared = SharedStore()

    private enum Key {
        static let settings = "settings.v1"
        static let categories = "quickInsert.categories.v1"
        static let phrases = "phrases.v1"
        static let keyboardLastRun = "keyboard.lastRun.v1"
    }

    @Published var settings: KeyboardSettings = .default {
        didSet { persist(settings, for: Key.settings) }
    }

    @Published var categories: [QuickInsertCategory] = [] {
        didSet { persist(categories, for: Key.categories) }
    }

    @Published var phrases: [PhraseTemplate] = [] {
        didSet { persist(phrases, for: Key.phrases) }
    }

    /// True when settings are genuinely being shared through the app group
    /// rather than falling back to this process's own defaults.
    var isSharingThroughAppGroup: Bool { AppGroup.isAvailable }

    /// When the keyboard extension last ran. Proves the extension is installed
    /// *and* that the app group round-trips (US-005 / US-006).
    var keyboardLastRun: Date? {
        AppGroup.defaults.object(forKey: Key.keyboardLastRun) as? Date
    }

    /// Suppresses persistence while loading from disk.
    private var isLoading = false

    private init() {
        reload()
    }

    /// Re-read everything from the app group. The app calls this when it comes
    /// back to the foreground; the extension calls it each time it appears, so
    /// a settings change in the app takes effect on the next keyboard use.
    func reload() {
        isLoading = true
        defer { isLoading = false }

        let defaults = AppGroup.defaults
        settings = decode(KeyboardSettings.self, from: defaults.data(forKey: Key.settings)) ?? .default

        let storedCategories = decode([QuickInsertCategory].self, from: defaults.data(forKey: Key.categories))
        categories = storedCategories ?? QuickInsertCategory.seeded

        let storedPhrases = decode([PhraseTemplate].self, from: defaults.data(forKey: Key.phrases))
        phrases = storedPhrases ?? PhraseTemplate.seeded

        // First launch: write the seeds through so the extension sees them too.
        if storedCategories == nil { persist(categories, for: Key.categories) }
        if storedPhrases == nil { persist(phrases, for: Key.phrases) }
    }

    /// Called by the extension so the app can tell the keyboard has been used.
    func noteKeyboardDidRun() {
        AppGroup.defaults.set(Date(), forKey: Key.keyboardLastRun)
    }

    /// Every quick-insert entry's text, used to fill `{name}` phrase slots.
    var allQuickInsertTexts: [String] {
        categories.flatMap { $0.entries.map(\.text) }
    }

    /// Wipe stored state back to the shipped seeds. Used by UI tests.
    func resetToSeeds() {
        let defaults = AppGroup.defaults
        for key in [Key.settings, Key.categories, Key.phrases, Key.keyboardLastRun] {
            defaults.removeObject(forKey: key)
        }
        reload()
    }

    // MARK: Persistence

    private func persist<T: Encodable>(_ value: T, for key: String) {
        guard !isLoading else { return }
        guard let data = try? JSONEncoder().encode(value) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
