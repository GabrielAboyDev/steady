import SwiftUI

/// Manage phrase templates and their `{slot}` variables (US-009).
struct PhrasesEditorView: View {

    @EnvironmentObject private var store: SharedStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($store.phrases) { $phrase in
                        NavigationLink {
                            PhraseEditor(phrase: $phrase, nameOptions: store.allQuickInsertTexts)
                        } label: {
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
                    Text("Write a blank as {name}, {minutes}, {place} — anything in braces becomes a blank you fill in when you use the phrase. A {name} blank offers your saved names.")
                }

                Section {
                    Button {
                        store.phrases.append(
                            PhraseTemplate(title: "New phrase", template: "Hi {name}, ")
                        )
                    } label: {
                        Label("Add phrase", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Phrases")
            .toolbar { EditButton() }
        }
    }
}

/// Edit one phrase: its title, its sentence, and each blank's options.
private struct PhraseEditor: View {

    @Binding var phrase: PhraseTemplate
    let nameOptions: [String]

    var body: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $phrase.title)
            }

            Section("Sentence") {
                TextField("Sentence with {blanks}", text: $phrase.template, axis: .vertical)
                    .lineLimit(2...5)
                Text(phrase.assembled(with: [:]))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }

            if phrase.slots.isEmpty {
                Section {
                    Text("No blanks yet — add one by typing {something} in the sentence.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                }
            }

            ForEach($phrase.slots) { $slot in
                Section("{\(slot.name)}") {
                    Toggle("Use my saved names", isOn: $slot.drawsFromNames)

                    if slot.drawsFromNames {
                        Text(nameOptions.isEmpty
                             ? "No saved names yet — add some on the Names tab."
                             : nameOptions.joined(separator: ", "))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                    } else {
                        TextField(
                            "Options, separated by commas",
                            text: Binding(
                                get: { slot.options.joined(separator: ", ") },
                                set: { newValue in
                                    slot.options = newValue
                                        .split(separator: ",")
                                        .map { $0.trimmingCharacters(in: .whitespaces) }
                                        .filter { !$0.isEmpty }
                                }
                            ),
                            axis: .vertical
                        )
                        .lineLimit(1...4)
                    }

                    Toggle("Allow typing a value", isOn: $slot.allowsFreeText)
                    Toggle("Required", isOn: $slot.isRequired)
                }
            }
        }
        .navigationTitle(phrase.title.isEmpty ? "Phrase" : phrase.title)
        .onAppear(perform: syncSlots)
        .onChange(of: phrase.template) { _ in syncSlots() }
    }

    /// Keep the stored slot list in step with the braces in the sentence,
    /// carrying existing option lists across edits.
    private func syncSlots() {
        let resolved = phrase.resolvedSlots
        if resolved != phrase.slots {
            phrase.slots = resolved
        }
    }
}
