import SwiftUI

@main
struct SteadyApp: App {

    @StateObject private var store = SharedStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
            // UI tests and the store captures launch with this flag, so each
            // run starts from the same demo content rather than whatever the
            // previous one left in the app group. A shipping install never
            // takes this path and starts with nothing.
            if ProcessInfo.processInfo.arguments.contains("-UITestResetState") {
                SharedStore.shared.resetToDemoContent()
            }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.brand)
                // Steady's palette is light-only (see `Theme`), so the app is
                // pinned to the light appearance. Without this the system
                // chrome — the Settings `Form`'s grouped background, its
                // segmented pickers and separators, the navigation titles and
                // the tab bar — flips to dark while every brand surface stays
                // light, which leaves dark-on-dark text in Settings.
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { phase in
                    // Re-read in case the extension wrote while we were away.
                    if phase == .active { store.reload() }
                }
        }
    }
}
