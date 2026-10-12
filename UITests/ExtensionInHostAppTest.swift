import XCTest

/// Drives Safari, switches to the Steady keyboard with the globe key, and types.
/// This is the one acceptance criterion that can't be checked from inside our
/// own app: US-003's "works in a standard text field in any host app".
final class ExtensionInHostAppTest: XCTestCase {

    func testSteadyKeyboardTypesInSafari() throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()

        func shoot(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        shoot("A-safari-launched")

        // A fresh simulator throws up one-time notices — Safari's search
        // suggestions blurb, then the system keyboard's slide-to-type tutorial.
        func dismissIntroScreens() {
            for _ in 0..<4 {
                let next = safari.buttons["Continue"]
                guard next.waitForExistence(timeout: 3), next.isHittable else { return }
                next.tap()
            }
        }
        dismissIntroScreens()

        // Focus the address bar so a keyboard comes up.
        let field = safari.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15), "no text field in Safari")
        field.tap()

        // iOS remembers the last keyboard used, so Steady may come straight up.
        // XCUITest's `keyboards` query only matches the *system* keyboard — a
        // custom keyboard never shows there — so check for either.
        let steadyMarker = safari.buttons["panel-phrases"]
        let keyboardIsUp =
            steadyMarker.waitForExistence(timeout: 5)
            || safari.keyboards.firstMatch.waitForExistence(timeout: 10)
        XCTAssertTrue(keyboardIsUp, "no keyboard appeared at all")
        dismissIntroScreens()
        shoot("B-keyboard-up")

        // If some other keyboard is up, cycle with the globe until Steady shows.
        var switches = 0
        while !steadyMarker.exists && switches < 4 {
            let globe = safari.buttons["Next keyboard"]
            if globe.waitForExistence(timeout: 5) {
                globe.tap()
            }
            switches += 1
            shoot("C-after-globe-\(switches)")
        }

        try XCTSkipUnless(
            steadyMarker.waitForExistence(timeout: 5),
            "Steady isn't an enabled keyboard on this simulator. "
                + "Run scripts/enable-keyboard-in-simulator.sh first."
        )
        shoot("D-steady-active")

        // Type "th" and check the keyboard reshapes inside the host app.
        safari.buttons["t"].tap()
        safari.buttons["h"].tap()
        shoot("E-typed-th")

        XCTAssertTrue(safari.buttons["e"].exists, "e should remain after th")
        XCTAssertFalse(safari.buttons["q"].exists, "q can't follow th and should be gone")

        // The completion chip should put a real word into Safari's address bar.
        let chip = safari.buttons.matching(identifier: "suggestion-0").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "no suggestion chip")
        chip.tap()
        shoot("F-after-chip")

        // Safari pads its address-bar accessibility value with a leading space,
        // so compare on the trimmed text and check the trailing space separately.
        let typed = (field.value as? String) ?? ""
        XCTAssertEqual(typed.trimmingCharacters(in: .whitespaces), "the")
        XCTAssertTrue(typed.hasSuffix(" "), "the chip should leave a trailing space")
    }
}
