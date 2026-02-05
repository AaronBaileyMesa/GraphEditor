//
//  SimpleDebugTest.swift
//  GraphEditorWatchUITests
//
//  Debug test to investigate launch issues
//

import XCTest

final class SimpleDebugTest: XCTestCase {
    
    func testAppLaunchesAtAll() {
        let app = XCUIApplication()
        app.launch()
        
        // Wait a bit for app to fully launch
        sleep(10)
        
        // Print the entire UI hierarchy
        print("=== APP UI HIERARCHY ===")
        print(app.debugDescription)
        print("========================")
        
        // Check if app exists
        XCTAssertTrue(app.exists, "App should exist")
        
        // Check what elements are visible
        let allElements = app.descendants(matching: .any)
        print("Total elements found: \(allElements.count)")
        
        // Look for canvas with different queries
        let canvasById = app.otherElements["GraphCanvas"]
        let canvasExists = canvasById.exists
        print("Canvas by ID 'GraphCanvas' exists: \(canvasExists)")
        
        // Try lowercase
        let canvasLower = app.otherElements["graphCanvas"]
        print("Canvas by ID 'graphCanvas' exists: \(canvasLower.exists)")
        
        // Look for any other elements that might be the canvas
        let otherElements = app.otherElements
        print("Other elements count: \(otherElements.count)")
        
        for i in 0..<min(otherElements.count, 10) {
            let element = otherElements.element(boundBy: i)
            print("Other element \(i): identifier='\(element.identifier)' label='\(element.label)'")
        }
        
        // Check for Loading text
        let loadingText = app.staticTexts["Loading..."]
        print("Loading text exists: \(loadingText.exists)")
        
        // Check for ContentView elements
        let buttons = app.buttons
        print("Buttons count: \(buttons.count)")
    }
    
    func testAppWithMockLaunch() {
        let app = XCUIApplication()
        app.launchArguments.append("--uitest-mock-storage")
        app.launchArguments.append("--uitest-no-simulation")
        app.launchArguments.append("--uitest-skip-loading")
        app.launch()
        
        sleep(10)
        
        print("=== APP WITH MOCK STORAGE ===")
        print(app.debugDescription)
        print("=============================")
        
        let canvasById = app.otherElements["GraphCanvas"]
        print("Canvas exists: \(canvasById.exists)")
        
        let loadingText = app.staticTexts["Loading..."]
        print("Loading text exists: \(loadingText.exists)")
    }
}
