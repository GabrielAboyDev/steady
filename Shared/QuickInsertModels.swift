import Foundation

/// One tappable quick-insert entry — a name, place, or any word that's hard to
/// spell or tedious to type.
struct QuickInsertEntry: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    /// The exact text inserted on tap. A capital first letter follows the
    /// sentence's own capitalization when inserted; a deliberate lowercase
    /// stays put.
    var text: String
}

/// A user-managed group of entries ("People", "Places").
struct QuickInsertCategory: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var entries: [QuickInsertEntry]
}

extension QuickInsertCategory {

    /// The `{Category}` marker a phrase template uses to draw a blank from
    /// this category. Braces inside the name are dropped so the marker
    /// always closes where it should.
    static func blankMarker(for category: QuickInsertCategory) -> String {
        let name = category.name.filter { $0 != "{" && $0 != "}" }.trimmingCharacters(in: .whitespaces)
        return "{\(name)}"
    }

    /// Demo content for the UI tests and the store captures.
    ///
    /// This is NOT shipped. A fresh install has no names at all — see
    /// `SharedStore.reload()`. It lives here so the screenshots and the tests
    /// have something realistic to drive, nothing more.
    static let demo: [QuickInsertCategory] = [
        QuickInsertCategory(
            name: "People",
            entries: [
                QuickInsertEntry(text: "Mom"),
                QuickInsertEntry(text: "Dad"),
                QuickInsertEntry(text: "Sarah"),
                QuickInsertEntry(text: "Aunt Rosa"),
            ]),
        QuickInsertCategory(
            name: "Care team",
            entries: [
                QuickInsertEntry(text: "Dr. Lee"),
                QuickInsertEntry(text: "Mr. Okafor"),
            ]),
        QuickInsertCategory(
            name: "Places",
            entries: [
                QuickInsertEntry(text: "the clinic"),
                QuickInsertEntry(text: "home"),
                QuickInsertEntry(text: "the day centre"),
            ]),
        QuickInsertCategory(
            name: "Work",
            entries: [
                QuickInsertEntry(text: "the office"),
                QuickInsertEntry(text: "the Monday meeting"),
            ]),
    ]
}
