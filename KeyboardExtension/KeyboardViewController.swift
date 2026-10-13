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
    private let surfaceHeight: CGFloat = 390

    private var hostingController: UIHostingController<KeyboardSurface>?

    override func viewDidLoad() {
        super.viewDidLoad()
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
