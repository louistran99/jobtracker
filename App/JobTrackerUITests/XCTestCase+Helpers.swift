import XCTest

extension XCTestCase {
    /// Waits for `field`, taps it, and types `text`.
    @MainActor
    func type(_ text: String, into field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "\(field) never appeared", file: file, line: line)
        field.tap()
        field.typeText(text)
    }

    /// Waits until `element`'s `attribute` (such as `label` or `value`) equals `expected`.
    @MainActor
    func wait(
        for element: XCUIElement,
        _ attribute: String,
        toEqual expected: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "%K == %@", attribute, expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(
            result,
            .completed,
            "\(element) \(attribute) never became \"\(expected)\"",
            file: file,
            line: line
        )
    }
}
