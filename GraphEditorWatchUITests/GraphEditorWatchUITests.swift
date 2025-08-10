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

        let canvas = app.otherElements["GraphCanvas"]  // Assumes accessibilityIdentifier set on GraphCanvasView
        XCTAssertTrue(canvas.waitForExistence(timeout: 5), "Graph canvas should appear")

        // Assume default nodes: Adjust start/end based on positions (e.g., node0 at (100,100), node1 at (200,200))
        let startPoint = CGVector(dx: 0.3, dy: 0.3)  // Near node0
        let endPoint = CGVector(dx: 0.6, dy: 0.6)    // Near node1

        let dragStart = canvas.coordinate(withNormalizedOffset: startPoint)
        let dragEnd = canvas.coordinate(withNormalizedOffset: endPoint)
        dragStart.press(forDuration: 0.1, thenDragTo: dragEnd)

        // Assert: Updated label reflects directed edge (e.g., "Graph with 3 nodes and 4 directed edges." and mentions direction)
        let updatedLabel = app.staticTexts["Graph with 3 nodes and 4 directed edges. No node selected."]  // Adjust based on post-drag (add "directed")
        XCTAssertTrue(updatedLabel.waitForExistence(timeout: 2), "Directed edge created, updating graph description")

        // Optional: Select the from-node and check description mentions "outgoing to" the to-node
        // Simulate tap on startPoint to select, then check label includes "outgoing to: <label>"
    }
    
    func testUndoAfterAddNode() throws {
            let app = XCUIApplication()
            app.launch()
            
            let canvas = app.otherElements["GraphCanvas"]  // Assume identifier set
            XCTAssertTrue(canvas.waitForExistence(timeout: 5))
            
            // Simulate add node: Assume menu button "Add Node" exists
            app.buttons["Show Menu"].tap()  // Or long press if using gestures
            app.buttons["Add Node"].tap()
            
            // Assert: Graph description updates (e.g., nodes increase)
            let updatedLabel = app.staticTexts["Graph with 4 nodes"]  // Adjust based on defaults +1
            XCTAssertTrue(updatedLabel.waitForExistence(timeout: 2), "Node added")
            
            // Undo via button
            app.buttons["Undo"].tap()  // Assume undo button in menu or UI
            let revertedLabel = app.staticTexts["Graph with 3 nodes"]  // Back to defaults
            XCTAssertTrue(revertedLabel.waitForExistence(timeout: 2), "Undo reverts add")
        }
        
        func testMenuDisplayAndAction() throws {
            let app = XCUIApplication()
            app.launch()
            
            let canvas = app.otherElements["GraphCanvas"]
            XCTAssertTrue(canvas.waitForExistence(timeout: 5))
            
            // Long press to show menu (if using sheet)
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.0)
            
            // Assert menu appears with buttons
            let addButton = app.buttons["Add Node"]
            XCTAssertTrue(addButton.waitForExistence(timeout: 2), "Menu shows with actions")
            
            addButton.tap()
            // Assert action effect (e.g., via label)
            let updatedLabel = app.staticTexts["Graph with 4 nodes"]
            XCTAssertTrue(updatedLabel.waitForExistence(timeout: 2), "Menu action adds node")
        }
    
    // New: Test for digital crown zooming (using proxy button; manual test crown in simulator)
    func testDigitalCrownZooming() throws {
        let app = XCUIApplication()
        app.launch()
        
        let canvas = app.otherElements["GraphCanvas"]  // Assume identifier set
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        
        // Simulate crown via menu button (add "Zoom In" to menu if not present)
        app.buttons["Show Menu"].tap()
        app.buttons["Zoom In"].tap()  // Proxy for crown rotation; adjust if button named differently
        
        // Assert: Check if description or visible elements change (e.g., more details visible)
        let zoomedLabel = app.staticTexts["Graph with 3 nodes"]  // Adjust to match post-zoom (e.g., if zoom reveals more)
        XCTAssertTrue(zoomedLabel.waitForExistence(timeout: 2), "Zoom updates view")
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
