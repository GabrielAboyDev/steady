import SwiftUI

/// Either an existing phrase a user tapped in the list, or one just created
/// by "Add phrase" — the two land on the same editor, but only the latter
/// should grab the keyboard and focus the title.
private enum PhraseRoute: Hashable {
    case existing(PhraseTemplate.ID)
    case justAdded(PhraseTemplate.ID)

    var id: PhraseTemplate.ID {
        switch self {
        case .existing(let id), .justAdded(let id): return id
        }
    }

    var isJustAdded: Bool {
        switch self {
        case .existing: return false
        case .justAdded: return true
        }
    }
}

/// Manage phrase templates and their `{slot}` variables (US-009).
struct PhrasesEditorView: View {

    @EnvironmentObject private var store: SharedStore
    @State private var path: [PhraseRoute] = []
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach($store.phrases) { $phrase in
                        NavigationLink(value: PhraseRoute.existing(phrase.id)) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(phrase.title).font(.system(size: 16, weight: .medium))
                                Text(phrase.template)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textMuted)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .onDelete { offsets in
                        store.phrases.remove(atOffsets: offsets)
                    }
                } footer: {
                    Text(
                        "Write a blank as {name}, {minutes}, {place} — anything in braces becomes a blank you fill in when you use the phrase. A {name} blank offers all your saved names; a blank named after a Names category, like {People}, offers just that category. With the Steady keyboard up, the Names panel's first tile writes one for you."
                    )
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Phrases")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let phrase = PhraseTemplate(title: "", template: "Hi {name}, ")
                        store.phrases.append(phrase)
                        path.append(.justAdded(phrase.id))
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add phrase")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editMode = editMode == .active ? .inactive : .active
                    } label: {
                        Image(
                            systemName: editMode == .active
                                ? "checkmark.circle.fill" : "pencil.circle.fill")
                    }
                    .accessibilityLabel(editMode == .active ? "Done" : "Edit")
                }
            }
            .navigationDestination(for: PhraseRoute.self) { route in
                if let index = store.phrases.firstIndex(where: { $0.id == route.id }) {
                    PhraseEditor(
                        phrase: $store.phrases[index],
                        nameOptions: store.allQuickInsertTexts,
                        focusTitleOnAppear: route.isJustAdded
                    )
                }
            }
        }
    }
}

/// Edit one phrase: its title, its sentence, and each blank's options.
private struct PhraseEditor: View {

    private enum Field: Hashable {
        case title
        case template
    }

    @Binding var phrase: PhraseTemplate
    let nameOptions: [String]
    var focusTitleOnAppear: Bool = false

    @EnvironmentObject private var store: SharedStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    var body: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $phrase.title)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .template }
            }

            Section("Sentence") {
                TextField("Sentence with {blanks}", text: $phrase.template, axis: .vertical)
                    .focused($focusedField, equals: .template)
                    .lineLimit(2...5)
            }

            if phrase.slots.isEmpty {
                Section {
                    Text("No blanks yet — add one by typing {something} in the sentence.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                }
            }

            // Not `ForEach($phrase.slots)`: that hands each row a Binding
            // subscripted by position into the array, and pasting into the
            // sentence field can shrink `phrase.slots` (via `syncSlots`,
            // below) while a Toggle here is still mid-render — SwiftUI then
            // reads a stale offset and traps. Binding by the slot's own id
            // instead means a row whose slot has since disappeared just
            // reads its last known value and writes nowhere, instead of
            // crashing.
            ForEach(phrase.slots) { slot in
                Section("{\(slot.name)}") {
                    Toggle("Use my saved names", isOn: binding(for: slot, \.drawsFromNames))

                    if slot.drawsFromNames {
                        Text(
                            nameOptions.isEmpty
                                ? "No saved names yet — add some on the Names tab."
                                : nameOptions.joined(separator: ", ")
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                    } else if let category = category(for: slot) {
                        // Named after one of the Names categories: it offers
                        // just that category, which is what the keyboard's
                        // Variable tile wrote it for.
                        Text(
                            category.entries.isEmpty
                                ? "Offers your \(category.name) names — none saved yet."
                                : "Offers your \(category.name) names: "
                                    + category.entries.map(\.text).joined(separator: ", ")
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                    } else {
                        TextField(
                            "Options, separated by commas",
                            text: Binding(
                                get: { slot.options.joined(separator: ", ") },
                                set: { newValue in
                                    update(slot.id) {
                                        $0.options =
                                            newValue
                                            .split(separator: ",")
                                            .map { $0.trimmingCharacters(in: .whitespaces) }
                                            .filter { !$0.isEmpty }
                                    }
                                }
                            ),
                            axis: .vertical
                        )
                        .lineLimit(1...4)
                    }

                    Toggle("Allow typing a value", isOn: binding(for: slot, \.allowsFreeText))
                    Toggle("Required", isOn: binding(for: slot, \.isRequired))
                }
            }
        }
        .navigationTitle(phrase.title.isEmpty ? "Phrase" : phrase.title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { dismiss() }
            }
        }
        .onAppear {
            syncSlots()
            if focusTitleOnAppear { focusedField = .title }
        }
        .onChange(of: phrase.template) { _ in syncSlots() }
        // Tell the keyboard when the sentence is what's being typed, so its
        // Names panel offers a blank instead of a name. Off again whenever
        // focus moves, the screen closes, or the app leaves the foreground
        // — the flag must never outlive the field, or every other app's
        // Names panel would offer blanks too.
        .onChange(of: focusedField) { field in
            store.noteEditingPhraseTemplate(field == .template)
        }
        .onChange(of: scenePhase) { phase in
            store.noteEditingPhraseTemplate(phase == .active && focusedField == .template)
        }
        .onDisappear { store.noteEditingPhraseTemplate(false) }
    }

    /// The category whose entries a blank with this name would offer, if any.
    private func category(for slot: PhraseSlot) -> QuickInsertCategory? {
        store.categories.first { $0.name.caseInsensitiveCompare(slot.name) == .orderedSame }
    }

    /// Keep the stored slot list in step with the braces in the sentence,
    /// carrying existing option lists across edits.
    private func syncSlots() {
        let resolved = phrase.resolvedSlots
        if resolved != phrase.slots {
            phrase.slots = resolved
        }
    }

    /// A two-way binding to one field of one slot, found by id at read and
    /// write time rather than captured by array position — see the comment
    /// above the `ForEach` this backs.
    private func binding<Value>(
        for slot: PhraseSlot, _ keyPath: WritableKeyPath<PhraseSlot, Value>
    ) -> Binding<Value> {
        Binding(
            get: { slot[keyPath: keyPath] },
            set: { newValue in update(slot.id) { $0[keyPath: keyPath] = newValue } }
        )
    }

    /// Applies a change to the slot with this id, if it's still there.
    private func update(_ id: PhraseSlot.ID, _ mutate: (inout PhraseSlot) -> Void) {
        guard let index = phrase.slots.firstIndex(where: { $0.id == id }) else { return }
        mutate(&phrase.slots[index])
    }
}
