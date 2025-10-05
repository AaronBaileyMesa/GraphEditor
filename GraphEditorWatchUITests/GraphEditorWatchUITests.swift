//
//  GraphEditorWatchUITests.swift
//  GraphEditorWatchUITests
//
//  Created by handcart on 8/4/25.
//

import XCTest

final class GraphEditorWatchUITests: XCTestCase {
    
    override func setUpWithError() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Open menu, tap "New Graph", enter "TestGraph", create
        let menuButton = app.buttons["Menu"]
        menuButton.tap()
        let newButton = app.buttons["New Graph"]
        newButton.tap()
        let textField = app.textFields.firstMatch  // Assume one
        textField.typeText("TestGraph\n")  // Enter name and submit
        sleep(2)  // Wait for creation
        
        // Now graph is new/empty; proceed
    }
    
    override func tearDownWithError() throws {}
    
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        
        XCTAssertTrue(app.exists, "App should launch successfully")
    }
    
    func testDragToCreateEdge() throws {
        let app = XCUIApplication()
        app.launch()

        let canvas = app.otherElements["GraphCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5), "Graph canvas should appear")

        // Open menu and add two nodes
        let menuButton = app.buttons["Menu"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Menu button should appear")
        menuButton.tap()
        let addNodeButton = app.buttons["Add"]
        XCTAssertTrue(addNodeButton.waitForExistence(timeout: 5), "Add button should appear")
        addNodeButton.tap()
        sleep(2)
        menuButton.tap()
        addNodeButton.tap()
        sleep(2)

        // Pre-tap start to ensure hit/select
        let startPoint = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))  // Center-top
        startPoint.tap()
        let endPoint = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))  // Center-bottom
        startPoint.press(forDuration: 0.2, thenDragTo: endPoint)
        sleep(2)

        // Check updated label
        let expectedLabel = "Graph with 5 nodes and 4 edges. No node or edge selected."
        let predicate = NSPredicate(format: "label == %@", expectedLabel)
        let expectation = self.expectation(for: predicate, evaluatedWith: canvas)
        let result = XCTWaiter.wait(for: [expectation], timeout: 10.0)
        XCTAssert(result == .completed, "Directed edge created, updating graph description")
    }

    func testUndoAfterAddNode() throws {
        let app = XCUIApplication()
        app.launch()
        
        let canvas = app.otherElements["GraphCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        
        // Open menu and add node
        let menuButton = app.buttons["Menu"]
        menuButton.tap()
        let addNodeButton = app.buttons["Add"]
        addNodeButton.tap()
        sleep(2)
        
        // Check added
        let addedLabel = "Graph with 4 nodes and 3 edges. No node or edge selected."
        let addedPredicate = NSPredicate(format: "label == %@", addedLabel)
        let addedExpectation = self.expectation(for: addedPredicate, evaluatedWith: canvas)
        let addedResult = XCTWaiter.wait(for: [addedExpectation], timeout: 10.0)
        XCTAssert(addedResult == .completed, "Node added")
        
        // Open menu and undo
        menuButton.tap()
        let undoButton = app.buttons["Undo"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 5), "Undo button should appear")
        undoButton.tap()
        sleep(2)
        
        // Check reverted
        let revertedLabel = "Graph with 3 nodes and 3 edges. No node or edge selected."
        let revertedPredicate = NSPredicate(format: "label == %@", revertedLabel)
        let revertedExpectation = self.expectation(for: revertedPredicate, evaluatedWith: canvas)
        let revertedResult = XCTWaiter.wait(for: [revertedExpectation], timeout: 10.0)
        XCTAssert(revertedResult == .completed, "Undo reverts add")
    }

    func testMenuDisplayAndAction() throws {
        let app = XCUIApplication()
        app.launch()
        
        let canvas = app.otherElements["GraphCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        
        // Tap menu button
        let menuButton = app.buttons["Menu"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Menu button should appear")
        menuButton.tap()
        
        // Check add button in menu
        let addButton = app.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Menu shows with actions")
        
        addButton.tap()
        sleep(2)
        
        // Check updated label
        let updatedLabel = "Graph with 4 nodes and 3 edges. No node or edge selected."
        let predicate = NSPredicate(format: "label == %@", updatedLabel)
        let expectation = self.expectation(for: predicate, evaluatedWith: canvas)
        let result = XCTWaiter.wait(for: [expectation], timeout: 10.0)
        XCTAssert(result == .completed, "Menu action adds node")
    }

    func testDigitalCrownZooming() throws {
        let app = XCUIApplication()
        app.launch()
        
        let canvas = app.otherElements["GraphCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        
        XCUIDevice.shared.rotateDigitalCrown(delta: 5.0, velocity: 1.0)  // Zoom in
        sleep(2)
        
        // Check label unchanged post-zoom
        let zoomedLabel = "Graph with 3 nodes and 3 edges. No node or edge selected."
        let predicate = NSPredicate(format: "label == %@", zoomedLabel)
        let expectation = self.expectation(for: predicate, evaluatedWith: canvas)
        let result = XCTWaiter.wait(for: [expectation], timeout: 10.0)
        XCTAssert(result == .completed, "Zoom updates view")
    }
    
    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }
    
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
