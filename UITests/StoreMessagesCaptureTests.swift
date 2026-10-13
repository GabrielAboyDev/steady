import XCTest

/// Captures the listing's main screenshots: Steady running as a real system
/// keyboard inside Messages, which is where people actually use it.
///
/// The container app's practice pad is a safe place to learn the keyboard, but
/// it isn't the product — the product is the keyboard in somebody else's app.
/// These frames show exactly that: a real conversation, real sent messages,
/// and the extension doing the work.
///
/// Needs a simulator that has been through `scripts/enable-keyboard-in-simulator.sh`
/// and has the Simulator app open (the software keyboard never appears
/// otherwise). Skipped unless `STEADY_CAPTURE=1`; drive it through
/// `scripts/capture-store-assets.sh`.
final class StoreMessagesCaptureTests: XCTestCase {

    private var messages: XCUIApplication!

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

        // Reset the app group so the keyboard's Names and Phrases are the
        // seeded ones, then leave the app in the background.
        let steady = XCUIApplication()
        steady.launchArguments += ["-UITestResetState", "1"]
        steady.launch()
        XCTAssertTrue(steady.staticTexts["Almost ready"].waitForExistence(timeout: 60))
        steady.terminate()

        messages = XCUIApplication(bundleIdentifier: "com.apple.MobileSMS")
        messages.launch()
        Thread.sleep(forTimeInterval: 3)

        // Launching Messages from the test runner leaves a "◀ Steady" chip in
        // the status bar. Going home and reactivating clears it, which matters
        // when the status bar is in every frame.
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2.5)
        messages.activate()
        Thread.sleep(forTimeInterval: 3)
    }

    // MARK: Capture

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

    private func dump(_ name: String) {
        capture("debug-\(name)")
        try? messages.debugDescription.write(
            to: Self.outputDirectory.appendingPathComponent("debug-\(name).txt"),
            atomically: true, encoding: .utf8)
    }

    private func settle(_ seconds: TimeInterval = 1.0) {
        Thread.sleep(forTimeInterval: seconds)
    }

    // MARK: Messages

    private var composeField: XCUIElement {
        messages.textFields["messageBodyField"]
    }

    private var draft: String {
        (composeField.value as? String) ?? ""
    }

    private func openConversation() {
        // Messages restores whatever it was showing last, which after an
        // earlier run is the thread itself rather than the list of them.
        if !composeField.waitForExistence(timeout: 5) {
            let cell = messages.cells.element(boundBy: 0)
            XCTAssertTrue(cell.waitForExistence(timeout: 20), "no conversation in Messages")
            cell.tap()
            XCTAssertTrue(composeField.waitForExistence(timeout: 20), "no compose field")
        }
        composeField.tap()
        settle(2.5)
    }

    /// iOS remembers the last keyboard, so Steady may already be up; otherwise
    /// cycle the globe until its panel toolbar appears.
    private func activateSteady() {
        let marker = messages.buttons["panel-phrases"]
        var switches = 0
        while !marker.exists && switches < 6 {
            let globe = messages.buttons["Next keyboard"].firstMatch
            if globe.waitForExistence(timeout: 4) { globe.tap() }
            switches += 1
            settle(2.0)
        }
        if !marker.waitForExistence(timeout: 5) {
            dump("no-steady")
            XCTFail("Steady never came up — run scripts/enable-keyboard-in-simulator.sh")
        }
    }

    private func key(_ character: Character) -> XCUIElement {
        character == " "
            ? messages.buttons["Space"].firstMatch
            : messages.buttons[String(character)].firstMatch
    }

    private func typeRun(_ text: String) {
        for character in text {
            let button = key(character)
            if !button.waitForExistence(timeout: 3) {
                dump("missing-\(character)")
                XCTFail("key \(character) was not on screen")
                return
            }
            button.tap()
        }
    }

    /// Types into the compose field, re-sending anything the surface dropped.
    ///
    /// Compared without case: the scripts are lowercase, and the keyboard's
    /// autocapitalisation puts the first letter of a sentence up itself.
    private func type(_ text: String) {
        for _ in 0..<3 {
            let current = draft
            if current.lowercased() == text.lowercased() { return }
            if text.lowercased().hasPrefix(current.lowercased()) {
                typeRun(String(text.dropFirst(current.count)))
            } else {
                clearDraft()
                typeRun(text)
            }
            waitForDraft(text, failing: false)
        }
        waitForDraft(text)
    }

    private func waitForDraft(_ expected: String, failing: Bool = true) {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline && draft.lowercased() != expected.lowercased() {
            settle(0.2)
        }
        if failing {
            XCTAssertEqual(
                draft.lowercased(), expected.lowercased(), "the compose field does not hold the shot's text")
        }
    }

    private func clearDraft() {
        let delete = messages.buttons["Delete"].firstMatch
        var guardRail = 0
        while !draft.isEmpty && guardRail < 60 {
            if delete.exists {
                delete.tap()
            } else {
                messages.keys["delete"].firstMatch.tap()
            }
            guardRail += 1
        }
    }

    private func send() {
        let send = messages.buttons["sendButton"].firstMatch
        XCTAssertTrue(send.waitForExistence(timeout: 5), "no send button")
        send.tap()
        settle(3.0)
    }

    /// Whether the surface's panel toolbar can be driven at all.
    ///
    /// On iPad the toolbar comes back with a frame half a point above the
    /// screen — the extension's own coordinate space leaking through rather
    /// than the screen's — and XCUITest will neither tap it nor answer
    /// whether it is hittable, it just throws. The frame is readable though,
    /// and a negative origin is the tell.
    private var panelsAreReachable: Bool {
        let toolbar = messages.buttons["panel-names"].firstMatch
        guard toolbar.waitForExistence(timeout: 5) else { return false }
        return toolbar.frame.minY >= 0
    }

    private func tapInSurface(_ element: XCUIElement, _ description: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "no \(description)")
        element.tap()
    }

    private func panel(_ name: String) {
        tapInSurface(messages.buttons["panel-\(name)"].firstMatch, "\(name) panel")
        settle(1.2)
    }

    // MARK: The listing

    func testCaptureTextingScreenshots() throws {
        openConversation()
        activateSteady()

        // Build a real conversation first, so the frames below have something
        // above them rather than an empty thread.
        type("on my way")
        send()
        type("be there in ten")
        send()

        // 1 — the hero: mid-word, the keys that can't follow already gone.
        type("meet me at the sch")
        XCTAssertTrue(
            messages.buttons.matching(identifier: "suggestion-0").firstMatch
                .waitForExistence(timeout: 5))
        settle(1.0)
        capture("01-texting")

        // 2 — one tap on the chip finishes the word.
        messages.buttons.matching(identifier: "suggestion-0").firstMatch.tap()
        waitForDraft("meet me at the school ")
        settle(1.0)
        capture("02-one-tap")

        send()
        settle(1.5)

        // 3 and 4 — the Names and Phrases panels, which only the iPhone can
        // be driven into. The iPad frames stop at the conversation below.
        if panelsAreReachable {
            panel("names")
            settle(1.0)
            capture("03-names")

            panel("phrases")
            tapInSurface(messages.buttons["Use phrase Running late"], "seeded phrase")
            XCTAssertTrue(messages.staticTexts["Blank 1 of 3"].waitForExistence(timeout: 5))
            tapInSurface(messages.buttons["Fill name with Mom"], "name chip")
            XCTAssertTrue(messages.staticTexts["Blank 2 of 3"].waitForExistence(timeout: 5))
            settle(1.0)
            capture("04-phrases")

            tapInSurface(messages.buttons["Fill minutes with 10"], "minutes chip")
            XCTAssertTrue(messages.staticTexts["Blank 3 of 3"].waitForExistence(timeout: 5))
            // Filling the last blank inserts the sentence and returns to the
            // keys by itself; there is no insert button to tap any more.
            tapInSurface(messages.buttons["Fill place with the clinic"], "place chip")
            waitForDraft("Hi Mom, I'm running 10 late for the clinic.")
            settle(1.5)
            send()
        } else {
            // Give the thread one more line so the conversation frame below
            // still shows a conversation rather than a pair of messages.
            type("thanks")
            send()
        }

        // 5 — the conversation those keystrokes produced.
        settle(2.0)
        capture("05-conversation")
    }

    /// A single continuous take for the App Store preview video: a text
    /// written with Steady, start to finish.
    ///
    /// Deliberately short. A keystroke routed through a keyboard extension
    /// into a host app costs about three and a half seconds under XCUITest,
    /// so a take long enough to spell out a sentence cannot be cut down to
    /// the thirty seconds App Store Connect allows without looking absurd.
    /// Seven letters and a chip tell the same story.
    func testPerformTextingPreviewTake() throws {
        openConversation()
        activateSteady()
        settle(1.5)

        // Beat 1: the keys reshape as the word narrows.
        typeRun("on my w")
        settle(1.6)

        // Beat 2: one tap finishes the word.
        messages.buttons.matching(identifier: "suggestion-0").firstMatch.tap()
        settle(1.4)
        send()
        settle(1.6)

        // Beat 3: a whole sentence out of big chips, then sent. The panels
        // can't be driven on iPad (see `panelsAreReachable`), so the take
        // there ends on a second typed line instead.
        if panelsAreReachable {
            panel("phrases")
            tapInSurface(messages.buttons["Use phrase Running late"], "seeded phrase")
            settle(1.0)
            tapInSurface(messages.buttons["Fill name with Mom"], "name chip")
            settle(0.8)
            tapInSurface(messages.buttons["Fill minutes with 10"], "minutes chip")
            settle(0.8)
            // The last blank inserts the sentence by itself.
            tapInSurface(messages.buttons["Fill place with the clinic"], "place chip")
            settle(1.5)
        } else {
            typeRun("see you th")
            settle(1.4)
            messages.buttons.matching(identifier: "suggestion-0").firstMatch.tap()
            settle(1.2)
        }
        send()
        settle(3.0)
    }
}
