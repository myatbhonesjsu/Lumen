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
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        app.terminate()
    }

// MARK: Happy Path
    func testOnboarding_HappyPath_CompletesAndShowsHome() throws {
        // Page 0 (Welcome)
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
        let homeScreen = app.staticTexts["home.screen"]
        XCTAssertTrue(homeScreen.waitForExistence(timeout: 5), "Should navigate to Home after completing onboarding")

    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
