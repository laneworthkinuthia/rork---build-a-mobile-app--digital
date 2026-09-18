import XCTest

/// End-to-end UI flows. Every test starts from a clean slate via the
/// `UITEST_RESET` launch argument; `UITEST_SKIP_ONBOARDING` lands directly in
/// the tab shell where onboarding is not the subject under test.
final class CardexUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAllTabsNavigateToTheirScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_RESET", "UITEST_SKIP_ONBOARDING", "UITEST_LOCAL"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Main tab bar did not appear")

        for label in ["Discover", "Live", "Feed", "Profile"] {
            let tab = tabBar.buttons[label]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "\(label) tab missing")
            tab.tap()
            XCTAssertTrue(
                app.staticTexts[label].waitForExistence(timeout: 5),
                "\(label) screen did not load"
            )
        }
    }

    @MainActor
    func testOnboardingCompletesToMainApp() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_RESET", "UITEST_LOCAL"]
        app.launch()

        let create = app.buttons["Create My Card"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "Onboarding welcome step missing")
        create.tap()

        // Photo step — the default avatar is fine, just continue.
        let photoContinue = app.buttons["Continue"]
        XCTAssertTrue(photoContinue.waitForExistence(timeout: 5))
        photoContinue.tap()

        // Identity step — name is required before continuing.
        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Identity form missing")
        nameField.tap()
        nameField.typeText("Ada Lovelace")
        app.buttons["Continue"].tap()

        // Design step.
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()

        // Privacy step — finishing lands in the main app.
        let finish = app.buttons["Finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()

        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 10),
            "Onboarding did not reach the main app"
        )
    }

    @MainActor
    func testSendMessageFromInbox() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_RESET", "UITEST_SKIP_ONBOARDING", "UITEST_LOCAL"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        tabBar.buttons["Profile"].tap()

        // Open the inbox. The row sits below the fold, so scroll it into view,
        // tap, and verify the screen actually opened — a settling scroll can
        // swallow a tap, so retry a couple of times before failing.
        let navBar = app.navigationBars["Messages"]
        var attempts = 0
        while !navBar.exists && attempts < 4 {
            let row = app.buttons["profile-messages-row"]
            if !row.waitForExistence(timeout: 3) { break }
            if !row.isHittable { app.swipeUp() }
            if row.isHittable { row.tap() }
            _ = navBar.waitForExistence(timeout: 3)
            attempts += 1
        }
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Messages inbox did not open")

        // Seeded thread with a connection (Sarah Okafor).
        let thread = app.buttons["inbox-row"]
        let threadByName = app.staticTexts["Sarah Okafor"]
        let foundThread = thread.waitForExistence(timeout: 6) || threadByName.waitForExistence(timeout: 3)
        XCTAssertTrue(foundThread, "Seeded conversation missing from inbox")
        (thread.exists ? thread : threadByName).tap()

        let field = app.textViews.firstMatch
        let fallbackField = app.textFields.firstMatch
        let input = field.waitForExistence(timeout: 3) ? field : fallbackField
        XCTAssertTrue(input.exists, "Message input missing")
        input.tap()
        input.typeText("Hello from the UI test")

        let send = app.buttons["Send message"]
        XCTAssertTrue(send.waitForExistence(timeout: 5), "Send button missing")
        send.tap()

        XCTAssertTrue(
            app.staticTexts["Hello from the UI test"].waitForExistence(timeout: 5),
            "Sent message did not appear in the thread"
        )
    }

    @MainActor
    func testMyRoomsOpensFromCardsStatTile() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_RESET", "UITEST_SKIP_ONBOARDING", "UITEST_LOCAL"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        let roomsTile = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Rooms'")).firstMatch
        XCTAssertTrue(roomsTile.waitForExistence(timeout: 5), "Rooms stat tile missing on Cards")
        roomsTile.tap()

        XCTAssertTrue(
            app.navigationBars["My Rooms"].waitForExistence(timeout: 5),
            "My Rooms screen did not open"
        )
    }
}
