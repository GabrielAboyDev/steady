import PredictiveEngine
import SwiftUI

/// Resize aggressiveness and key behaviour (US-006). Everything written here
/// goes straight into the app group, so the extension picks it up next time it
/// appears.
struct SettingsView: View {

    @EnvironmentObject private var store: SharedStore
    @StateObject private var previewController = PredictionController()

    var body: some View {
        NavigationStack {
            Form {
                Section("Resize strength") {
                    Picker("Resize strength", selection: $store.settings.resizeStrength) {
                        ForEach(ResizeStrength.allCases) { strength in
                            Text(strength.title).tag(strength)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(store.settings.resizeStrength.explanation)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)

                    VStack(alignment: .leading, spacing: 6) {
                        ResizePreviewRow(
                            keyScales: previewController.keyScales,
                            topScale: previewController.topScale
                        )
                        Text("Preview after typing “th”.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .padding(.vertical, 4)
                }

                Section("Key behaviour") {
                    Toggle(isOn: $store.settings.hideImpossibleKeys) {
                        settingLabel(
                            "Hide impossible keys",
                            detail:
                                "Remove letters that can't continue a word. Off shrinks and fades them instead."
                        )
                    }
                    Toggle(isOn: $store.settings.enlargeLikelyKeys) {
                        settingLabel(
                            "Enlarge likely keys",
                            detail: "Grow the most probable next letters."
                        )
                    }
                    Toggle(isOn: $store.settings.showSuggestionChips) {
                        settingLabel(
                            "Big word suggestions",
                            detail: "Show three large completion chips above the keys."
                        )
                    }
                }

                Section("Browsing suggestions") {
                    Picker("Browsing suggestions", selection: $store.settings.suggestionBrowsing) {
                        ForEach(SuggestionBrowsing.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("suggestion-browsing")

                    Text(store.settings.suggestionBrowsing.explanation)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)

                    Text("The keyboard offers up to \(PredictionController.suggestionLimit) words; three show at once.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                }
                // Nothing in here applies with the chips switched off.
                .disabled(!store.settings.showSuggestionChips)

                Section("Sharing") {
                    HStack {
                        Text(store.isSharingThroughAppGroup ? "Shared with the keyboard" : "Not shared yet")
                            .foregroundStyle(store.isSharingThroughAppGroup ? Theme.positive : Theme.caution)
                        Spacer()
                        if let lastRun = store.keyboardLastRun {
                            Text(lastRun, style: .relative)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                    Text(
                        store.isSharingThroughAppGroup
                            ? "Settings are stored in the app group, so the keyboard reads them the next time it opens."
                            : "The app group isn't available in this build, so the keyboard can't read these settings yet."
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear(perform: updatePreview)
            .onChange(of: store.settings) { _ in updatePreview() }
        }
    }

    private func settingLabel(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 16))
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func updatePreview() {
        previewController.update(settings: store.settings)
        previewController.refresh(context: "th", isSecure: false)
    }
}

/// A compact version of the top keyboard row, so the effect of a settings
/// change is visible immediately (as the settings mock shows).
struct ResizePreviewRow: View {

    let keyScales: [Character: KeyScale]
    let topScale: Double

    private let keys = Array("qwertyuiop")

    var body: some View {
        GeometryReader { geometry in
            let scales = keys.map { max(0, keyScales[$0]?.scale ?? 1) }
            let total = scales.reduce(0, +)
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
                    let scale = scales[index]
                    let width = total > 0 ? geometry.size.width * (scale / total) : 0
                    let isPossible = keyScales[key]?.isPossible ?? true
                    let tier = KeyTier.forScale(scale, isPossible: isPossible, topScale: topScale)

                    Text(String(key))
                        .font(
                            .system(
                                size: min(max(11 * scale, 9), 20), weight: tier.isEmphasized ? .bold : .medium
                            )
                        )
                        .foregroundStyle(tier.label)
                        .frame(width: width, height: min(max(26 * scale, 18), 44))
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(tier.face)
                                .padding(.horizontal, 1.5)
                        )
                        .opacity(isPossible ? 1 : 0.34)
                }
            }
            .frame(width: geometry.size.width, height: 44, alignment: .bottom)
            .animation(.easeOut(duration: 0.18), value: total)
        }
        .frame(height: 44)
    }
}
