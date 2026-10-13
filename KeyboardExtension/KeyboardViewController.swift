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
    private lazy var sink = ProxyTextSink(owner: self)

    /// Taller than the stock keyboard on purpose: the whole point is bigger,
    /// easier-to-hit targets.
    ///
    /// It is also the exact sum of what the surface lays out, because the panel
    /// toolbar now sits at the bottom and anything short clips *that* rather
    /// than a few points of key tray: keys 282 + suggestions 62 + toolbar 50 =
    /// 394, plus 4 of slack. (At 390 the stack was already 4pt over.)
    private let surfaceHeight: CGFloat = 398

    private var hostingController: UIHostingController<KeyboardSurface>?

    override func viewDidLoad() {
        super.viewDidLoad()
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
            sink: sink,
            showsNextKeyboardKey: needsInputModeSwitchKey,
            onNextKeyboard: { [weak self] in self?.advanceToNextInputMode() },
            onCollapse: { [weak self] in self?.dismissKeyboard() }
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
        controller.refresh(context: sink.contextBeforeInput, isSecure: sink.isSecureEntry)
    }
}

/// Bridges the shared keyboard UI onto the host app's text field.
final class ProxyTextSink: TextSink {

    private weak var owner: UIInputViewController?

    init(owner: UIInputViewController) {
        self.owner = owner
    }

    private var proxy: UITextDocumentProxy? { owner?.textDocumentProxy }

    var contextBeforeInput: String? { proxy?.documentContextBeforeInput }

    /// In a password field iOS reports secure entry; prediction and resizing
    /// stand down and the layout falls back to a static QWERTY (FR-9).
    ///
    /// `isSecureTextEntry` is an optional requirement of `UITextInputTraits`,
    /// so it's read defensively rather than assumed present.
    var isSecureEntry: Bool {
        guard let object = proxy as? NSObject else { return false }
        let selector = NSSelectorFromString("isSecureTextEntry")
        guard object.responds(to: selector) else { return false }
        return object.value(forKey: "isSecureTextEntry") as? Bool ?? false
    }

    func insertText(_ text: String) {
        proxy?.insertText(text)
    }

    func deleteBackward() {
        proxy?.deleteBackward()
    }
}
