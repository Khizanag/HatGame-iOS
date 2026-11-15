//
//  HatGameUITests.swift
//  HatGameUITests
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import XCTest

/// Single-device game flows, driven through accessibility identifiers. The
/// DEBUG `-uiTestScreen game` hook opens a started two-team, two-word game.
final class HatGameUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyingTheHatAdvancesToRoundTwo() throws {
        let app = launchIntoTestGame()
        let roundTitle = app.staticTexts["nextTeam.roundTitle"]
        XCTAssertTrue(roundTitle.waitForExistence(timeout: 10))
        let roundOneTitle = roundTitle.label

        app.buttons["nextTeam.play"].tap()
        let gotIt = app.buttons["game.gotIt"]
        XCTAssertTrue(gotIt.waitForExistence(timeout: 5))
        gotIt.tap()
        gotIt.tap()

        XCTAssertTrue(app.staticTexts["turnResults.title"].waitForExistence(timeout: 5))
        app.buttons["turnResults.continue"].tap()

        XCTAssertTrue(roundTitle.waitForExistence(timeout: 5))
        XCTAssertNotEqual(roundTitle.label, roundOneTitle)
        XCTAssertTrue(roundTitle.label.contains("2"), "Expected round two, got \(roundTitle.label)")
    }

    @MainActor
    func testSwipeBackIsDisabledInsideTheGameLoop() throws {
        let app = launchIntoTestGame()
        let play = app.buttons["nextTeam.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))

        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        edge.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))

        XCTAssertTrue(play.waitForExistence(timeout: 2))
        XCTAssertTrue(play.isHittable)
        XCTAssertFalse(app.navigationBars.buttons["BackButton"].exists)
    }

    @MainActor
    func testKilledGameIsOfferedForResumeAndComesBackPaused() throws {
        let app = launchIntoTestGame()
        let play = app.buttons["nextTeam.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        play.tap()
        let gotIt = app.buttons["game.gotIt"]
        XCTAssertTrue(gotIt.waitForExistence(timeout: 5))
        gotIt.tap()
        // Saves are asynchronous; give the write a moment before killing the app.
        Thread.sleep(forTimeInterval: 1)
        app.terminate()

        let relaunched = XCUIApplication()
        relaunched.launch()
        let resume = relaunched.buttons["home.resumeButton"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        resume.tap()

        let restoredGotIt = relaunched.buttons["game.gotIt"]
        XCTAssertTrue(restoredGotIt.waitForExistence(timeout: 5))
        XCTAssertFalse(restoredGotIt.isEnabled, "A restored turn should come back paused")

        relaunched.terminate()
        launchClearingSavedGame().terminate()
    }
}

// MARK: - Helpers
private extension HatGameUITests {
    @MainActor
    func launchIntoTestGame() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestScreen", "game", "-uiTestResetState", "-uiTestDisableAnimations"]
        app.launch()
        return app
    }

    @MainActor
    func launchClearingSavedGame() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetState"]
        app.launch()
        XCTAssertTrue(app.buttons["home.resumeButton"].waitForNonExistence(timeout: 5))
        return app
    }
}
