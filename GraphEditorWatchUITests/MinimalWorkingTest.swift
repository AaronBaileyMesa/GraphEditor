//
//  MinimalWorkingTest.swift
//  GraphEditorWatchUITests
//
//  Minimal test to verify basic functionality
//

import XCTest

final class MinimalWorkingTest: XCTestCase {
    
    func testAppActuallyLaunches() {
        // This test should pass - just verify app launches
        let app = XCUIApplication()
        app.launch()
        sleep(5)
        
        // These should always pass
        XCTAssertTrue(app.exists, "App should exist")
        XCTAssert(app.state == .runningForeground || app.state == .runningBackground, "App should be running")
    }
    
    func testAppLaunchesWithoutFlags() {
        // No launch arguments - just launch the real app
        let app = XCUIApplication()
        app.launch()
        
        // Wait generously for app to load
        sleep(15)
        
        // First, verify the app itself exists
        XCTAssertTrue(app.exists, "XCUIApplication should exist")
        XCTAssertNotEqual(app.state, .notRunning, "App should be running")
        
        print("App state: \(app.state.rawValue)")
        print("App exists: \(app.exists)")
        print("App debugDescription: \(app.debugDescription)")
        
        // Check for ANY elements
        let allElements = app.descendants(matching: .any)
        print("Total elements found: \(allElements.count)")
        
        // Check for loading text
        let loadingText = app.staticTexts["Loading..."]
        print("Loading text exists: \(loadingText.exists)")
        
        // Check if canvas appears
        let canvas = app.otherElements["GraphCanvas"]
        print("Canvas exists (immediate): \(canvas.exists)")
        
        // Use waitForExistence instead of immediate check
        let appeared = canvas.waitForExistence(timeout: 30)
        print("Canvas appeared after wait: \(appeared)")
        
        XCTAssertTrue(appeared, "Canvas should appear when launching without test flags")
    }
}
