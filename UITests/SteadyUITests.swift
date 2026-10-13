import XCTest

/// Drives the real app on the simulator to check the acceptance criteria that
/// are about behaviour rather than appearance.
///
/// Everything here exercises the Practice tab, which hosts exactly the same
/// `KeyboardSurface` the keyboard extension does — same keys, same chips, same
/// Names and Phrases panels — just writing into an in-app buffer instead of
/// another app's text field.
final class SteadyUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITestResetState", "1"]
        app.launch()
        app.tabBars.buttons["Practice"].tap()
    }

    private var padText: String {
        app.staticTexts.matching(identifier: "practicePadText").firstMatch.label
    }

    /// Waits for each key first: the first tap of a test can land before the
    /// keyboard has rendered, and a tap sent then finds nothing.
    private func typeKeys(_ letters: String) {
        for letter in letters {
            let key = app.buttons[String(letter)].firstMatch
            XCTAssertTrue(key.waitForExistence(timeout: 5), "key \(letter) was not on screen")
            key.tap()
        }
    }

    // US-003: the keyboard reshapes — impossible letters go away.
    func testImpossibleKeysDisappearAsTheWordNarrows() {
        XCTAssertTrue(app.buttons["q"].exists, "every letter should be available before typing")

        typeKeys("th")

        // In the bundled dictionary only a, c, e, i, l, o, r, u, w, y can follow "th".
        XCTAssertTrue(app.buttons["e"].exists, "e must stay — it's the likeliest continuation")
        XCTAssertFalse(app.buttons["q"].exists, "q cannot continue \"th\" and must be hidden")
        XCTAssertFalse(app.buttons["z"].exists, "z cannot continue \"th\" and must be hidden")
    }

    // US-003: keys keep their position; the row never reorders.
    func testRowKeepsItsOrderWhileResizing() {
        typeKeys("th")

        let e = app.buttons["e"].frame
        let r = app.buttons["r"].frame
        let i = app.buttons["i"].frame
        XCTAssertLessThan(e.minX, r.minX, "e must stay left of r")
        XCTAssertLessThan(r.minX, i.minX, "r must stay left of i")
    }

    // US-004: tapping a completion chip replaces the fragment and adds a space.
    func testCompletionChipInsertsWholeWordAndTrailingSpace() {
        typeKeys("th")

        let chip = app.buttons.matching(identifier: "suggestion-0").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 2))
        let word = chip.label.replacingOccurrences(of: "Complete word as ", with: "")
        chip.tap()

        // Auto-capitalisation put the first letter up, and the completion
        // keeps the casing of what was typed.
        let expected = word.prefix(1).uppercased() + word.dropFirst() + " "
        XCTAssertEqual(padText, expected, "the chip should replace \"Th\" with the full word plus a space")
    }

    // US-004: after a space the chips become next-word predictions.
    func testChipsBecomeNextWordPredictionsAfterASpace() {
        typeKeys("i")
        app.buttons["Space"].tap()

        let chip = app.buttons.matching(identifier: "suggestion-0").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 2))
        XCTAssertTrue(chip.label.hasPrefix("Insert next word"), "chips should switch to next-word mode after a space")
    }

    // US-008: a saved name inserts verbatim, and the keys come straight back.
    func testQuickInsertNameInsertsItsExactText() {
        app.buttons["panel-names"].tap()
        app.buttons["Insert Mom"].tap()

        XCTAssertEqual(padText, "Mom ")
        XCTAssertTrue(
            app.buttons["Space"].waitForExistence(timeout: 2),
            "inserting a name should return the surface to the keyboard")
        XCTAssertFalse(app.buttons["Insert Mom"].exists, "the Names panel should no longer be showing")
    }

    // US-009: the guided fill flow assembles the sentence and inserts it the
    // moment the last blank is answered, then returns to the keyboard.
    func testPhraseFillFlowInsertsAssembledSentence() {
        app.buttons["panel-phrases"].tap()
        app.buttons["Use phrase Running late"].tap()

        // Blank 1 of 3 — {name}, drawn from the Names list.
        XCTAssertTrue(app.staticTexts["Blank 1 of 3"].waitForExistence(timeout: 2))
        app.buttons["Fill name with Mom"].tap()

        // Blank 2 of 3 — {minutes}.
        XCTAssertTrue(app.staticTexts["Blank 2 of 3"].waitForExistence(timeout: 2))
        app.buttons["Fill minutes with 10"].tap()

        // Blank 3 of 3 — {place}. Answering it is what inserts.
        XCTAssertTrue(app.staticTexts["Blank 3 of 3"].waitForExistence(timeout: 2))
        app.buttons["Fill place with the clinic"].tap()

        XCTAssertTrue(
            app.buttons["Space"].waitForExistence(timeout: 2),
            "answering the last blank should return the surface to the keyboard")
        XCTAssertEqual(padText, "Hi Mom, I'm running 10 late for the clinic.")
    }

    // US-009: a typed value for a blank behaves like a picked one — Done goes
    // back to the remaining blanks, and the last answer inserts.
    func testPhraseFillFlowAcceptsATypedValueForABlank() {
        app.buttons["panel-phrases"].tap()
        app.buttons["Use phrase Need a hand"].tap()

        XCTAssertTrue(app.staticTexts["Blank 1 of 2"].waitForExistence(timeout: 2))
        app.buttons["Fill name with Sarah"].tap()

        // Blank 2 of 2 — {task}, typed rather than picked.
        XCTAssertTrue(app.staticTexts["Blank 2 of 2"].waitForExistence(timeout: 2))
        app.buttons["Type a value for task"].tap()
        typeKeys("tea")
        app.buttons["Done"].tap()

        // The keys were already showing under the draft bar, so the bar going
        // away is what says the surface is back on the plain keyboard.
        XCTAssertFalse(app.buttons["Done"].waitForExistence(timeout: 1), "the draft bar should be gone")
        XCTAssertTrue(app.buttons["Space"].exists, "the keyboard should still be showing")
        XCTAssertEqual(padText, "Sarah, could you help me with tea when you get a chance?")
    }

    // US-006: turning resizing off stops keys from being hidden, and the
    // setting survives the trip through the shared store.
    func testResizeStrengthOffKeepsEveryKeyVisible() {
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Off"].tap()

        app.tabBars.buttons["Practice"].tap()
        typeKeys("th")

        XCTAssertTrue(app.buttons["q"].exists, "with resizing off, no key should be hidden")
        XCTAssertTrue(app.buttons["z"].exists)
    }

    // US-007: the practice pad echoes what was typed. The first letter is a
    // capital: the pad is a sentence field, and shift is up when it starts.
    func testPracticePadShowsTypedText() {
        typeKeys("the")
        XCTAssertEqual(padText, "The")
    }

    // Autocapitalisation: shift is up for the first letter only, and comes
    // back down for the next word.
    func testAutocapitalisationLiftsOnlyTheFirstLetter() {
        typeKeys("hi")
        app.buttons["Space"].tap()
        typeKeys("ok")
        XCTAssertEqual(padText, "Hi ok")
    }

    // Autocorrection: a misspelling is fixed on the space, and backspace
    // right after puts the original back.
    func testAutocorrectFixesOnSpaceAndBackspaceReverts() {
        typeKeys("teh")
        app.buttons["Space"].tap()
        let corrected = padText
        XCTAssertNotEqual(corrected, "Teh ", "the space should have corrected the word")
        XCTAssertTrue(corrected.hasSuffix(" "), "the space should still follow the corrected word")
        app.buttons["Delete"].tap()
        XCTAssertEqual(padText, "Teh", "backspace right after a correction should put the original back")
    }
}
