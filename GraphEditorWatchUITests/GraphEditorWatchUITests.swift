//
//  GraphEditorWatchUITests.swift
//  GraphEditorWatchUITests
//
//  Created by handcart on 8/4/25.
//

import XCTest

extension XCUIApplication {
    @discardableResult
    func focusAndTypeInTextField(identifier: String, text: String, timeout: TimeInterval = 5.0, file: StaticString = #file, line: UInt = #line) -> XCUIElement {
        let field = textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: timeout), "TextField with identifier \(identifier) did not appear", file: file, line: line)
        field.tap()
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: field)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if result != .completed {
            XCTFail("TextField did not gain focus after tap", file: file, line: line)
        }
        field.typeText(text)
        return field
    }

    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5.0, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element did not appear: \(element)", file: file, line: line)
    }
}

final class GraphEditorWatchUITests: XCTestCase {
    override func setUpWithError() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Open menu
        let menuButton = app.buttons["Menu"]  // Matches label (identifier is symbol name)
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Menu button should appear")
        menuButton.tap()
        
        // Debug: Print full hierarchy (remove after fixing)
        print(app.debugDescription)
        
        // Tap "New Graph" (use identifier from your list)
        let newButton = app.buttons["newGraphButton"]
        scrollUntilVisible(element: newButton, in: app)
        XCTAssertTrue(newButton.waitForExistence(timeout: 5), "New Graph button should appear after scroll")
        newButton.tap()
        
        // Enter name in sheet's TextField (use identifier if available, otherwise fall back)
        if app.textFields["newGraphNameTextField"].exists {
            _ = app.focusAndTypeInTextField(identifier: "newGraphNameTextField", text: "TestGraph")
        } else {
            let sheetField = app.textFields["New Graph Name"].firstMatch
            XCTAssertTrue(sheetField.waitForExistence(timeout: 5), "New Graph Name field should appear")
            sheetField.tap()
            Thread.sleep(forTimeInterval: 0.5)  // Brief delay for watchOS
            let focusExpectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: sheetField)
            let focusResult = XCTWaiter.wait(for: [focusExpectation], timeout: 5.0)
            if focusResult != .completed {
                XCTFail("TextField did not gain keyboard focus after tap")
            }
            sheetField.typeText("TestGraph")
        }
        
        // Tap "Create" (use identifier from your list)
        let createButton = app.buttons["createButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create button should appear")
        createButton.tap()
        
        // Wait for async creation/dismiss
        XCTAssertTrue(app.otherElements["GraphCanvas"].waitForExistence(timeout: 5), "Back to empty graph after creation")
    }
    
    // Helper to scroll until visible/hittable (coordinate drag for precision; smaller dy to avoid overshoot)
    private func scrollUntilVisible(element: XCUIElement, in app: XCUIApplication, maxAttempts: Int = 10) {
        var attempts = 0
        while !element.isHittable && attempts < maxAttempts {
            // Coordinate-based drag (upward to reveal bottom items)
            let startCoord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))  // Near bottom
            let endCoord = startCoord.withOffset(CGVector(dx: 0.0, dy: -50))  // Drag up, smaller offset
            startCoord.press(forDuration: 0.1, thenDragTo: endCoord)
            attempts += 1
        }
        if !element.isHittable {
            XCTFail("Element not visible after \(maxAttempts) attempts")
        }
    }
    
    override func tearDownWithError() throws {}
    
    func testLaunch() throws {
        let app = XCUIApplication()
        XCTAssertTrue(app.exists, "App should launch successfully")
    }
    
    func testDragToCreateEdge() throws {
        let app = XCUIApplication()
        let canvas = app.otherElements["GraphCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5), "Graph canvas should appear")

        // Open menu and add two nodes (use identifier from your list)
        let menuButton = app.buttons["Menu"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Menu button should appear")
        menuButton.tap()
        let addNodeButton = app.buttons["addNodeButton"]
        XCTAssertTrue(addNodeButton.waitForExistence(timeout: 5), "Add Node button should appear")
        addNodeButton.tap()
        XCTAssertTrue(canvas.waitForExistence(timeout: 5), "Back to canvas after add")
        menuButton.tap()
        addNodeButton.tap()
        XCTAssertTrue(canvas.waitForExistence(timeout: 5), "Back to canvas after second add")

        // Pre-tap start to ensure hit/select
        let startPoint = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        startPoint.tap()
        let endPoint = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        startPoint.press(forDuration: 0.2, thenDragTo: endPoint)
        
        // Check updated label (adjust for empty start: 2 nodes, 1 edge)
        let expectedLabel = "Graph with 2 nodes and 1 edge. No node or edge selected."
        let predicate = NSPredicate(format: "label == %@", expectedLabel)
        let expectation = self.expectation(for: predicate, evaluatedWith: canvas)
        let result = XCTWaiter.wait(for: [expectation], timeout: 10.0)
        XCTAssert(result == .completed, "Directed edge created, updating graph description")
    }

    func testUndoAfterAddNode() throws {
        let app = XCUIApplication()
        let canvas = app.otherElements["GraphCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        
        // Open menu and add node (use identifier)
        let menuButton = app.buttons["Menu"]
        menuButton.tap()
        let addNodeButton = app.buttons["addNodeButton"]
        addNodeButton.tap()
        
        // Check added (from 0 -> 1 node, 0 edges)
        let addedLabel = "Graph with 1 node and 0 edges. No node or edge selected."
        let addedPredicate = NSPredicate(format: "label == %@", addedLabel)
        let addedExpectation = self.expectation(for: addedPredicate, evaluatedWith: canvas)
        let addedResult = XCTWaiter.wait(for: [addedExpectation], timeout: 10.0)
        XCTAssert(addedResult == .completed, "Node added")
        
        // Open menu and undo (use identifier)
        menuButton.tap()
        let undoButton = app.buttons["undoButton"]
        scrollUntilVisible(element: undoButton, in: app)
        XCTAssertTrue(undoButton.waitForExistence(timeout: 5), "Undo button should appear")
        undoButton.tap()
        
        // Check reverted (back to 0 nodes, 0 edges)
        let revertedLabel = "Graph with 0 nodes and 0 edges. No node or edge selected."
        let revertedPredicate = NSPredicate(format: "label == %@", revertedLabel)
        let revertedExpectation = self.expectation(for: revertedPredicate, evaluatedWith: canvas)
        let revertedResult = XCTWaiter.wait(for: [revertedExpectation], timeout: 10.0)
        XCTAssert(revertedResult == .completed, "Undo reverts add")
    }

    func testMenuDisplayAndAction() throws {
        let app = XCUIApplication()
        let canvas = app.otherElements["GraphCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        
        // Tap menu button
        let menuButton = app.buttons["Menu"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Menu button should appear")
        menuButton.tap()
        
        // Check add button in menu (use identifier)
        let addButton = app.buttons["addNodeButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Menu shows with actions")
        
        addButton.tap()
        
        // Check updated label (from 0 -> 1 node, 0 edges)
        let updatedLabel = "Graph with 1 node and 0 edges. No node or edge selected."
        let predicate = NSPredicate(format: "label == %@", updatedLabel)
        let expectation = self.expectation(for: predicate, evaluatedWith: canvas)
        let result = XCTWaiter.wait(for: [expectation], timeout: 10.0)
        XCTAssert(result == .completed, "Menu action adds node")
    }

    func testDigitalCrownZooming() throws {
        let app = XCUIApplication()
        let canvas = app.otherElements["GraphCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        
        XCUIDevice.shared.rotateDigitalCrown(delta: 5.0, velocity: 1.0)  // Zoom in
        
        // Check label unchanged post-zoom (empty graph)
        let zoomedLabel = "Graph with 0 nodes and 0 edges. No node or edge selected."
        let predicate = NSPredicate(format: "label == %@", zoomedLabel)
        let expectation = self.expectation(for: predicate, evaluatedWith: canvas)
        let result = XCTWaiter.wait(for: [expectation], timeout: 10.0)
        XCTAssert(result == .completed, "Zoom updates view")
    }
    
    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
    }
    
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
