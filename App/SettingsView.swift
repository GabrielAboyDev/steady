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
                            topScale: previewController.topScale,
                            colorVision: store.settings.colorVision
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

                    Text(
                        "The keyboard offers up to \(PredictionController.suggestionLimit) words; three show at once."
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                }
                // Nothing in here applies with the chips switched off.
                .disabled(!store.settings.showSuggestionChips)

                Section("Keyboard appearance") {
                    Picker("Keyboard appearance", selection: $store.settings.keyboardAppearance) {
                        ForEach(KeyboardAppearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("keyboard-appearance")

                    Text(store.settings.keyboardAppearance.explanation)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)

                    Text(
                        "Names and Phrases always stay light, so saved entries read the same way every time."
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                }

                Section("Colour vision") {
                    Picker("Colour vision", selection: $store.settings.colorVision) {
                        ForEach(ColorVisionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("color-vision")

                    Text(store.settings.colorVision.explanation)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        // Two lines, whatever the phone: the copy is written
                        // to fit, and this keeps a narrow screen honest.
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    // The tints are what carries "how likely is this letter",
                    // so the choice has to be made by looking, not by reading
                    // the name of a condition.
                    VStack(alignment: .leading, spacing: 6) {
                        ResizePreviewRow(
                            keyScales: previewController.keyScales,
                            topScale: previewController.topScale,
                            colorVision: store.settings.colorVision
                        )
                        Text(
                            "The top row after typing “th”, tinted by how likely each letter is to come next."
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                    }
                    .padding(.vertical, 4)
                }

                Section("Typing") {
                    Toggle(isOn: $store.settings.autoCapitalization) {
                        settingLabel(
                            "Auto-capitalisation",
                            detail: "Shift goes up at the start of a sentence."
                        )
                    }
                    Toggle(isOn: $store.settings.autoCorrection) {
                        settingLabel(
                            "Auto-correction",
                            detail: "Fix a misspelled word when you type a space. Backspace puts it back."
                        )
                    }
                    Toggle(isOn: $store.settings.spellingSuggestions) {
                        settingLabel(
                            "Spelling suggestions",
                            detail: "When a word isn't in the dictionary, the chips offer the spell checker's guesses."
                        )
                    }
                    Toggle(isOn: $store.settings.enableCapsLock) {
                        settingLabel(
                            "Enable caps lock",
                            detail: "Double-tap shift to lock it."
                        )
                    }
                    Toggle(isOn: $store.settings.smartPunctuation) {
                        settingLabel(
                            "Smart punctuation",
                            detail: "Curly quotes, and two hyphens become a dash."
                        )
                    }
                    Toggle(isOn: $store.settings.periodShortcut) {
                        settingLabel(
                            "“.” shortcut",
                            detail: "Two quick spaces end the sentence with a full stop."
                        )
                    }
                    Toggle(isOn: $store.settings.textReplacement) {
                        settingLabel(
                            "Text replacement",
                            detail: "Use the shortcuts from Settings > General > Keyboard > Text Replacement, and know your contacts' names."
                        )
                    }
                    Toggle(isOn: $store.settings.nextLetterHighlight) {
                        settingLabel(
                            "Next letter highlight",
                            detail: "Ring and bold the single most likely next letter."
                        )
                    }
                    Text(
                        "iOS doesn't let a keyboard read Settings > General > Keyboard, so these ask again. A text field that turns one of them off is always obeyed. Keyboard clicks follow the iOS setting on their own."
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                }

                Section {
                    Text(Self.versionString)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.clear)
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

    /// "Version 1.0 (3)", from the bundle's own marketing and build numbers.
    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Version \(version) (\(build))"
    }
}

/// A compact version of the top keyboard row, so the effect of a settings
/// change is visible immediately (as the settings mock shows).
struct ResizePreviewRow: View {

    let keyScales: [Character: KeyScale]
    let topScale: Double
    var colorVision: ColorVisionMode = .standard

    private let keys = Array("qwertyuiop")

    var body: some View {
        GeometryReader { geometry in
            let palette = colorVision.keyPalette
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
                        .foregroundStyle(palette.label(tier))
                        .frame(width: width, height: min(max(26 * scale, 18), 44))
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(palette.face(tier))
                                .padding(.horizontal, 1.5)
                        )
                        .opacity(isPossible ? 1 : 0.34)
                }
            }
            .frame(width: geometry.size.width, height: 44, alignment: .bottom)
            .animation(.easeOut(duration: 0.18), value: total)
        }
        .frame(height: 44)
        // Sat on the tray colour, like the real keyboard: an impossible key
        // is drawn at 0.34 opacity, so what it composites onto decides whether
        // it still reads as "out of the way". Measured against this grey.
        .padding(3)
        .background(Theme.keyTray)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
