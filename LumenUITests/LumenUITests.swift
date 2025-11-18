//
//  LumenUITests.swift
//  LumenUITests
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
        
        app.launch()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        app.terminate()
    }
    
// MARK: Test 1 - Required/Optional Onboarding + Happy Path
    
    func test_01_Onboarding_01_NameIsRequired_DisablesNext() {
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
    
    func test_01_Onboarding_02_BackNavigates() {
        app.buttons["nav.next"].tap()
        app.textFields["onboarding.nameField"].typeText("Ray")
        app.buttons["nav.next"].tap()
        app.buttons["nav.back"].tap()
        XCTAssertTrue(app.textFields["onboarding.nameField"].waitForExistence(timeout: 3))
    }

    func test_01_Onboarding_03_MetricsOptional_AllowsBlank() {
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
    
    func test_01_Onboarding_04_FullFlowAndSkipOnRelaunch() throws {
        // Page 0 – Welcome
        XCTAssertTrue(app.buttons["nav.next"].waitForExistence(timeout: 3))
        app.buttons["nav.next"].tap()

        // Page 1 – Name
        let name = app.textFields["onboarding.nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Ray")
        app.buttons["nav.next"].tap()

        // Page 2 – Skin Concern
        let concern = app.buttons["concern.Acne & Breakouts"]
        XCTAssertTrue(concern.waitForExistence(timeout: 3))
        concern.tap()
        app.buttons["nav.next"].tap()

        // Page 3 – Goal
        let goal = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'goal.'"))
            .firstMatch
        XCTAssertTrue(goal.waitForExistence(timeout: 3))
        goal.tap()
        app.buttons["nav.next"].tap()

        // Page 4 – Metrics
        let age = app.textFields["metrics.age"]
        XCTAssertTrue(age.waitForExistence(timeout: 3))
        age.tap()
        age.typeText("28")

        let height = app.textFields["metrics.height"]
        height.tap()
        height.typeText("75")

        let weight = app.textFields["metrics.weight"]
        weight.tap()
        weight.typeText("170")

        let getStarted = app.buttons["nav.getStarted"]
        XCTAssertTrue(getStarted.isEnabled)
        getStarted.tap()

        // Arrive on Home
        let homeHeader = app.staticTexts["Skin Analysis"]
        XCTAssertTrue(homeHeader.waitForExistence(timeout: 6))

        // Relaunch: Should Skip Onboarding Automatically
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["USE_MOCK_BACKEND"]
        app.launch()

        // Should land directly on Home
        let homeHeader2 = app.staticTexts["Skin Analysis"]
        XCTAssertTrue(
            homeHeader2.waitForExistence(timeout: 6),
            "App did NOT skip onboarding on the second launch!"
        )
    }

// MARK: Test 2 - Home
    
    func ensureAtHome(file: StaticString = #filePath, line: UInt = #line) {
        // on Home?
        if app.staticTexts["Skin Analysis"].waitForExistence(timeout: 1.5) { return }

        // if Welcome appears, complete minimal onboarding.
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

        // wait for Home to appear
        let homeHeader = app.staticTexts["Skin Analysis"]
        XCTAssertTrue(homeHeader.waitForExistence(timeout: 6), "Home screen did not appear after onboarding.")
    }
    
    func test_02_Home_01_Smoke_ShowsKeyActions() {
        ensureAtHome()

        // Just verify Home is visible and the section header exists.
        XCTAssertTrue(app.staticTexts["Skin Analysis"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.buttons["home.analyze"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.chat"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.learn"].waitForExistence(timeout: 5))
    }
    
    func test_02_Home_02_Tiles_Exist() {
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

    func test_02_Home_03_TileNavigation_Analyze() {
        ensureAtHome()

        // Tap the Analyze tile
        let analyzeTile = app.buttons["home.analyze"]
        XCTAssertTrue(analyzeTile.waitForExistence(timeout: 5), "Analyze tile not found on Home")
        analyzeTile.tap()

        // Handle camera permission popup (first run only)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
        }

        // Verify scan screen appears
        let scan = app.anyElement(withId: "scan.screen")
        XCTAssertTrue(scan.waitForExistence(timeout: 6), "Scan screen did not appear")
    }

    
    func test_02_Home_04_TileNavigation_History() {
        ensureAtHome()

        let history = app.buttons.containing(NSPredicate(format: "label CONTAINS 'History'")).firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        history.tap()

        let historyScreen = app.anyElement(withId: "history.screen")
        XCTAssertTrue(historyScreen.waitForExistence(timeout: 8), "History screen did not appear")
    }


    func test_02_Home_05_TileNavigation_Chat() {
        ensureAtHome()

        let chat = app.buttons.containing(NSPredicate(format: "label CONTAINS 'AI Chat'")).firstMatch
        XCTAssertTrue(chat.waitForExistence(timeout: 5))
        chat.tap()

        let chatScreen = app.anyElement(withId: "chat.screen")
        XCTAssertTrue(chatScreen.waitForExistence(timeout: 8), "Chat screen did not appear")
    }

    func test_02_Home_06_TileNavigation_Learn() {
        ensureAtHome()

        let learn = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Learn'")).firstMatch
        XCTAssertTrue(learn.waitForExistence(timeout: 5))
        learn.tap()

        let learnScreen = app.anyElement(withId: "learn.screen")
        XCTAssertTrue(learnScreen.waitForExistence(timeout: 8), "Learn screen did not appear")
    }

    func test_02_Home_07_Scroll() {
        ensureAtHome()

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))

        scrollView.swipeUp()
        scrollView.swipeDown()
    }
    
    func test_02_Home_08_TakePhotoCTA() {
        ensureAtHome()

        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()

        let takePhoto = app.buttons["Take Photo"]
        XCTAssertTrue(takePhoto.waitForExistence(timeout: 5))
        takePhoto.tap()

        let scanScreen = app.staticTexts["scan.screen"]
        XCTAssertTrue(scanScreen.waitForExistence(timeout: 6))
    }

    func test_02_Home_09_TabBar() {
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

// MARK: Test 3 - Camera

    private func openScanFromHome(file: StaticString = #filePath, line: UInt = #line) {
        ensureAtHome(file: file, line: line)

        let analyzeTile = app.buttons["home.analyze"]
        XCTAssertTrue(
            analyzeTile.waitForExistence(timeout: 6),
            "Analyze tile not found on Home",
            file: file, line: line
        )
        analyzeTile.tap()

        // Trigger the UIInterruptionMonitor so it can handle camera permission
        app.tap()
    }
    
    // Camera opens and shows scan screen
    func test_03_Camera_01_FromHome_ShowsScanScreen() {
        openScanFromHome()

        let scanScreen = app.anyElement(withId: "scan.screen")
        XCTAssertTrue(
            scanScreen.waitForExistence(timeout: 8),
            "Scan screen did not appear after tapping Analyze"
        )
    }

    // Close button returns to Home
    func test_03_Camera_02_Close_ReturnsHome() {
        openScanFromHome()

        let scanScreen = app.anyElement(withId: "scan.screen")
        XCTAssertTrue(
            scanScreen.waitForExistence(timeout: 8),
            "Scan screen did not appear"
        )

        // Use the label we actually see in the hierarchy: "Close"
        let closeButton = app.buttons["Close"]
        XCTAssertTrue(
            closeButton.waitForExistence(timeout: 5),
            "Scan close (X) button not found"
        )
        closeButton.tap()

        // Back on Home
        let homeHeader = app.staticTexts["Skin Analysis"]
        XCTAssertTrue(homeHeader.waitForExistence(timeout: 6), "Did not return to Home after closing camera")
    }


    // Shutter button exists (and is tappable)
    func test_03_Camera_03_ShutterButton_VisibleAndTappable() {
        openScanFromHome()

        let scanScreen = app.anyElement(withId: "scan.screen")
        XCTAssertTrue(
            scanScreen.waitForExistence(timeout: 8),
            "Scan screen did not appear"
        )

        let shutter = app.buttons.matching(
            NSPredicate(format: "identifier == 'scan.shutter' OR (identifier == 'scan.screen' AND label == '')")
        ).firstMatch

        XCTAssertTrue(
            shutter.waitForExistence(timeout: 5),
            "Shutter button not visible on scan screen"
        )

        // Try tapping it (even if disabled, this just verifies the control is there)
        shutter.tap()
    }
    
    
// MARK: Test 4 - History
    
    func test_04_History_01_OpenEntryIfExists() {
        ensureAtHome()

        // Go to history
        let historyTile = app.buttons["home.history"]
        XCTAssertTrue(historyTile.waitForExistence(timeout: 5))
        historyTile.tap()

        let historyScreen = app.anyElement(withId: "history.screen")
        XCTAssertTrue(historyScreen.waitForExistence(timeout: 5))

        // Look for a history cell (button or list row)
        let firstEntry = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Scan' OR label CONTAINS[c] 'Result'")).firstMatch

        if firstEntry.exists {
            firstEntry.tap()

            let detail = app.anyElement(withId: "history.detail.screen")
            XCTAssertTrue(detail.waitForExistence(timeout: 5), "Detail screen did not appear")

            // Go back if there's a back button
            app.buttons["Back"].firstMatch.tap()
            XCTAssertTrue(historyScreen.waitForExistence(timeout: 5))
        } else {
            // Verify empty state appears instead
            let emptyLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'No' OR label CONTAINS[c] 'empty'")).firstMatch
            XCTAssertTrue(emptyLabel.exists, "Expected empty state in History but nothing found")
        }
    }

// MARK: Test 5 - Learn/Chat
    
    private func openLearnFromTabBar(
        file: StaticString = #filePath,
        line: UInt = #line) {

        ensureAtHome(file: file, line: line)
        app.buttons["Learn"].tap()

        let learnScreen = app.anyElement(withId: "learn.screen")
        XCTAssertTrue(
            learnScreen.waitForExistence(timeout: 5),
            "Learn screen did not appear after tapping Learn tab",
            file: file,
            line: line
        )
    }

    func test_05_Learn_01_TabBar_OpensChat() {
        openLearnFromTabBar()

        let header = app.staticTexts["Your AI Skincare Assistant"]
        XCTAssertTrue(
            header.waitForExistence(timeout: 5),
            "Chat hero header did not appear on Learn screen"
        )

        // At least one sample question card
        let sampleQuestion = app.staticTexts
            .containing(NSPredicate(format: "label CONTAINS[c] '?'"))
            .firstMatch
        XCTAssertTrue(
            sampleQuestion.waitForExistence(timeout: 5),
            "No sample question card appeared on Chat tab"
        )
    }

    func test_05_Learn_02_TabBar_SwitchesToArticles() {
        openLearnFromTabBar()

        let articlesTab = app.buttons["Articles"]
        XCTAssertTrue(
            articlesTab.waitForExistence(timeout: 3),
            "Articles tab not visible in Learn segmented control"
        )
        articlesTab.tap()

        // Articles search field
        let searchField = app.textFields["Search articles..."]
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "Articles search field did not appear"
        )

        let allCategory = app.buttons["All"]
        XCTAssertTrue(
            allCategory.waitForExistence(timeout: 5),
            "Articles category filter chips not visible"
        )
    }

    func test_05_Learn_03_TabBar_SwitchesToForYou() {
        openLearnFromTabBar()

        let forYouTab = app.buttons["For You"]
        XCTAssertTrue(
            forYouTab.waitForExistence(timeout: 3),
            "'For You' tab not visible in Learn segmented control"
        )
        forYouTab.tap()

        let header = app.staticTexts["Personalized For You"]
        XCTAssertTrue(
            header.waitForExistence(timeout: 6),
            "'Personalized For You' header did not appear on recommendations tab"
        )
    }
    
    func test_05_Learn_04_ChatSuggestion_SendsMessageAndGetsReply() {
        openLearnFromTabBar()

        let suggestion = app.staticTexts["What's the best routine for my skin?"]
        XCTAssertTrue(
            suggestion.waitForExistence(timeout: 5),
            "Chat suggestion card 'What's the best routine for my skin?' was not visible on Learn Chat"
        )
        suggestion.tap()

        let questionBubble = app.staticTexts["What's the best routine for my skin?"]
        XCTAssertTrue(
            questionBubble.waitForExistence(timeout: 5),
            "Question bubble did not appear in the chat after tapping the suggestion"
        )

        // Verify AI response
        let thinking = app.staticTexts["Thinking..."]
        XCTAssertTrue(
            thinking.waitForExistence(timeout: 5),
            "\"Thinking...\" indicator did not appear after sending the question"
        )

        // Wait for "Thinking..." to disappear
        let gonePredicate = NSPredicate(format: "exists == false")
        expectation(for: gonePredicate, evaluatedWith: thinking)
        waitForExpectations(timeout: 20)

        let allMessages = app.staticTexts.allElementsBoundByIndex

        let sentQuestion = "What's the best routine for my skin?"

        let replyMessages = allMessages.filter {
            let text = $0.label.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.count > 0 && text != sentQuestion && text != "Thinking..."
        }

        XCTAssertFalse(
            replyMessages.isEmpty,
            "AI assistant reply did not appear after \"Thinking...\" finished"
        )
    }

    func test_05_Learn_05_ArticleCard_OpensDetail() {
        openLearnFromTabBar()
        let articlesTab = app.buttons["Articles"]
        XCTAssertTrue(
            articlesTab.waitForExistence(timeout: 3),
            "Articles tab not visible in Learn segmented control"
        )
        articlesTab.tap()

        let articleTitle = "Acne: Diagnosis and Treatment"
        let articleCard  = app.staticTexts[articleTitle]

        XCTAssertTrue(
            articleCard.waitForExistence(timeout: 5),
            "Sample article card '\(articleTitle)' not found on Articles list"
        )

        articleCard.tap()

        // Detail screen title visible
        let detailTitle = app.staticTexts[articleTitle]
        XCTAssertTrue(
            detailTitle.waitForExistence(timeout: 5),
            "Article detail did not open for '\(articleTitle)'"
        )

        let readButton = app.buttons["Read Full Article"]
        XCTAssertTrue(
            readButton.waitForExistence(timeout: 5),
            "'Read Full Article' button not visible on article detail"
        )
    }
    
    
    
    
    
    

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
