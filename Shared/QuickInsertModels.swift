import Foundation

/// One tappable quick-insert entry — a name, place, or any word that's hard to
/// spell or tedious to type.
struct QuickInsertEntry: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    /// The exact text inserted on tap.
    var text: String
    /// Optional qualifier shown under the text ("sister", "GP").
    var note: String?
    /// Append a space after inserting.
    var appendsSpace: Bool = true
}

/// A user-managed group of entries ("People", "Places").
struct QuickInsertCategory: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var entries: [QuickInsertEntry]
}

extension QuickInsertCategory {

    /// Seed content matching the Names mock, so the panel is useful before the
    /// user has added anything.
    static let seeded: [QuickInsertCategory] = [
        QuickInsertCategory(name: "People", entries: [
            QuickInsertEntry(text: "Mom"),
            QuickInsertEntry(text: "Dad"),
            QuickInsertEntry(text: "Sarah", note: "sister"),
            QuickInsertEntry(text: "Aunt Rosa")
        ]),
        QuickInsertCategory(name: "Care team", entries: [
            QuickInsertEntry(text: "Dr. Lee", note: "GP"),
            QuickInsertEntry(text: "Mr. Okafor", note: "carer")
        ]),
        QuickInsertCategory(name: "Places", entries: [
            QuickInsertEntry(text: "the clinic"),
            QuickInsertEntry(text: "home"),
            QuickInsertEntry(text: "the day centre")
        ]),
        QuickInsertCategory(name: "Work", entries: [
            QuickInsertEntry(text: "the office"),
            QuickInsertEntry(text: "the Monday meeting")
        ])
    ]
}
