//
//  AccessibilityAuditUITests.swift
//  HatGameUITests
//

import XCTest

/// Runs Apple's accessibility audit on every screen the DEBUG deep link can
/// open, at the default text size and the largest accessibility size
/// (constitution article 18). Each issue fails the test with its element.
final class AccessibilityAuditUITests: XCTestCase {
    /// `nil` is Home; the rest are `-uiTestScreen` values.
    private static let screens: [String?] = [
        nil, "rules", "history", "recap", "settings", "defaults", "appIcon", "developer", "fillHat",
        "randomization", "game",
    ]

    private static let largestSize = "UICTContentSizeCategoryAccessibilityXXXL"

    /// Issues already recorded as open in CONSTITUTION.md ("Not yet
    /// conforming"), by screen and kind. They're expected until fixed; any
    /// other issue fails, so the audit only ratchets toward passing.
    private static let knownOpen: [String: Set<String>] = [
        "contrast": ["home", "fillHat", "appIcon", "randomization", "developer"],
        "dynamicType": ["defaults", "developer", "appIcon"],
        "textClipped": ["settings", "defaults"],
        "inaccessibleText": ["fillHat", "defaults"],
    ]

    private static func isKnownOpen(screen: String, issue: XCUIAccessibilityAuditIssue) -> Bool {
        let kind: String
        switch issue.auditType {
        case .contrast: kind = "contrast"
        case .dynamicType: kind = "dynamicType"
        case .textClipped: kind = "textClipped"
        default:
            kind = issue.compactDescription.localizedCaseInsensitiveContains("inaccessible text")
                ? "inaccessibleText"
                : "other"
        }
        return knownOpen[kind]?.contains(screen) ?? false
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testEveryScreenPassesTheAuditAtTheDefaultSize() throws {
        try auditEveryScreen(contentSize: nil)
    }

    @MainActor
    func testEveryScreenPassesTheAuditAtTheLargestTextSize() throws {
        try auditEveryScreen(contentSize: Self.largestSize)
    }
}

// MARK: - Audit
private extension AccessibilityAuditUITests {
    @MainActor
    func auditEveryScreen(contentSize: String?) throws {
        for screen in Self.screens {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTestResetState"]
            if let screen {
                app.launchArguments += ["-uiTestScreen", screen]
            }
            if let contentSize {
                app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
            }
            app.launch()
            // Let deep links and entrance animations settle.
            _ = app.wait(for: .runningForeground, timeout: 5)
            sleep(2)

            let screenHeight = app.frame.height
            try app.performAccessibilityAudit { issue in
                // The action bar caps its buttons' text so it never buries the
                // screen: "bars stop growing" (constitution article 15).
                if issue.auditType == .dynamicType, let element = issue.element,
                   element.frame.minY > screenHeight * 0.8 {
                    return true
                }
                // Apple reports these as within tolerance, not as failures.
                if issue.compactDescription.localizedCaseInsensitiveContains("nearly passed") {
                    return true
                }
                let name = screen ?? "home"
                let message = "[\(name)] \(issue.compactDescription) — "
                    + "\(issue.element?.label ?? "no element")"
                if Self.isKnownOpen(screen: name, issue: issue) {
                    XCTExpectFailure("Open under article 18; listed in CONSTITUTION.md", strict: false) {
                        XCTFail(message)
                    }
                } else {
                    XCTFail(message)
                }
                return true
            }
            app.terminate()
        }
    }
}
