import SwiftUI

/// Manage the quick-insert categories and entries the keyboard panel shows
/// (US-008). Everything is stored in the app group.
struct NamesEditorView: View {

    @EnvironmentObject private var store: SharedStore
    @State private var isPresentingCreateName = false

    var body: some View {
        NavigationStack {
            List {
                ForEach($store.categories) { $category in
                    Section {
                        ForEach($category.entries) { $entry in
                            NavigationLink {
                                EntryEditor(entry: $entry)
                            } label: {
                                Text(entry.text).font(.system(size: 16, weight: .medium))
                            }
                        }
                        .onDelete { offsets in
                            $category.wrappedValue.entries.remove(atOffsets: offsets)
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
            }
            .navigationTitle("Names")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresentingCreateName = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add name")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $isPresentingCreateName) {
                CreateNameSheet(store: store)
            }
        }
    }
}

/// Create a new quick-insert entry, placing it in an existing category or a
/// brand-new one typed on the spot.
private struct CreateNameSheet: View {

    @ObservedObject var store: SharedStore
    @Environment(\.dismiss) private var dismiss

    private enum CategoryChoice: Hashable {
        case existing(QuickInsertCategory.ID)
        case new
    }

    @State private var nameText = ""
    @State private var categoryChoice: CategoryChoice?
    @State private var newCategoryName = ""
    @FocusState private var isNameFieldFocused: Bool

    private var trimmedName: String { nameText.trimmingCharacters(in: .whitespaces) }
    private var trimmedNewCategoryName: String { newCategoryName.trimmingCharacters(in: .whitespaces) }

    private var canSave: Bool {
        guard !trimmedName.isEmpty else { return false }
        switch categoryChoice {
        case .existing: return true
        case .new: return !trimmedNewCategoryName.isEmpty
        case nil: return false
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Sarah", text: $nameText)
                        .focused($isNameFieldFocused)
                }

                Section("Category") {
                    Picker("Category", selection: $categoryChoice) {
                        Text("Choose a category").tag(CategoryChoice?.none)
                        ForEach(store.categories) { category in
                            Text(category.name).tag(CategoryChoice?.some(.existing(category.id)))
                        }
                        Text("New category…").tag(CategoryChoice?.some(.new))
                    }

                    if categoryChoice == .new {
                        TextField("e.g. Neighbours", text: $newCategoryName)
                    }
                }
            }
            .navigationTitle("Add Name")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { isNameFieldFocused = true }
        }
    }

    private func save() {
        let entry = QuickInsertEntry(text: trimmedName)
        switch categoryChoice {
        case .existing(let id):
            guard let index = store.categories.firstIndex(where: { $0.id == id }) else { return }
            store.categories[index].entries.append(entry)
        case .new:
            guard !trimmedNewCategoryName.isEmpty else { return }
            store.categories.append(QuickInsertCategory(name: trimmedNewCategoryName, entries: [entry]))
        case nil:
            return
        }
        dismiss()
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
        }
        .navigationTitle(entry.text.isEmpty ? "Entry" : entry.text)
    }
}
