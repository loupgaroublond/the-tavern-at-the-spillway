import XCTest

/// Grade 4 smoke tests: verify the app launches and renders basic UI.
/// These steal focus — run via `redo Tavern/test-grade4` when user is not active.
final class SmokeTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--project-path", "/tmp/tavern-ui-test"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Smoke Tests

    /// App launches and a window appears
    func testAppLaunches() throws {
        XCTAssertTrue(app.windows.count > 0, "App should have at least one window")
    }

    /// Jake appears in the sidebar agent list
    func testJakeAppearsInSidebar() throws {
        let jakeText = app.staticTexts["Jake"]
        XCTAssertTrue(
            jakeText.waitForExistence(timeout: 10),
            "Jake should appear in the sidebar"
        )
    }

    /// Chat input field exists and is enabled
    func testInputFieldExists() throws {
        let inputField = app.textFields["chatInputField"]
        XCTAssertTrue(
            inputField.waitForExistence(timeout: 10),
            "Chat input field should exist"
        )
        XCTAssertTrue(inputField.isEnabled, "Chat input field should be enabled")
    }

    /// Can type text into the input field
    func testCanTypeInput() throws {
        let inputField = app.textFields["chatInputField"]
        XCTAssertTrue(
            inputField.waitForExistence(timeout: 10),
            "Chat input field should exist"
        )

        inputField.click()
        inputField.typeText("Hello from XCUITest")

        XCTAssertEqual(
            inputField.value as? String,
            "Hello from XCUITest",
            "Typed text should appear in the input field"
        )
    }
}
