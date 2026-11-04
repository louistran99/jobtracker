import XCTest

@MainActor
final class AddApplicationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testAddingAnApplicationShowsItsRow() {
        app.buttons["newApplicationButton"].tap()

        let addButton = app.buttons["addButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertFalse(addButton.isEnabled, "Add stays disabled until company and role are filled")

        type("Stripe", into: app.textFields["companyField"])
        XCTAssertFalse(addButton.isEnabled, "Add stays disabled with only a company")
        type("EM, Mobile Platform", into: app.textFields["roleField"])
        XCTAssertTrue(addButton.isEnabled)

        let stagePicker = app.buttons["stagePicker"]
        XCTAssertTrue(stagePicker.waitForExistence(timeout: 5))
        stagePicker.tap()
        let onsite = app.buttons["Onsite"]
        XCTAssertTrue(onsite.waitForExistence(timeout: 5))
        onsite.tap()

        addButton.tap()

        let row = app.descendants(matching: .any).matching(identifier: "applicationRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Stripe"), "Row label was \(row.label)")
        XCTAssertTrue(row.label.contains("EM, Mobile Platform"), "Row label was \(row.label)")
        XCTAssertTrue(row.label.contains("Onsite"), "Row label was \(row.label)")
        XCTAssertFalse(addButton.exists, "The sheet closes after Add")
    }

    func testCancellingADirtyFormAsksBeforeDiscarding() {
        app.buttons["newApplicationButton"].tap()
        type("Stripe", into: app.textFields["companyField"])

        app.buttons["cancelButton"].tap()
        let prompt = app.alerts["Discard this application?"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))

        prompt.buttons["Keep Editing"].tap()
        XCTAssertTrue(app.buttons["addButton"].exists, "Keep Editing returns to the sheet")

        app.buttons["cancelButton"].tap()
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        prompt.buttons["Discard"].tap()
        XCTAssertTrue(app.staticTexts["No Applications"].waitForExistence(timeout: 5))
    }

    func testCancellingACleanFormClosesImmediately() {
        app.buttons["newApplicationButton"].tap()
        let cancelButton = app.buttons["cancelButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))

        cancelButton.tap()

        XCTAssertTrue(app.staticTexts["No Applications"].waitForExistence(timeout: 5))
    }

    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
    }
}
