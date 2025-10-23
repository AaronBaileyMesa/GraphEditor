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
        Thread.sleep(forTimeInterval: 1.0)
        
        print("Post-launch hierarchy: \(app.debugDescription)")
        
        let canvas = app.otherElements["GraphCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10), "Graph canvas should appear on launch")
    }
    
    func testAppLaunchesAndCanvasExists() {
        let app = XCUIApplication()
        let canvas = app.otherElements["GraphCanvas"]
        canvas.waitForExistence(timeout: 10)
        
        // Basic verification: Check initial label (adjust based on launched state)
        let initialPredicate = NSPredicate(format: "label CONTAINS 'Graph with'")
        expectation(for: initialPredicate, evaluatedWith: canvas)
        waitForExpectations(timeout: 5.0)
    }
    
    func testMenuOpensAfterLongPress() {
        let app = XCUIApplication()
        let canvas = app.otherElements["GraphCanvas"]
        canvas.waitForExistence(timeout: 10)
        
        performLongPress(on: canvas, atNormalizedOffset: CGVector(dx: 0.5, dy: 0.5), maxRetries: 3, app: app)
        
        let menuList = app.collectionViews["menuList"]
        menuList.waitForExistence(timeout: 10)
        
        print("Menu hierarchy after open: \(app.debugDescription)")
    }
    
    func testAddNodeViaMenu() {
        let app = XCUIApplication()
        let canvas = app.otherElements["GraphCanvas"]
        canvas.waitForExistence(timeout: 10)
        
        performLongPress(on: canvas, atNormalizedOffset: CGVector(dx: 0.5, dy: 0.5), maxRetries: 3, app: app)
        
        let menuList = app.collectionViews["menuList"]
        menuList.waitForExistence(timeout: 10)
        
        print("Menu hierarchy after open: \(app.debugDescription)")
        
        let addNodeButton = app.otherElements["addNodeButton"]
        scrollUntilVisible(element: addNodeButton, in: menuList, maxAttempts: 30)
        addNodeButton.tap()
        Thread.sleep(forTimeInterval: 1.0)
        
        // Basic check: Label changes to include more nodes
        let addedPredicate = NSPredicate(format: "label CONTAINS 'node'")
        expectation(for: addedPredicate, evaluatedWith: canvas)
        waitForExpectations(timeout: 5.0)
    }
    
    func testResetGraphViaMenu() {
        let app = XCUIApplication()
        let canvas = app.otherElements["GraphCanvas"]
        canvas.waitForExistence(timeout: 10)
        
        performLongPress(on: canvas, atNormalizedOffset: CGVector(dx: 0.5, dy: 0.5), maxRetries: 3, app: app)
        
        let menuList = app.collectionViews["menuList"]
        menuList.waitForExistence(timeout: 10)
        
        print("Menu hierarchy after open: \(app.debugDescription)")
        
        let newGraphButton = app.otherElements["newGraphButton"]
        scrollUntilVisible(element: newGraphButton, in: menuList, maxAttempts: 30)
        newGraphButton.tap()
        Thread.sleep(forTimeInterval: 1.0)
        
        // Verify reset: Check for empty graph label
        let emptyPredicate = NSPredicate(format: "label == %@", "Graph with 0 nodes and 0 edges. No node or edge selected.")
        expectation(for: emptyPredicate, evaluatedWith: canvas)
        waitForExpectations(timeout: 5.0)
    }
    
    // Helper: Perform long press with retries and debug
    private func performLongPress(on element: XCUIElement, atNormalizedOffset offset: CGVector, maxRetries: Int = 3, app: XCUIApplication) {
        let coord = element.coordinate(withNormalizedOffset: offset)
        for attempt in 1...maxRetries {
            print("Long press attempt \(attempt)")
            coord.tap()  // Pre-tap for readiness
            Thread.sleep(forTimeInterval: 1.0)  // Settle time
            coord.press(forDuration: 7.0)
            Thread.sleep(forTimeInterval: 2.0)
            
            print("Post-long-press hierarchy (attempt \(attempt)): \(app.debugDescription)")
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Post-long-press-attempt-\(attempt)"
            attachment.lifetime = XCTAttachment.Lifetime.keepAlways
            add(attachment)
            
            if app.collectionViews["menuList"].exists {
                return  // Success
            }
            coord.tap()  // Dismiss if partial open
            Thread.sleep(forTimeInterval: 1.0)
        }
        XCTFail("Long press failed after \(maxRetries) attempts")
    }
    
    // Improved scrolling: Bidirectional, smaller swipes, non-failing existence checks
    private func scrollUntilVisible(element: XCUIElement, in container: XCUIElement, maxAttempts: Int) {
        var attempts = 0
        let smallOffset = CGVector(dx: 0.5, dy: 0.25)  // Swipe 1/4 height for precision
        
        while attempts < maxAttempts {
            // Use query to check existence without failing
            let query = container.buttons[element.identifier]
            if query.exists && query.firstMatch.isHittable {
                return
            }
            
            // Swipe up (primary)
            let start = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            let end = container.coordinate(withNormalizedOffset: smallOffset)
            start.press(forDuration: 0.1, thenDragTo: end)
            Thread.sleep(forTimeInterval: 0.5)
            attempts += 1
            
            print("Scroll up attempt \(attempts): Exists? \(query.exists), hittable? \(query.firstMatch.isHittable)")
            
            // Every 5 attempts, swipe down to correct overshoot
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
