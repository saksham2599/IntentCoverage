import XCTest

@MainActor
final class TaskFlowBaselineTests: XCTestCase {
    func testFiveActionsAndPersistence() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--test-store", UUID().uuidString]
        app.launch()
        let input = app.textFields["newTaskTitle"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap(); input.typeText("Orchid launch")
        app.buttons["addTask"].tap()
        XCTAssertTrue(app.staticTexts["Orchid launch"].waitForExistence(timeout: 5))
        input.tap(); input.typeText("Buy milk")
        app.buttons["addTask"].tap()
        XCTAssertTrue(app.staticTexts["Buy milk"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Orchid launch"].waitForExistence(timeout: 10))
        let search = app.textFields["searchTasks"]
        search.tap(); search.typeText("ORCHID")
        let onlyOrchid = NSPredicate(format: "exists == false")
        expectation(for: onlyOrchid, evaluatedWith: app.staticTexts["Buy milk"])
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.staticTexts["Orchid launch"].exists)
        // Dismiss keyboard so row actions stay visible on the iPhone 12.
        app.swipeDown()
        app.buttons["Complete Orchid launch"].tap()
        XCTAssertTrue(app.buttons["Completed Orchid launch"].waitForExistence(timeout: 5))
        app.buttons["Plan Orchid launch"].tap()
        XCTAssertTrue(app.buttons["saveDueDate"].waitForExistence(timeout: 5))
        app.buttons["saveDueDate"].tap()
        XCTAssertTrue(app.otherElements["dueDate-Orchid launch"].waitForExistence(timeout: 5) || app.staticTexts["dueDate-Orchid launch"].exists)
        app.buttons["Plan Orchid launch"].tap()
        app.buttons["removeDueDate"].tap()
        app.buttons["Clear search"].tap()
        XCTAssertTrue(app.staticTexts["Buy milk"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "TaskFlow-five-actions"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["Delete Orchid launch"].tap()
        XCTAssertTrue(app.alerts.buttons["Cancel"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Orchid launch"].exists)
        app.buttons["Delete Orchid launch"].tap()
        XCTAssertTrue(app.alerts.buttons["Delete task"].waitForExistence(timeout: 5))
        app.alerts.buttons["Delete task"].tap()
        expectation(for: onlyOrchid, evaluatedWith: app.staticTexts["Orchid launch"])
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.staticTexts["Buy milk"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Buy milk"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Orchid launch"].exists)
    }
}
