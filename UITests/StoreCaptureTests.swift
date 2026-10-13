import XCTest

/// Captures the container app's contribution to the App Store listing — the
/// settings screen — plus a preview take of the practice pad.
///
/// The screenshots that sell the app come from `StoreMessagesCaptureTests`
/// instead: the keyboard running inside Messages, which is where it is
/// actually used. Nothing here asserts behaviour — `SteadyUITests` does that.
/// This exists so every pixel that ships in the listing comes out of the
/// shipping build rather than a mockup.
///
/// Skipped unless `STEADY_CAPTURE=1` is in the environment, so CI never pays
/// for it. Drive it through `scripts/capture-store-assets.sh`.
final class StoreCaptureTests: XCTestCase {

    private var app: XCUIApplication!

    /// Where the frames land inside the test runner's container. The capture
    /// script copies them out with `simctl get_app_container`.
    private static var outputDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StoreCapture", isDirectory: true)
    }

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["STEADY_CAPTURE"] == "1",
            "Capture run only — see scripts/capture-store-assets.sh"
        )
        continueAfterFailure = false
        // Start from an empty directory: the collector copies whatever is in
        // here, and a frame left behind by an earlier run would be picked up
        // as though this run had produced it.
        try? FileManager.default.removeItem(at: Self.outputDirectory)
        try FileManager.default.createDirectory(
            at: Self.outputDirectory, withIntermediateDirectories: true)

        app = XCUIApplication()
        app.launchArguments += ["-UITestResetState", "1"]
        app.launch()

        // Wait for the first screen before anything probes the layout, so the
        // tab lookups below can use short timeouts.
        XCTAssertTrue(
            app.staticTexts["Almost ready"].waitForExistence(timeout: 60),
            "the app did not reach its first screen"
        )

        // Whatever ran before this leaves a "◀ Messages" chip in the status
        // bar. Going home and reactivating clears it, which matters when the
        // status bar is in the frame.
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2.5)
        app.activate()
        XCTAssertTrue(app.staticTexts["Almost ready"].waitForExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 1.5)
    }

    // MARK: Capture

    /// Saves the frame twice: to the runner's container (what the script
    /// collects) and as an attachment (so a failed run is still inspectable).
    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()

        let url = Self.outputDirectory.appendingPathComponent("\(name).png")
        do {
            try screenshot.pngRepresentation.write(to: url, options: .atomic)
        } catch {
            XCTFail("could not write \(name).png: \(error)")
        }

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// iPhone reports the tab bar as a tab bar. iPadOS 26 floats it above the
    /// content and reports the items as plain buttons, so try both.
    private func tab(_ name: String) {
        let inTabBar = app.tabBars.buttons[name]
        if inTabBar.waitForExistence(timeout: 3) {
            inTabBar.tap()
            return
        }
        let plain = app.buttons[name].firstMatch
        if !plain.waitForExistence(timeout: 10) {
            dumpHierarchy("no-tab-\(name)")
            XCTFail("no \(name) tab")
            return
        }
        plain.tap()
    }

    /// Writes the accessibility tree next to the frames, so a run that failed
    /// on a device this was not written against can be diagnosed without
    /// re-running it.
    private func dumpHierarchy(_ name: String) {
        capture("debug-\(name)")
        let dump = Self.outputDirectory.appendingPathComponent("debug-\(name).txt")
        try? app.debugDescription.write(to: dump, atomically: true, encoding: .utf8)
    }

    /// The pad shows a placeholder when it is empty; read that back as empty.
    private var padText: String {
        let label = app.staticTexts.matching(identifier: "practicePadText").firstMatch.label
        return label == "Start typing…" ? "" : label
    }

    /// Taps one key per character, waiting for each to appear first — the
    /// layout is still animating from the previous keystroke, and a tap sent
    /// into that gap lands on nothing.
    private func typeRun(_ text: String, pause: TimeInterval = 0) {
        for character in text {
            if character == " " {
                tapSpace()
            } else {
                let key = app.buttons[String(character)].firstMatch
                if !key.waitForExistence(timeout: 3) {
                    reportMissingKey(character)
                    return
                }
                key.tap()
            }
            if pause > 0 { Thread.sleep(forTimeInterval: pause) }
        }
    }

    private func reportMissingKey(_ character: Character) {
        dumpHierarchy("missing-\(character)")
        XCTFail("key \(character) was not on screen")
    }

    private func tapSpace() {
        app.buttons["Space"].firstMatch.tap()
    }

    /// Types a sentence and makes sure the pad really ends up holding it.
    ///
    /// The surface drops the occasional tap — one sent while the keys are
    /// still resizing lands on the gap a shrinking key left behind — so this
    /// re-types whatever is missing rather than failing. A frame showing text
    /// the app never produced would be worse than a slow run.
    ///
    /// Compared without case: the scripts are lowercase, and the keyboard's
    /// autocapitalisation puts the first letter of a sentence up itself.
    private func type(_ sentence: String, pause: TimeInterval = 0) {
        for _ in 0..<3 {
            let typed = padText
            if typed.lowercased() == sentence.lowercased() { return }
            if sentence.lowercased().hasPrefix(typed.lowercased()) {
                typeRun(String(sentence.dropFirst(typed.count)), pause: pause)
            } else {
                // Something other than a dropped key — start the line again.
                clearPad()
                typeRun(sentence, pause: pause)
            }
            waitForPad(sentence, failing: false)
        }
        waitForPad(sentence)
    }

    private func waitForPad(_ expected: String, failing: Bool = true) {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline && padText.lowercased() != expected.lowercased() {
            Thread.sleep(forTimeInterval: 0.2)
        }
        if failing {
            XCTAssertEqual(
                padText.lowercased(), expected.lowercased(), "the pad did not end up with the text the shot needs")
        }
    }

    private func openPracticePad() {
        tab("Practice")
        XCTAssertTrue(app.buttons["Space"].firstMatch.waitForExistence(timeout: 30), "no keyboard")
        settle()
    }

    private func clearPad() {
        let clear = app.buttons["Clear"].firstMatch
        if clear.isEnabled { clear.tap() }
        waitForPad("")
    }

    private func setResizeStrength(_ title: String) {
        tab("Settings")
        let option = app.buttons[title].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 20), "no \(title) option")
        option.tap()
        Thread.sleep(forTimeInterval: 0.4)
    }

    /// Lets SwiftUI's resize animation (0.18s) settle before the shutter.
    private func settle() {
        Thread.sleep(forTimeInterval: 0.8)
    }

    // MARK: The listing

    /// The one frame the listing still takes from the container app. The
    /// rest of the screenshots come from `StoreMessagesCaptureTests`, where
    /// the keyboard is doing its job inside Messages — which is the product.
    func testCaptureScreenshots() throws {
        setResizeStrength("Aggressive")
        tab("Settings")
        settle()
        capture("06-settings")
    }

    /// A single continuous take for the App Store preview video. Paced for
    /// watching, not for speed; the host records the screen around it.
    func testPerformPreviewTake() throws {
        openPracticePad()
        Thread.sleep(forTimeInterval: 1.5)

        // Beat 1: the keys reshape as the word narrows.
        typeRun("meet me at the sch", pause: 0.45)
        Thread.sleep(forTimeInterval: 1.5)

        // Beat 2: one tap finishes it.
        app.buttons.matching(identifier: "suggestion-0").firstMatch.tap()
        Thread.sleep(forTimeInterval: 1.8)

        // Beat 4: a saved name, inserted verbatim.
        app.buttons["panel-names"].tap()
        Thread.sleep(forTimeInterval: 1.4)
        app.buttons["Insert Mom"].tap()
        Thread.sleep(forTimeInterval: 1.6)

        // Beat 5: a phrase assembled from big chips and inserted.
        app.buttons["panel-phrases"].tap()
        Thread.sleep(forTimeInterval: 1.2)
        app.buttons["Use phrase Running late"].tap()
        Thread.sleep(forTimeInterval: 1.2)
        app.buttons["Fill name with Mom"].tap()
        Thread.sleep(forTimeInterval: 1.0)
        app.buttons["Fill minutes with 10"].tap()
        Thread.sleep(forTimeInterval: 1.0)
        app.buttons["Fill place with the clinic"].tap()
        Thread.sleep(forTimeInterval: 1.4)
        app.buttons.matching(identifier: "insertSentence").firstMatch.tap()
        Thread.sleep(forTimeInterval: 3.0)
    }
}
