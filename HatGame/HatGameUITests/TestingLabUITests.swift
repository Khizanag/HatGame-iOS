//
//  TestingLabUITests.swift
//  HatGameUITests
//

import XCTest

/// The Testing Lab in debug builds: it opens with this build's notes, its
/// shortcuts go where they say, and it opens over a game as well as Home.
final class TestingLabUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTheLabOpensWithNotesAndStartsAQuickGame() throws {
        let app = launch(["-openTestingLab", "YES"])
        XCTAssertTrue(app.staticTexts["In This Build"].waitForExistence(timeout: 10))

        let quickGame = app.buttons["Start a Quick Game"]
        for _ in 0 ..< 6 where !quickGame.isHittable { app.swipeUp() }
        quickGame.tap()

        XCTAssertTrue(app.buttons["nextTeam.play"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testTheDeveloperScreenOpensTheLab() throws {
        let app = launch(["-uiTestScreen", "developer"])
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        // The form builds rows as they scroll in; the lab's is the last one.
        let row = app.buttons["developer.testingLab"]
        for _ in 0 ..< 6 where !(row.exists && row.isHittable) { app.swipeUp() }
        row.tap()

        XCTAssertTrue(app.staticTexts["In This Build"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testANoteGoesWhereItsChangeIs() throws {
        let app = launch(["-openTestingLab", "YES"])
        let note = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'App Icon cards'")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 10))
        note.tap()

        XCTAssertTrue(app.staticTexts["Choose the vibe that appears on your Home Screen."].waitForExistence(timeout: 10))
    }
}

// MARK: - Helpers
private extension TestingLabUITests {
    @MainActor
    func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments + ["-uiTestResetState", "-uiTestDisableAnimations"]
        app.launch()
        return app
    }
}
