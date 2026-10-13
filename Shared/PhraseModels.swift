import Foundation

/// One named variable inside a phrase template, e.g. the `{minutes}` in
/// "I'm running {minutes} late".
struct PhraseSlot: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    /// The slot name as written between the braces.
    var name: String
    /// The large-chip options offered for this slot.
    var options: [String] = []
    /// When true the options come from the user's Names list instead of
    /// `options` — this is what makes `{name}` work (US-008 feeds US-009).
    var drawsFromNames: Bool = false
    /// Allow typing a value instead of picking one.
    var allowsFreeText: Bool = false
    /// A slot the user may skip. Required slots gate insertion.
    var isRequired: Bool = true
}

/// A reusable sentence with `{slot}` variables the user fills at send time.
struct PhraseTemplate: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    /// Short label shown in the phrase picker.
    var title: String
    /// The sentence itself, with `{slot}` markers.
    var template: String
    /// Per-slot configuration, in the order the slots appear.
    var slots: [PhraseSlot] = []

    /// Slot names in the order they appear in `template`.
    static func slotNames(in template: String) -> [String] {
        let pattern = try? NSRegularExpression(pattern: "\\{([^{}]+)\\}")
        guard let pattern else { return [] }
        let range = NSRange(template.startIndex..., in: template)
        var names: [String] = []
        for match in pattern.matches(in: template, range: range) {
            guard let nameRange = Range(match.range(at: 1), in: template) else { continue }
            let name = String(template[nameRange]).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { names.append(name) }
        }
        return names
    }

    /// The slots actually present in the template text, in order, carrying over
    /// any stored configuration for slots whose names still match. Keeps option
    /// lists intact when the user edits the surrounding words.
    var resolvedSlots: [PhraseSlot] {
        PhraseTemplate.slotNames(in: template).map { name in
            if let existing = slots.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                return existing
            }
            // An unconfigured {name} slot still draws from the Names list.
            return PhraseSlot(name: name, drawsFromNames: name.caseInsensitiveCompare("name") == .orderedSame)
        }
    }

    /// The finished sentence with every provided value substituted in. Slots
    /// without a value keep their `{slot}` marker.
    func assembled(with values: [String: String]) -> String {
        var output = template
        for slot in resolvedSlots {
            guard let value = values[slot.name], !value.isEmpty else { continue }
            output = output.replacingOccurrences(of: "{\(slot.name)}", with: value)
        }
        return output
    }
}

extension PhraseTemplate {

    /// Demo content for the UI tests and the store captures.
    ///
    /// Not shipped: a fresh install has no phrases. See `SharedStore.reload()`.
    static let demo: [PhraseTemplate] = [
        PhraseTemplate(
            title: "Running late",
            template: "Hi {name}, I'm running {minutes} late for {place}.",
            slots: [
                PhraseSlot(name: "name", drawsFromNames: true),
                PhraseSlot(name: "minutes", options: ["5", "10", "15", "20", "30"], allowsFreeText: true),
                PhraseSlot(name: "place", options: ["the clinic", "the office", "our meeting", "dinner"]),
            ]
        ),
        PhraseTemplate(
            title: "Need a hand",
            template: "{name}, could you help me with {task} when you get a chance?",
            slots: [
                PhraseSlot(name: "name", drawsFromNames: true),
                PhraseSlot(
                    name: "task", options: ["breakfast", "getting dressed", "my chair", "the phone"],
                    allowsFreeText: true),
            ]
        ),
        PhraseTemplate(
            title: "Check in",
            template: "Thanks {name} — I'm feeling {feeling} today.",
            slots: [
                PhraseSlot(name: "name", drawsFromNames: true),
                PhraseSlot(name: "feeling", options: ["good", "tired", "much better", "about the same"]),
            ]
        ),
    ]
}

/// One piece of a phrase being filled in, for rendering the live preview.
struct PhraseSegment: Identifiable {
    enum Kind: Equatable {
        case literal
        /// A slot the user has already answered.
        case filled
        /// The slot being asked about right now.
        case current
        /// A slot still to come.
        case pending
    }

    let id = UUID()
    let text: String
    let kind: Kind
}

/// Walks the user through a phrase's slots one at a time, as the mock's
/// "Blank 2 of 3" flow does, and assembles the sentence at the end.
final class PhraseFillSession: ObservableObject {

    let template: PhraseTemplate
    /// Options for any slot that draws from the Names list.
    private let nameOptions: [String]

    @Published private(set) var values: [String: String] = [:]
    @Published private(set) var index: Int = 0

    private let slots: [PhraseSlot]

    init(template: PhraseTemplate, nameOptions: [String]) {
        self.template = template
        self.nameOptions = nameOptions
        self.slots = template.resolvedSlots
    }

    var currentSlot: PhraseSlot? {
        index < slots.count ? slots[index] : nil
    }

    /// The chips to offer for the current slot.
    var currentOptions: [String] {
        guard let slot = currentSlot else { return [] }
        return slot.drawsFromNames ? nameOptions : slot.options
    }

    /// "Blank 2 of 3", matching the mock's progress indicator.
    var progressLabel: String {
        guard !slots.isEmpty else { return "" }
        return "Blank \(min(index + 1, slots.count)) of \(slots.count)"
    }

    var isComplete: Bool {
        slots.allSatisfy { slot in
            !slot.isRequired || !(values[slot.name] ?? "").isEmpty
        }
    }

    var canGoBack: Bool { index > 0 }

    var assembledText: String { template.assembled(with: values) }

    /// Fill the current slot and advance.
    func select(_ value: String) {
        guard let slot = currentSlot else { return }
        values[slot.name] = value
        index = min(index + 1, slots.count)
    }

    /// Step back to the previous slot, clearing its value so it can be redone.
    func back() {
        guard canGoBack else { return }
        index -= 1
        values[slots[index].name] = nil
    }

    /// The sentence split for display, with each slot marked by its state.
    var segments: [PhraseSegment] {
        var result: [PhraseSegment] = []
        var remainder = Substring(template.template)
        var slotPosition = 0

        while let open = remainder.firstIndex(of: "{"),
            let close = remainder[open...].firstIndex(of: "}")
        {

            let literal = String(remainder[remainder.startIndex..<open])
            if !literal.isEmpty { result.append(PhraseSegment(text: literal, kind: .literal)) }

            let name = String(remainder[remainder.index(after: open)..<close])
                .trimmingCharacters(in: .whitespaces)

            if let value = values[name], !value.isEmpty {
                result.append(PhraseSegment(text: value, kind: .filled))
            } else {
                let kind: PhraseSegment.Kind = slotPosition == index ? .current : .pending
                result.append(PhraseSegment(text: "{\(name)}", kind: kind))
            }

            slotPosition += 1
            remainder = remainder[remainder.index(after: close)...]
        }

        if !remainder.isEmpty { result.append(PhraseSegment(text: String(remainder), kind: .literal)) }
        return result
    }
}
