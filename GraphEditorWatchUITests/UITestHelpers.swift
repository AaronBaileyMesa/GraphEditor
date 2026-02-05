//
//  UITestHelpers.swift
//  GraphEditorWatchUITests
//
//  Created for improved UI test organization
//

import XCTest

// MARK: - XCUIElement Extensions

extension XCUIElement {
    /// Wait for element to exist with a timeout
    @discardableResult
    func waitToExist(timeout: TimeInterval = 10.0, file: StaticString = #file, line: UInt = #line) -> Bool {
        let exists = waitForExistence(timeout: timeout)
        if !exists {
            XCTFail("Element \(self) did not appear within \(timeout) seconds", file: file, line: line)
        }
        return exists
    }
    
    /// Wait for element to become hittable
    @discardableResult
    func waitToBeHittable(timeout: TimeInterval = 5.0) -> Bool {
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    /// Tap and wait for element to disappear
    func tapAndWaitToDisappear(timeout: TimeInterval = 5.0) {
        tap()
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        _ = XCTWaiter().wait(for: [expectation], timeout: timeout)
    }
}

// MARK: - Page Objects

/// Represents the main graph canvas and its interactions
struct GraphCanvasPage {
    let app: XCUIApplication
    
    var canvas: XCUIElement {
        app.otherElements["GraphCanvas"]
    }
    
    /// Wait for canvas to appear
    func waitForCanvas(timeout: TimeInterval = 5.0) {
        // Simple wait - the app should already be loaded via launchAndWait()
        canvas.waitToExist(timeout: timeout)
    }
    
    /// Tap at a normalized position (0.0-1.0 for x and y)
    func tap(at normalizedOffset: CGVector = CGVector(dx: 0.5, dy: 0.5)) {
        let coordinate = canvas.coordinate(withNormalizedOffset: normalizedOffset)
        coordinate.tap()
    }
    
    /// Perform a long press at a normalized position
    func longPress(at normalizedOffset: CGVector = CGVector(dx: 0.5, dy: 0.5), duration: TimeInterval = 1.2) {
        let coordinate = canvas.coordinate(withNormalizedOffset: normalizedOffset)
        coordinate.press(forDuration: duration)
    }
    
    /// Check if canvas exists
    var exists: Bool {
        canvas.exists
    }
}

/// Represents the graph menu that appears after long press
struct GraphMenuPage {
    let app: XCUIApplication
    
    var menuGrid: XCUIElement {
        app.otherElements["graphMenuGrid"]
    }
    
    var addNodeButton: XCUIElement {
        app.buttons["addNodeButton"]
    }
    
    var addToggleNodeButton: XCUIElement {
        app.buttons["addToggleNodeButton"]
    }
    
    var addEdgeButton: XCUIElement {
        app.buttons["addEdgeButton"]
    }
    
    var toggleSimulationButton: XCUIElement {
        app.buttons["toggleSimulation"]
    }
    
    var centerGraphButton: XCUIElement {
        app.buttons["centerGraphButton"]
    }
    
    var overlaysToggle: XCUIElement {
        app.switches["overlaysToggle"]
    }
    
    var simulationToggle: XCUIElement {
        app.switches["simulationToggle"]
    }
    
    /// Wait for menu to appear
    func waitForMenu(timeout: TimeInterval = 5.0) {
        menuGrid.waitToExist(timeout: timeout)
    }
    
    /// Check if menu is visible
    var isVisible: Bool {
        menuGrid.exists
    }
    
    /// Tap to add a node
    func tapAddNode() {
        addNodeButton.waitToBeHittable()
        addNodeButton.tap()
    }
    
    /// Tap to add a toggle node
    func tapAddToggleNode() {
        addToggleNodeButton.waitToBeHittable()
        addToggleNodeButton.tap()
    }
    
    /// Tap to add an edge
    func tapAddEdge() {
        addEdgeButton.waitToBeHittable()
        addEdgeButton.tap()
    }
    
    /// Close menu by tapping outside
    func close() {
        // Tap on canvas to dismiss menu
        let canvas = app.otherElements["GraphCanvas"]
        if canvas.exists {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        }
    }
}

/// Represents the node menu that appears when a node is selected
struct NodeMenuPage {
    let app: XCUIApplication
    
    var menuGrid: XCUIElement {
        app.otherElements["nodeMenuGrid"]
    }
    
    var editContentsButton: XCUIElement {
        app.buttons["editContentsButton"]
    }
    
    var deleteNodeButton: XCUIElement {
        app.buttons["deleteNodeButton"]
    }
    
    var toggleExpandCollapseButton: XCUIElement {
        app.buttons["toggleExpandCollapseButton"]
    }
    
    /// Wait for node menu to appear
    func waitForMenu(timeout: TimeInterval = 5.0) {
        menuGrid.waitToExist(timeout: timeout)
    }
    
    /// Check if menu is visible
    var isVisible: Bool {
        menuGrid.exists
    }
}

/// Represents the edge menu that appears when an edge is selected
struct EdgeMenuPage {
    let app: XCUIApplication
    
    var menuGrid: XCUIElement {
        app.otherElements["edgeMenuGrid"]
    }
    
    var deleteEdgeButton: XCUIElement {
        app.buttons["deleteEdgeButton"]
    }
    
    /// Wait for edge menu to appear
    func waitForMenu(timeout: TimeInterval = 5.0) {
        menuGrid.waitToExist(timeout: timeout)
    }
    
    /// Check if menu is visible
    var isVisible: Bool {
        menuGrid.exists
    }
}

// MARK: - Test App Configuration

extension XCUIApplication {
    /// Configure app for UI testing with mock data
    func configureForUITesting(withMockStorage: Bool = true, disableSimulation: Bool = true, skipLoading: Bool = true) {
        if withMockStorage {
            launchArguments.append("--uitest-mock-storage")
        }
        if disableSimulation {
            launchArguments.append("--uitest-no-simulation")
        }
        if skipLoading {
            launchArguments.append("--uitest-skip-loading")
        }
    }
    
    /// Launch and wait for app to be ready for testing
    func launchAndWait() {
        launch()
        // WatchOS apps need extra time to fully initialize
        // The ContentLoaderView uses .task which is async and takes time to complete
        sleep(10)
    }
    
    /// Take a screenshot and attach it to the test
    func takeScreenshot(named name: String, lifetime: XCTAttachment.Lifetime = .keepAlways, testCase: XCTestCase) {
        let attachment = XCTAttachment(screenshot: screenshot())
        attachment.name = name
        attachment.lifetime = lifetime
        testCase.add(attachment)
    }
}
