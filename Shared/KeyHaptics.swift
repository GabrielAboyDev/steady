import UIKit

/// A light tap for every key that produces input, when the setting is on.
///
/// One prepared generator is kept for the life of the surface: `prepare()`
/// warms the Taptic Engine so the tap lands with the keystroke rather than a
/// beat after it, and it is called again after each tap because the engine
/// idles within a second or two. Everything here is a no-op on hardware or in
/// a context without haptics, so nothing needs to be gated by device.
final class KeyHaptics: ObservableObject {

    private let generator = UIImpactFeedbackGenerator(style: .light)

    init() {
        generator.prepare()
    }

    func tap() {
        generator.impactOccurred()
        generator.prepare()
    }
}
