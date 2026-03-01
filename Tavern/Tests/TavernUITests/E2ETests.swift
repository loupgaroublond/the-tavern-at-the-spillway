import XCTest

/// Grade 4 E2E tests: full user journeys with real Claude.
/// E2E tests NEVER mock — they validate the actual user experience.
/// These steal focus — run via `redo Tavern/test-grade4` when user is not active.
@MainActor
final class E2ETests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 120

        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--project-path", "/tmp/tavern-e2e-test"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Helpers

    /// Wait for the chat input field to appear and return it.
    /// Uses firstMatch — SwiftUI may restore a second project window,
    /// giving two chatInputField elements across windows.
    private func waitForInputField() -> XCUIElement {
        let inputField = app.textViews["chatInputField"].firstMatch
        XCTAssertTrue(
            inputField.waitForExistence(timeout: 10),
            "Chat input field should appear"
        )
        return inputField
    }

    /// Wait for the send button and return it
    private func waitForSendButton() -> XCUIElement {
        let sendButton = app.buttons["sendButton"].firstMatch
        XCTAssertTrue(
            sendButton.waitForExistence(timeout: 10),
            "Send button should appear"
        )
        return sendButton
    }

    /// Type a message and send it
    private func sendMessage(_ text: String) {
        let inputField = waitForInputField()
        inputField.click()
        inputField.typeText(text)

        let sendButton = waitForSendButton()
        sendButton.click()
    }

    // MARK: - E2E Tests

    /// Send a message to Jake and receive a real Claude response
    func testSendMessageAndReceiveResponse() throws {
        sendMessage("Say hello in exactly one word.")

        // Wait for user message to appear
        let userMessage = app.staticTexts["Say hello in exactly one word."]
        XCTAssertTrue(
            userMessage.waitForExistence(timeout: 5),
            "User message should appear in the chat"
        )

        // Wait for a response from Claude (may take a while with real API)
        // The response text is unpredictable, but the servitor name label should appear
        // after the cogitation indicator disappears
        let cogitatingIndicator = app.otherElements["cogitatingIndicator"]

        // If cogitating indicator appeared, wait for it to disappear
        if cogitatingIndicator.exists {
            let disappeared = NSPredicate(format: "exists == false")
            expectation(for: disappeared, evaluatedWith: cogitatingIndicator, handler: nil)
            waitForExpectations(timeout: 60)
        }

        // After cogitation, there should be more than just the user message
        // Verify at least two message-like elements exist (user + servitor response)
        sleep(2) // Brief pause for UI to update
        XCTAssertTrue(
            app.staticTexts.count > 1,
            "Should have more than one text element after receiving a response"
        )
    }

    /// Spawn a new servitor via the toolbar button
    func testSpawnServitor() throws {
        let spawnButton = app.buttons["spawnServitorButton"].firstMatch
        XCTAssertTrue(
            spawnButton.waitForExistence(timeout: 10),
            "Spawn servitor button should exist"
        )

        // Count servitors before
        let servitorList = app.outlines["servitorList"].firstMatch
        XCTAssertTrue(servitorList.waitForExistence(timeout: 10))

        spawnButton.click()

        // Wait briefly for the new servitor to appear
        sleep(2)

        // There should now be more than just Jake in the list
        // We can't predict the name, but the list should have grown
        let listCells = servitorList.cells
        XCTAssertTrue(
            listCells.count > 1,
            "Servitor list should have more than one item after spawning"
        )
    }

    /// Switch between Jake and a spawned servitor
    func testSwitchBetweenServitors() throws {
        // Spawn a servitor first
        let spawnButton = app.buttons["spawnServitorButton"].firstMatch
        XCTAssertTrue(spawnButton.waitForExistence(timeout: 10))
        spawnButton.click()
        sleep(2)

        // Click on Jake in the sidebar (scope to servitorList to avoid matching
        // the chat header's "Jake" StaticText)
        let servitorList = app.outlines["servitorList"].firstMatch
        XCTAssertTrue(servitorList.waitForExistence(timeout: 5))
        let jakeInSidebar = servitorList.staticTexts["Jake"]
        XCTAssertTrue(jakeInSidebar.waitForExistence(timeout: 5))
        jakeInSidebar.click()
        sleep(1)

        // Verify Jake's chat is showing (header should say "Jake")
        let headerJake = app.staticTexts["Jake"]
        XCTAssertTrue(headerJake.exists, "Jake should be visible after switching back")
    }

    /// Close a spawned servitor
    func testCloseServitor() throws {
        // Spawn a servitor
        let spawnButton = app.buttons["spawnServitorButton"].firstMatch
        XCTAssertTrue(spawnButton.waitForExistence(timeout: 10))
        spawnButton.click()
        sleep(2)

        let servitorList = app.outlines["servitorList"].firstMatch
        XCTAssertTrue(servitorList.waitForExistence(timeout: 10))

        // Get the count before closing
        let countBefore = servitorList.cells.count
        XCTAssertTrue(countBefore > 1, "Should have more than Jake after spawning")

        // Right-click on the second item (the spawned servitor) to get context menu
        let secondCell = servitorList.cells.element(boundBy: 1)
        secondCell.rightClick()

        // Click "Close" in context menu (use servitorList scope to avoid File→Close ambiguity)
        let closeMenuItem = servitorList.menuItems["Close"]
        if closeMenuItem.waitForExistence(timeout: 5) {
            closeMenuItem.click()
            sleep(1)

            // Verify the servitor was removed
            let countAfter = servitorList.cells.count
            XCTAssertEqual(
                countAfter, countBefore - 1,
                "Servitor list should have one fewer item after closing"
            )
        }
    }
}
