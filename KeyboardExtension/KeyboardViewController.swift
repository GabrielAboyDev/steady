import SwiftUI
import UIKit

/// The system-wide keyboard. Hosts the shared SwiftUI surface and writes
/// through `textDocumentProxy` into whatever app the user is typing in.
///
/// No network access and no "Allow Full Access" — the Info.plist sets
/// `RequestsOpenAccess` to false and nothing here opens a connection (FR-6).
final class KeyboardViewController: UIInputViewController {

    private let store = SharedStore.shared
    private let controller = PredictionController()
    private let composer = TextComposer()
    private lazy var sink = ProxyTextSink(owner: self)

    /// Taller than the stock keyboard on purpose: the whole point is bigger,
    /// easier-to-hit targets.
    ///
    /// It is also the exact sum of what the surface lays out, because anything
    /// short clips the bottom row of keys: suggestions 32 + toolbar 42 (a
    /// 38pt track with 4 above it) + keys 233 (three 55pt rows, a 44pt bottom
    /// row, 18 of row spacing, 6 below). Row height is the key height times
    /// the growth cap in `DynamicKeyboardView`; the cap went from 1.5 to 1.25,
    /// which with the dropped paddings took this from 348 to 307.
    private let surfaceHeight: CGFloat = 307

    private var hostingController: UIHostingController<KeyboardSurface>?

    /// The input view adopts `UIInputViewAudioFeedback`, which is what lets
    /// `playInputClick` sound — and lets iOS mute it when the user has
    /// Keyboard Clicks off. That is one native setting a custom keyboard
    /// does inherit, by not deciding for itself.
    override func loadView() {
        let input = ClickingInputView(frame: .zero, inputViewStyle: .keyboard)
        inputView = input
        view = input
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // The user's text replacements and contact names. Granted to every
        // keyboard, Full Access or not, and it comes back asynchronously.
        requestSupplementaryLexicon { [weak self] lexicon in
            let entries = lexicon.entries.map {
                LexiconEntry(userInput: $0.userInput, documentText: $0.documentText)
            }
            DispatchQueue.main.async {
                self?.composer.lexicon = entries
                self?.controller.lexicon = entries
            }
        }
        // Nothing pins the appearance here on purpose. A keyboard extension
        // inherits the appearance of the app it is typing into, and that is
        // exactly what `KeyboardAppearance.system` needs to read. Pinning the
        // whole view to light — as this did while the palette was light-only —
        // overrides the trait collection the surface derives `\.colorScheme`
        // from, which makes the Dark and Match-system settings impossible.
        //
        // The panels that must stay light pin themselves instead, through
        // `LightPanel` in `KeyboardSurface`, which is scoped to those two
        // subtrees rather than the whole keyboard.
        installSurface()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Pick up anything the user changed in the container app.
        store.reload()
        store.noteKeyboardDidRun()
        refreshPredictions()
    }

    /// The host's text changed under us (cursor moved, field switched, text
    /// cleared by the app) — recompute so the keys match reality.
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshPredictions()
    }

    private func installSurface() {
        let surface = KeyboardSurface(
            store: store,
            controller: controller,
            composer: composer,
            sink: sink,
            showsNextKeyboardKey: needsInputModeSwitchKey,
            onNextKeyboard: { [weak self] in self?.advanceToNextInputMode() },
            onCollapse: { [weak self] in self?.dismissKeyboard() },
            sitsOnSystemBackdrop: true
        )

        let host = UIHostingController(rootView: surface)
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        hostingController = host

        // Keyboard extensions must declare their own height.
        let height = view.heightAnchor.constraint(equalToConstant: surfaceHeight)
        height.priority = UILayoutPriority(999)
        height.isActive = true
    }

    private func refreshPredictions() {
        controller.update(settings: store.settings)
        controller.refresh(context: sink.contextBeforeInput, traits: sink.traits)
    }
}

/// A `UIInputView` that opts into the system key click.
private final class ClickingInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

/// Bridges the shared keyboard UI onto the host app's text field.
final class ProxyTextSink: TextSink {

    private weak var owner: UIInputViewController?

    init(owner: UIInputViewController) {
        self.owner = owner
    }

    private var proxy: UITextDocumentProxy? { owner?.textDocumentProxy }

    var contextBeforeInput: String? { proxy?.documentContextBeforeInput }

    /// Everything the host field says about itself, read off the proxy:
    /// capitalization, correction and punctuation traits, keyboard and return
    /// key types, appearance, and secure entry (a password field, where
    /// prediction and resizing stand down — FR-9).
    var traits: InputTraits {
        guard let proxy else { return .standard }
        return InputTraits(proxy)
    }

    func insertText(_ text: String) {
        proxy?.insertText(text)
    }

    func deleteBackward() {
        proxy?.deleteBackward()
    }

    /// The system click. Silent when Keyboard Clicks is off in iOS Settings.
    func playKeyClick() {
        UIDevice.current.playInputClick()
    }
}
