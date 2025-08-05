//
//  GraphEditorWatchUITests.swift
//  GraphEditorWatchUITests
//
//  Created by handcart on 8/4/25.
//

import XCTest

final class GraphEditorWatchUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testLaunch() throws {
            let app = XCUIApplication()
            app.launch()
            
            // Basic assertion: Check if the app launches without crashing
            XCTAssertTrue(app.exists, "App should launch successfully")
        }
    
    func testDragToCreateEdge() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for the graph to load (adjust timeout if simulation takes time)
        let canvas = app.otherElements["GraphCanvas"]  // Add accessibilityIdentifier="GraphCanvas" to your GraphCanvasView in code if not already
        XCTAssertTrue(canvas.waitForExistence(timeout: 5), "Graph canvas should appear")
        
        // Assume two nodes are visible at approximate positions (tweak based on defaults or add identifiers)
        // Node 1 at ~ (100,100), Node 2 at ~ (200,200) – use normalized coordinates for drag
        let startPoint = CGVector(dx: 0.3, dy: 0.3)  // Normalized (0-1) from top-left
        let endPoint = CGVector(dx: 0.6, dy: 0.6)
        
        // Simulate drag gesture
        let dragStart = canvas.coordinate(withNormalizedOffset: startPoint)
        let dragEnd = canvas.coordinate(withNormalizedOffset: endPoint)
        dragStart.press(forDuration: 0.1, thenDragTo: dragEnd)
        
        // Assert: Check for accessibility label update or some indicator (e.g., edge count increases)
        // If your graphDescription updates, query it via accessibility
        let updatedLabel = app.staticTexts["Graph with 3 nodes and 4 edges."]  // Adjust based on expected post-drag state
        XCTAssertTrue(updatedLabel.waitForExistence(timeout: 2), "Edge should be created, updating graph description")
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
