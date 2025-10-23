//
//  GraphEditorWatchUITests.swift
//  GraphEditorWatchUITests
//
//  Created by handcart on 8/4/25.
//

import XCTest

extension XCUIApplication {
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10.0, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element did not appear: \(element)", file: file, line: line)
    }
}

final class GraphEditorWatchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.terminate()
        app.launch()
        Thread.sleep(forTimeInterval: 2.0)  // Increased for idle
        
        print("Post-launch hierarchy: \(app.debugDescription)")
        
        let canvas = app.otherElements["GraphCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10), "Graph canvas should appear on launch")
    }
    
    func testAppLaunchesAndCanvasExists() {
        let app = XCUIApplication()
        let canvas = app.otherElements["GraphCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10), "Canvas should exist")
        
        // Removed predicate (no label); add if canvas gets one, e.g.:
        // let initialPredicate = NSPredicate(format: "label CONTAINS 'Graph'")
        // expectation(for: initialPredicate, evaluatedWith: canvas)
        // waitForExpectations(timeout: 5.0)
    }
    
    func testMenuOpensAfterLongPress() {
        let app = XCUIApplication()
        let canvas = app.otherElements["GraphCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10), "Canvas should exist")
        
        canvas.tap()  // Deselect anything
        
        performLongPress(on: canvas, atNormalizedOffset: CGVector(dx: 0.5, dy: 0.5), maxRetries: 5, app: app)
        
        let menuGrid = app.otherElements["graphMenuGrid"]
        XCTAssertTrue(menuGrid.waitForExistence(timeout: 10), "Graph menu should appear")
        
        print("Menu hierarchy after open: \(app.debugDescription)")
    }
    
    func testAddNodeViaMenu() {
        let app = XCUIApplication()
        let canvas = app.otherElements["GraphCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10), "Canvas should exist")
        
        canvas.tap()  // Deselect
        
        performLongPress(on: canvas, atNormalizedOffset: CGVector(dx: 0.5, dy: 0.5), maxRetries: 5, app: app)
        
        let menuGrid = app.otherElements["graphMenuGrid"]
        XCTAssertTrue(menuGrid.waitForExistence(timeout: 10), "Graph menu should appear")
        
        print("Menu hierarchy after open: \(app.debugDescription)")
        
        let addNodeButton = app.buttons["addNodeButton"]
        scrollUntilVisible(element: addNodeButton, in: menuGrid, maxAttempts: 30)
        addNodeButton.tap()
        Thread.sleep(forTimeInterval: 1.0)
        
        // Update predicate to match actual post-add (inspect app)
        let addedPredicate = NSPredicate(format: "label CONTAINS 'node'")
        expectation(for: addedPredicate, evaluatedWith: canvas)
        waitForExpectations(timeout: 5.0)
    }
    
    func testResetGraphViaMenu() {
        // If dropping reset, comment out or remove this test
        // Otherwise, add after implementing resetGraph()
        let app = XCUIApplication()
        let canvas = app.otherElements["GraphCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10), "Canvas should exist")
        
        canvas.tap()  // Deselect
        
        performLongPress(on: canvas, atNormalizedOffset: CGVector(dx: 0.5, dy: 0.5), maxRetries: 5, app: app)
        
        let menuGrid = app.otherElements["graphMenuGrid"]
        XCTAssertTrue(menuGrid.waitForExistence(timeout: 10), "Graph menu should appear")
        
        print("Menu hierarchy after open: \(app.debugDescription)")
        
        let resetButton = app.buttons["resetGraphButton"]
        scrollUntilVisible(element: resetButton, in: menuGrid, maxAttempts: 30)
        resetButton.tap()
        Thread.sleep(forTimeInterval: 1.0)
        
        // Verify reset (adjust predicate)
        let resetPredicate = NSPredicate(format: "label CONTAINS 'Empty'")
        expectation(for: resetPredicate, evaluatedWith: canvas)
        waitForExpectations(timeout: 5.0)
    }
    
    // Helper: Perform long press with retries and debug (adjustments for watchOS)
    private func performLongPress(on element: XCUIElement, atNormalizedOffset offset: CGVector, maxRetries: Int = 5, app: XCUIApplication) {
        let coord = element.coordinate(withNormalizedOffset: offset)
        for attempt in 1...maxRetries {
            print("Long press attempt \(attempt)")
            Thread.sleep(forTimeInterval: 0.5)  // Settle without tap
            coord.press(forDuration: 1.5)  // Reduced; match app's timer
            Thread.sleep(forTimeInterval: 1.0)
            
            print("Post-long-press hierarchy (attempt \(attempt)): \(app.debugDescription)")
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Post-long-press-attempt-\(attempt)"
            attachment.lifetime = .keepAlways
            add(attachment)
            
            if app.otherElements["graphMenuGrid"].exists {
                return  // Success
            }
            coord.tap()  // Attempt dismiss
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("Long press failed after \(maxRetries) attempts")
    }
    
    // Improved scrolling (updated query to otherElements if needed)
    private func scrollUntilVisible(element: XCUIElement, in container: XCUIElement, maxAttempts: Int) {
        var attempts = 0
        let smallOffset = CGVector(dx: 0.5, dy: 0.25)
        
        while attempts < maxAttempts {
            let query = container.descendants(matching: .button)[element.identifier]  // Broader query for nested
            if query.exists && query.firstMatch.isHittable {
                return
            }
            
            // Swipe up
            let start = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            let end = container.coordinate(withNormalizedOffset: smallOffset)
            start.press(forDuration: 0.1, thenDragTo: end)
            Thread.sleep(forTimeInterval: 0.5)
            attempts += 1
            
            print("Scroll up attempt \(attempts): Exists? \(query.exists), hittable? \(query.firstMatch.isHittable)")
            
            // Corrective swipe down every 5
            if attempts % 5 == 0 {
                let downStart = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
                let downEnd = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                downStart.press(forDuration: 0.1, thenDragTo: downEnd)
                Thread.sleep(forTimeInterval: 0.5)
                print("Corrective swipe down at attempt \(attempts)")
            }
        }
        XCTFail("Element not visible after \(maxAttempts) attempts")
    }
}
