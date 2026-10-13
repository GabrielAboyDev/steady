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

        // Empty on a fresh install. The app ships with no names and no phrases
        // of its own: what someone says, and who they say it to, is theirs to
        // write. Both panels already explain how to add the first one.
        categories = decode([QuickInsertCategory].self, from: defaults.data(forKey: Key.categories)) ?? []
        phrases = decode([PhraseTemplate].self, from: defaults.data(forKey: Key.phrases)) ?? []
    }

    /// Called by the extension so the app can tell the keyboard has been used.
    func noteKeyboardDidRun() {
        AppGroup.defaults.set(Date(), forKey: Key.keyboardLastRun)
    }

    /// Every quick-insert entry across the categories, in Names-panel order.
    /// The phrase fill flow offers exactly these for a `{name}` blank.
    var allQuickInsertEntries: [QuickInsertEntry] {
        categories.flatMap(\.entries)
    }

    /// Just the texts, for the phrase editor's "these names will be offered" hint.
    var allQuickInsertTexts: [String] {
        allQuickInsertEntries.map(\.text)
    }

    /// Wipe stored state back to the shipped seeds. Used by UI tests.
    /// Wipe the app group and install the demo names and phrases.
    ///
    /// Only the UI tests and the store captures call this, through the
    /// `-UITestResetState` launch argument. Nothing here reaches a shipping
    /// install — a real one starts empty.
    func resetToDemoContent() {
        let defaults = AppGroup.defaults
        for key in [Key.settings, Key.categories, Key.phrases, Key.keyboardLastRun] {
            defaults.removeObject(forKey: key)
        }
        reload()
        categories = QuickInsertCategory.demo
        phrases = PhraseTemplate.demo
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
