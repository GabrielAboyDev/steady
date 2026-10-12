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

    private func typeKeys(_ letters: String) {
        for letter in letters {
            app.buttons[String(letter)].firstMatch.tap()
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

        XCTAssertEqual(padText, word + " ", "the chip should replace \"th\" with the full word plus a space")
    }

    // US-004: after a space the chips become next-word predictions.
    func testChipsBecomeNextWordPredictionsAfterASpace() {
        typeKeys("i")
        app.buttons["Space"].tap()

        let chip = app.buttons.matching(identifier: "suggestion-0").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 2))
        XCTAssertTrue(chip.label.hasPrefix("Insert next word"), "chips should switch to next-word mode after a space")
    }

    // US-008: a saved name inserts verbatim.
    func testQuickInsertNameInsertsItsExactText() {
        app.buttons["panel-names"].tap()
        app.buttons["Insert Mom"].tap()

        XCTAssertEqual(padText, "Mom ")
    }

    // US-009: the guided fill flow assembles and inserts the sentence.
    func testPhraseFillFlowInsertsAssembledSentence() {
        app.buttons["panel-phrases"].tap()
        app.buttons["Use phrase Running late"].tap()

        // Blank 1 of 3 — {name}, drawn from the Names list.
        XCTAssertTrue(app.staticTexts["Blank 1 of 3"].waitForExistence(timeout: 2))
        app.buttons["Fill name with Mom"].tap()

        // Blank 2 of 3 — {minutes}.
        XCTAssertTrue(app.staticTexts["Blank 2 of 3"].waitForExistence(timeout: 2))
        app.buttons["Fill minutes with 10"].tap()

        // Blank 3 of 3 — {place}.
        XCTAssertTrue(app.staticTexts["Blank 3 of 3"].waitForExistence(timeout: 2))
        app.buttons["Fill place with the clinic"].tap()

        let insert = app.buttons.matching(identifier: "insertSentence").firstMatch
        XCTAssertTrue(insert.waitForExistence(timeout: 2))
        insert.tap()

        XCTAssertEqual(padText, "Hi Mom, I'm running 10 late for the clinic.")
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

    // US-007: the practice pad echoes what was typed.
    func testPracticePadShowsTypedText() {
        typeKeys("the")
        XCTAssertEqual(padText, "the")
    }
}
