import SwiftUI

/// Manage the quick-insert categories and entries the keyboard panel shows
/// (US-008). Everything is stored in the app group.
struct NamesEditorView: View {

    @EnvironmentObject private var store: SharedStore
    @State private var newCategoryName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach($store.categories) { $category in
                    Section {
                        ForEach($category.entries) { $entry in
                            NavigationLink {
                                EntryEditor(entry: $entry)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.text).font(.system(size: 16, weight: .medium))
                                    if let note = entry.note, !note.isEmpty {
                                        Text(note)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.textMuted)
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            $category.wrappedValue.entries.remove(atOffsets: offsets)
                        }

                        Button {
                            $category.wrappedValue.entries.append(QuickInsertEntry(text: "New name"))
                        } label: {
                            Label("Add name", systemImage: "plus.circle.fill")
                        }
                    } header: {
                        HStack {
                            TextField("Category", text: $category.name)
                                .font(.system(size: 13, weight: .semibold))
                            Button(role: .destructive) {
                                store.categories.removeAll { $0.id == category.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Delete category \(category.name)")
                        }
                    }
                }

                Section("New category") {
                    HStack {
                        TextField("e.g. Neighbours", text: $newCategoryName)
                        Button("Add") {
                            let name = newCategoryName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            store.categories.append(QuickInsertCategory(name: name, entries: []))
                            newCategoryName = ""
                        }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Names")
            .toolbar { EditButton() }
        }
    }
}

/// Edit one quick-insert entry.
private struct EntryEditor: View {

    @Binding var entry: QuickInsertEntry

    var body: some View {
        Form {
            Section("Inserted text") {
                TextField("Text", text: $entry.text)
            }
            Section("Note") {
                TextField(
                    "e.g. sister",
                    text: Binding(
                        get: { entry.note ?? "" },
                        set: { entry.note = $0.isEmpty ? nil : $0 }
                    )
                )
            }
            Section {
                Toggle("Add a space after inserting", isOn: $entry.appendsSpace)
            }
        }
        .navigationTitle(entry.text.isEmpty ? "Entry" : entry.text)
    }
}
