import SwiftUI

struct RootView: View {

    var body: some View {
        TabView {
            OnboardingView()
                .tabItem { Label("Setup", systemImage: "checkmark.circle") }

            PracticePadView()
                .tabItem { Label("Practice", systemImage: "keyboard") }

            NamesEditorView()
                .tabItem { Label("Names", systemImage: "person.2") }

            PhrasesEditorView()
                .tabItem { Label("Phrases", systemImage: "text.bubble") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
    }
}
