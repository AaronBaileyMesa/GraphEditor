//
//  InlineTest.swift
//  GraphEditorWatchUITests
//
//  Test with everything inline to debug
//

import XCTest

final class InlineTest: XCTestCase {
    
    func testCanvasAppearsInline() {
        let app = XCUIApplication()
        app.launchArguments.append("--uitest-mock-storage")
        app.launchArguments.append("--uitest-no-simulation")
        app.launchArguments.append("--uitest-skip-loading")
        app.launch()
        
        sleep(10)
        
        let canvas = app.otherElements["GraphCanvas"]
        
        // Use explicit wait instead of immediate check
        let appeared = canvas.waitForExistence(timeout: 30)
        XCTAssertTrue(appeared, "Canvas should exist after waiting")
        XCTAssertTrue(canvas.exists, "Canvas should exist")
    }
    
    func testWithHelper() {
        let app = XCUIApplication()
        app.configureForUITesting()
        app.launchAndWait()
        
        let canvasPage = GraphCanvasPage(app: app)
        XCTAssertTrue(canvasPage.canvas.exists, "Canvas should exist via page object")
    }
    
    func testExactCopyOfSimpleDebug() {
        let app = XCUIApplication()
        app.terminate() // Ensure clean state
        
        app.launchArguments.append("--uitest-mock-storage")
        app.launchArguments.append("--uitest-no-simulation")
        app.launchArguments.append("--uitest-skip-loading")
        app.launch()
        
        sleep(10)
        
        print("=== INLINE TEST - APP WITH MOCK STORAGE ===")
        print("App exists: \(app.exists)")
        print("App state: \(app.state.rawValue)")
        
        let canvasById = app.otherElements["GraphCanvas"]
        let canvasExistsBefore = canvasById.exists
        print("Canvas exists (before wait): \(canvasExistsBefore)")
        
        if !canvasExistsBefore {
            print("Canvas not found, waiting...")
            let appeared = canvasById.waitForExistence(timeout: 20)
            print("Canvas appeared after wait: \(appeared)")
        }
        
        let loadingText = app.staticTexts["Loading..."]
        print("Loading text exists: \(loadingText.exists)")
        
        print("Total elements in hierarchy: \(app.descendants(matching: .any).count)")
        print("Other elements count: \(app.otherElements.count)")
        
        // Print first few other elements
        for i in 0..<min(5, app.otherElements.count) {
            let elem = app.otherElements.element(boundBy: i)
            print("  Other[\(i)]: id='\(elem.identifier)' exists=\(elem.exists)")
        }
        
        print("===========================================")
        
        // Now assert
        XCTAssertTrue(canvasById.exists, "Canvas should exist - check logs above")
    }
}
