//
//  LumenUITests.swift
//  LumenUITests
//
//  Created by Myat Bhone San on 10/18/25.
//

import XCTest

final class LumenUITests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        app = XCUIApplication()
        app.launchArguments += ["UITEST_RESET", "USE_MOCK_BACKEND"]
        app.launch()
        
        // Handle permissions
        addUIInterruptionMonitor(withDescription: "System Alerts") { alert in
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            if alert.buttons["OK"].exists {
                alert.buttons["OK"].tap()
                return true
            }
            if alert.buttons["Don’t Allow"].exists {
                alert.buttons["Don’t Allow"].tap()
                return true
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        app.terminate()
    }

// MARK: Test 1 - Happy Path
    func testOnboarding_HappyPath_CompletesAndShowsHome() throws {
        // Page 0 (Welcome)
        XCTAssertTrue(app.buttons["nav.next"].waitForExistence(timeout: 3), "Next button should exist on Welcome page")
        app.buttons["nav.next"].tap()
        
        // Page 1 (Name)
        let name = app.textFields["onboarding.nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 3), "Name field should exist on page 1")
        name.tap()
        name.typeText("Spartan")
        app.buttons["nav.next"].tap()

        // Page 2 (Skin Concerns)
        let acne = app.buttons["concern.Acne & Breakouts"]
        XCTAssertTrue(acne.waitForExistence(timeout: 3), "Concern button should be visible on page 2")
        acne.tap()
        app.buttons["nav.next"].tap()

        // Page 3 (Goal)
        let goal = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'goal.'")).firstMatch
        XCTAssertTrue(goal.waitForExistence(timeout: 3), "Goal options should be visible on page 3")
        goal.tap()
        app.buttons["nav.next"].tap()

        // Page 4 (Body Metrics)
        let age = app.textFields["metrics.age"]
        XCTAssertTrue(age.waitForExistence(timeout: 3), "Body Metrics fields should exist on page 4")
        age.tap();
        age.typeText("28")
        
        let height = app.textFields["metrics.height"]
        height.tap()
        height.typeText("75")
        
        let weight = app.textFields["metrics.weight"]
        weight.tap()
        weight.typeText("170")
        
        // Get Started
        let getStarted = app.buttons["nav.getStarted"]
        XCTAssertTrue(getStarted.isEnabled, "Get Started should be enabled after valid metrics")
        getStarted.tap()
        
        // Land on home screen after onboarding
        let homeHeader = app.staticTexts["Skin Analysis"]
        XCTAssertTrue(homeHeader.waitForExistence(timeout: 6), "Home screen did not appear after onboarding.")
        

    }
    
// MARK: Test 2 - Required/Optional Onboarding
    
    func testOnboarding_NameIsRequired_DisablesNext() {
        app.buttons["nav.next"].tap() // welcome → name
        let next = app.buttons["nav.next"]
        XCTAssertTrue(next.exists)

        let name = app.textFields["onboarding.nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))

        // Ensure empty
        if let text = name.value as? String, !text.isEmpty {
                    name.tap()
                    name.typeText(String(
                        repeating: XCUIKeyboardKey.delete.rawValue,
                        count: text.count
                    ))
                }
        // Should not proceed
        XCTAssertFalse(next.isEnabled, "Next should be disabled when name is empty")
    }
    
    func testOnboarding_BackNavigates() {
        app.buttons["nav.next"].tap()
        app.textFields["onboarding.nameField"].typeText("Ray")
        app.buttons["nav.next"].tap()
        app.buttons["nav.back"].tap()
        XCTAssertTrue(app.textFields["onboarding.nameField"].waitForExistence(timeout: 3))
    }

    func testOnboarding_MetricsOptional_AllowsBlank() {
        // Go to metrics quickly
        app.buttons["nav.next"].tap()
        app.textFields["onboarding.nameField"].typeText("Ray")
        app.buttons["nav.next"].tap()
        app.buttons["concern.Acne & Breakouts"].tap()
        app.buttons["nav.next"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'goal.'")).firstMatch.tap()
        app.buttons["nav.next"].tap()

        let getStarted = app.buttons["nav.getStarted"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 3))
        XCTAssertTrue(getStarted.isEnabled, "Get Started should be enabled when metrics are blank (optional)")
    }
    
    func testLaunch_SkipsOnboarding_AfterCompletion() {
        // First launch: complete onboarding once
        app = XCUIApplication()
        app.launchArguments = ["USE_MOCK_BACKEND"]
        app.launch()

        app.buttons["nav.next"].tap()
        app.textFields["onboarding.nameField"].tap()
        app.textFields["onboarding.nameField"].typeText("Ray")
        app.buttons["nav.next"].tap()

        app.buttons["concern.Acne & Breakouts"].tap()
        app.buttons["nav.next"].tap()

        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'goal.'")
        ).firstMatch.tap()
        app.buttons["nav.next"].tap()

        app.buttons["nav.getStarted"].tap()

        // Relaunch: should skip onboarding
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["USE_MOCK_BACKEND"]
        app.launch()

        let homeHeader = app.staticTexts["Skin Analysis"]
        XCTAssertTrue(homeHeader.waitForExistence(timeout: 6), "Home screen did not appear after onboarding.")
    }
    
// MARK: Test 3 - Home
    func ensureAtHome(file: StaticString = #filePath, line: UInt = #line) {
        // 0) Already on Home?
        if app.staticTexts["Skin Analysis"].waitForExistence(timeout: 1.5) { return }

        // 1) If Welcome appears, complete minimal onboarding.
        if app.buttons["nav.next"].waitForExistence(timeout: 4) {
            app.buttons["nav.next"].tap()

            let name = app.textFields["onboarding.nameField"]
            XCTAssertTrue(name.waitForExistence(timeout: 5), "Name field not found", file: file, line: line)
            name.tap()
            name.typeText("Ray")
            app.buttons["nav.next"].tap()

            let acne = app.buttons["concern.Acne & Breakouts"]
            XCTAssertTrue(acne.waitForExistence(timeout: 5), "Concern screen not found", file: file, line: line)
            acne.tap()
            app.buttons["nav.next"].tap()

            let goal = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'goal.'")).firstMatch
            XCTAssertTrue(goal.waitForExistence(timeout: 5), "Goal not found", file: file, line: line)
            goal.tap()
            app.buttons["nav.next"].tap()

            let getStarted = app.buttons["nav.getStarted"]
            XCTAssertTrue(getStarted.waitForExistence(timeout: 5), "Get Started not found", file: file, line: line)
            getStarted.tap()
        }

        // 2) Finally, wait for Home to appear (type-agnostic)
        let homeHeader = app.staticTexts["Skin Analysis"]
        XCTAssertTrue(homeHeader.waitForExistence(timeout: 6), "Home screen did not appear after onboarding.")
    }
    
    func testHome_Smoke_ShowsKeyActions() {
        ensureAtHome()

        // Just verify Home is visible and the section header exists.
        XCTAssertTrue(app.staticTexts["Skin Analysis"].waitForExistence(timeout: 5))

        // And maybe also that the four tiles exist
        XCTAssertTrue(app.buttons["home.analyze"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.chat"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.learn"].waitForExistence(timeout: 5))
    }
    
    func testHome_Tiles_Exist() {
        ensureAtHome()

        let newScan = app.buttons.containing(NSPredicate(format: "label CONTAINS 'New Scan'")).firstMatch
        let history = app.buttons.containing(NSPredicate(format: "label CONTAINS 'History'")).firstMatch
        let chat    = app.buttons.containing(NSPredicate(format: "label CONTAINS 'AI Chat'")).firstMatch
        let learn   = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Learn'")).firstMatch

        XCTAssertTrue(newScan.waitForExistence(timeout: 5))
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        XCTAssertTrue(chat.waitForExistence(timeout: 5))
        XCTAssertTrue(learn.waitForExistence(timeout: 5))
    }

    func testHome_TileNavigation_Analyze_Simple() {
        ensureAtHome()

        // Find the Analyze tile by id
        let analyzeTile = app.buttons["home.analyze"]
        XCTAssertTrue(
            analyzeTile.waitForExistence(timeout: 5),
            "Analyze tile not found on Home"
        )

        // Tap it
        analyzeTile.tap()

        // We should now be on the scan screen
        let scan = app.anyElement(withId: "scan.screen")
        XCTAssertTrue(
            scan.waitForExistence(timeout: 6),
            "Scan screen did not appear"
        )
    }
    
    func testHome_TileNavigation_Analyze() {
        ensureAtHome()

        let analyze = app.buttons.containing(NSPredicate(format: "label CONTAINS 'New Scan'")).firstMatch
        XCTAssertTrue(analyze.waitForExistence(timeout: 5))
        analyze.tap()

        // Camera screen identifier
        let scanScreen = app.staticTexts["scan.screen"]
        XCTAssertTrue(scanScreen.waitForExistence(timeout: 6), "Scan screen did not appear")
    }
    
    func testHome_TileNavigation_History() {
        ensureAtHome()

        let history = app.buttons.containing(NSPredicate(format: "label CONTAINS 'History'")).firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        history.tap()

        let historyScreen = app.anyElement(withId: "history.screen")
        XCTAssertTrue(historyScreen.waitForExistence(timeout: 8), "History screen did not appear")
    }


    func testHome_TileNavigation_Chat() {
        ensureAtHome()

        let chat = app.buttons.containing(NSPredicate(format: "label CONTAINS 'AI Chat'")).firstMatch
        XCTAssertTrue(chat.waitForExistence(timeout: 5))
        chat.tap()

        let chatScreen = app.anyElement(withId: "chat.screen")
        XCTAssertTrue(chatScreen.waitForExistence(timeout: 8), "Chat screen did not appear")
    }

    func testHome_TileNavigation_Learn() {
        ensureAtHome()

        let learn = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Learn'")).firstMatch
        XCTAssertTrue(learn.waitForExistence(timeout: 5))
        learn.tap()

        let learnScreen = app.anyElement(withId: "learn.screen")
        XCTAssertTrue(learnScreen.waitForExistence(timeout: 8), "Learn screen did not appear")
    }

    func testHome_Scroll() {
        ensureAtHome()

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))

        scrollView.swipeUp()
        scrollView.swipeDown()
    }
    
    func testHome_TakePhotoCTA() {
        ensureAtHome()

        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()

        let takePhoto = app.buttons["Take Photo"]
        XCTAssertTrue(takePhoto.waitForExistence(timeout: 5))
        takePhoto.tap()

        let scanScreen = app.staticTexts["scan.screen"]
        XCTAssertTrue(scanScreen.waitForExistence(timeout: 6))
    }

    func testHome_TabBar() {
        ensureAtHome()

        app.buttons["History"].tap()
        XCTAssertTrue(app.anyElement(withId: "history.screen").waitForExistence(timeout: 5))
        
        app.buttons["Learn"].tap()
        XCTAssertTrue(app.anyElement(withId: "learn.screen").waitForExistence(timeout: 5))
        
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.anyElement(withId: "settings.screen").waitForExistence(timeout: 5))

        app.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts["Skin Analysis"].waitForExistence(timeout: 5))
    }

// MARK: Test 4 - History


    
    
    
    
    
    
    

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

// MARK: - Helpers
extension XCUIElement {
    @discardableResult
    func waitAndTap(timeout: TimeInterval = 5,
                    file: StaticString = #filePath,
                    line: UInt = #line) -> Bool {
        let exists = waitForExistence(timeout: timeout)
        XCTAssertTrue(exists,
                      "Element not found to tap: \(self)",
                      file: file,
                      line: line)
        if exists {
            tap()
        }
        return exists
    }
}

private extension XCUIApplication {
    func anyElement(withId id: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: id).firstMatch
    }
}
