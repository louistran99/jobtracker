import XCTest

/// One test per link-field state. Each launch picks a canned posting result, so no test touches the network.
@MainActor
final class LinkFetchUITests: XCTestCase {
    private static let ashbyLink = "https://jobs.ashbyhq.com/grow-therapy/eb6b5a30-a02d-47b7-83ac-51839574d2d2"

    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
    }

    func testFetchingKeepsTheFormEditable() {
        openSheetAndEnterLink(stub: "fetching")

        wait(for: linkStatus, "label", toEqual: "Fetching details")
        wait(
            for: app.staticTexts["linkFooter"],
            "label",
            toEqual: "Fetching details. You can keep filling in the form."
        )

        type("Grow Therapy", into: app.textFields["companyField"])
        type("Engineering Manager", into: app.textFields["roleField"])
        XCTAssertTrue(app.buttons["addButton"].isEnabled, "A fetch in flight never blocks Add")
        XCTAssertEqual(linkStatus.label, "Fetching details", "The fetch is still in flight")
    }

    func testFoundFillsCompanyAndRole() {
        openSheetAndEnterLink(stub: "found")

        wait(for: linkStatus, "label", toEqual: "Posting found")
        wait(for: app.textFields["companyField"], "value", toEqual: "Grow Therapy")
        wait(for: app.textFields["roleField"], "value", toEqual: "Engineering Manager, Momentum")

        let summary = app.descendants(matching: .any).matching(identifier: "postingSummary").firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("Grow Therapy"), "Summary label was \(summary.label)")
        XCTAssertTrue(summary.label.contains("New York · Remote"), "Summary label was \(summary.label)")
        XCTAssertEqual(
            app.staticTexts["detailsFooter"].label,
            "Company and role were filled in from the posting. Edit them if they're wrong."
        )
        XCTAssertFalse(app.staticTexts["linkFooter"].exists, "The found state has no link footer")

        app.buttons["addButton"].tap()
        let row = app.descendants(matching: .any).matching(identifier: "applicationRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Grow Therapy"), "Row label was \(row.label)")
    }

    func testCouldNotReadKeepsTheFormUsable() {
        openSheetAndEnterLink(stub: "couldNotRead")

        wait(for: linkStatus, "label", toEqual: "Couldn't read posting")
        wait(
            for: app.staticTexts["linkFooter"],
            "label",
            toEqual: "This posting couldn't be read. Fill in the company and role below. The link is still saved."
        )
        XCTAssertFalse(app.buttons["addButton"].isEnabled)

        type("Grow Therapy", into: app.textFields["companyField"])
        type("Engineering Manager", into: app.textFields["roleField"])
        XCTAssertTrue(app.buttons["addButton"].isEnabled)
        app.buttons["addButton"].tap()

        let row = app.descendants(matching: .any).matching(identifier: "applicationRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Grow Therapy"), "Row label was \(row.label)")
    }

    func testAlreadyAddedLinkShowsWhenItWasAdded() {
        // Every fetch in this launch hangs, so reaching "Already added" proves the second link was never fetched.
        app.launchEnvironment["POSTING_STUB"] = "fetching"
        app.launch()
        let dayBefore = Date.now.formatted(.dateTime.month(.abbreviated).day())

        app.buttons["newApplicationButton"].tap()
        type(Self.ashbyLink, into: app.textFields["linkField"])
        type("Grow Therapy", into: app.textFields["companyField"])
        type("Engineering Manager", into: app.textFields["roleField"])
        app.buttons["addButton"].tap()
        XCTAssertTrue(app.buttons["newApplicationButton"].waitForExistence(timeout: 5))

        app.buttons["newApplicationButton"].tap()
        type("\(Self.ashbyLink)?departmentId=8f5e4c2a&utm_source=linkedin", into: app.textFields["linkField"])

        wait(for: linkStatus, "label", toEqual: "Already added")
        let note = app.staticTexts["duplicateNote"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        let dayAfter = Date.now.formatted(.dateTime.month(.abbreviated).day())
        // The test may run across midnight, so either day is right.
        XCTAssertTrue(
            [dayBefore, dayAfter].map { "You added this on \($0)" }.contains(note.label),
            "Note was \(note.label)"
        )
        XCTAssertFalse(app.staticTexts["linkFooter"].exists, "The already-added state has no link footer")

        type("Grow Therapy", into: app.textFields["companyField"])
        type("Engineering Manager", into: app.textFields["roleField"])
        XCTAssertFalse(app.buttons["addButton"].isEnabled, "A link that was already added can't be added again")
    }

    private var linkStatus: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "linkStatus").firstMatch
    }

    private func openSheetAndEnterLink(stub: String) {
        app.launchEnvironment["POSTING_STUB"] = stub
        app.launch()
        app.buttons["newApplicationButton"].tap()
        type(Self.ashbyLink, into: app.textFields["linkField"])
    }
}
