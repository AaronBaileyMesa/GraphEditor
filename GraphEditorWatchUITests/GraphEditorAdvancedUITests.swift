//
//  GraphEditorAdvancedUITests.swift
//  GraphEditorWatchUITests
//
//  Advanced UI test scenarios for comprehensive coverage
//

import XCTest

final class GraphEditorAdvancedUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.configureForUITesting(
            withMockStorage: true,
            disableSimulation: true,
            skipLoading: true
        )
        app.launchAndWait()
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // MARK: - Multiple Node Tests
    
    func testAddMultipleNodes() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        
        // Add first node
        canvas.tap()
        canvas.longPress(duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        menu.tapAddNode()
        usleep(500000)
        
        // Add second node
        canvas.tap(at: CGVector(dx: 0.3, dy: 0.3))
        canvas.longPress(at: CGVector(dx: 0.7, dy: 0.7), duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        menu.tapAddNode()
        usleep(500000)
        
        XCTAssertTrue(canvas.exists, "Canvas should remain functional after adding multiple nodes")
    }
    
    func testAddMixedNodeTypes() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        
        // Add regular node
        canvas.tap()
        canvas.longPress(at: CGVector(dx: 0.3, dy: 0.5), duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        menu.tapAddNode()
        usleep(500000)
        
        // Add toggle node
        canvas.tap(at: CGVector(dx: 0.2, dy: 0.2))
        canvas.longPress(at: CGVector(dx: 0.7, dy: 0.5), duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        menu.tapAddToggleNode()
        usleep(500000)
        
        XCTAssertTrue(canvas.exists, "Canvas should handle mixed node types")
    }
    
    // MARK: - Node Menu Tests
    
    func testNodeMenuAppearsAfterAdd() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        let nodeMenu = NodeMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        canvas.tap()
        canvas.longPress(duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        menu.tapAddNode()
        usleep(800000)
        
        // Either node menu or graph menu should be present
        let menuVisible = nodeMenu.isVisible || menu.isVisible
        XCTAssertTrue(menuVisible, "Some menu should be visible after adding node")
    }
    
    func testNodeMenuHasEditButton() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        let nodeMenu = NodeMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        canvas.tap()
        canvas.longPress(duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        menu.tapAddNode()
        usleep(800000)
        
        // If node menu is visible, check for edit button
        if nodeMenu.isVisible {
            XCTAssertTrue(nodeMenu.editContentsButton.exists, "Edit contents button should exist in node menu")
        }
    }
    
    // MARK: - Canvas Interaction Tests
    
    func testCanvasSingleTap() {
        let canvas = GraphCanvasPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        canvas.tap()
        usleep(200000)
        
        XCTAssertTrue(canvas.exists, "Canvas should remain after tap")
    }
    
    func testCanvasTapAtDifferentPositions() {
        let canvas = GraphCanvasPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        
        // Tap at different positions
        canvas.tap(at: CGVector(dx: 0.2, dy: 0.2))
        usleep(100000)
        
        canvas.tap(at: CGVector(dx: 0.8, dy: 0.8))
        usleep(100000)
        
        canvas.tap(at: CGVector(dx: 0.5, dy: 0.5))
        usleep(100000)
        
        XCTAssertTrue(canvas.exists, "Canvas should handle taps at various positions")
    }
    
    func testLongPressAtDifferentPositions() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        canvas.tap()
        canvas.longPress(at: CGVector(dx: 0.3, dy: 0.3), duration: 1.2)
        usleep(500000)
        
        XCTAssertTrue(menu.isVisible, "Menu should appear after long press at any position")
    }
    
    // MARK: - Menu State Tests
    
    func testMenuTogglesInteractive() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        canvas.longPress(duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        
        // Check if toggles exist
        if menu.overlaysToggle.exists {
            XCTAssertTrue(menu.overlaysToggle.isHittable, "Overlays toggle should be interactive")
        }
        
        if menu.simulationToggle.exists {
            XCTAssertTrue(menu.simulationToggle.isHittable, "Simulation toggle should be interactive")
        }
    }
    
    // MARK: - Edge Tests
    
    func testAddEdgeButtonAccessible() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        canvas.longPress(duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        
        XCTAssertTrue(menu.addEdgeButton.exists, "Add edge button should exist")
    }
    
    // MARK: - Stress Tests
    
    func testMultipleMenuOpenClose() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        
        // Open and close menu multiple times
        for _ in 0..<3 {
            canvas.longPress(duration: 1.2)
            menu.waitForMenu(timeout: 3.0)
            XCTAssertTrue(menu.isVisible, "Menu should open")
            
            canvas.tap(at: CGVector(dx: 0.1, dy: 0.1))
            usleep(300000)
        }
        
        XCTAssertTrue(canvas.exists, "Canvas should remain stable after multiple menu operations")
    }
    
    func testRapidTapsStability() {
        let canvas = GraphCanvasPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        
        // Rapid taps
        for _ in 0..<10 {
            canvas.tap(at: CGVector(dx: 0.5, dy: 0.5))
            usleep(50000)
        }
        
        XCTAssertTrue(canvas.exists, "Canvas should remain stable after rapid taps")
        XCTAssertTrue(canvas.canvas.isHittable, "Canvas should remain interactive")
    }
}

// MARK: - Accessibility Tests

final class GraphEditorAccessibilityTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.configureForUITesting()
        app.launch()
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    func testCanvasHasAccessibilityID() {
        let canvas = GraphCanvasPage(app: app)
        canvas.waitForCanvas(timeout: 10.0)
        
        XCTAssertEqual(canvas.canvas.identifier, "GraphCanvas", "Canvas should have correct accessibility identifier")
    }
    
    func testMenuButtonsHaveAccessibilityIDs() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        canvas.longPress(duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        
        XCTAssertEqual(menu.addNodeButton.identifier, "addNodeButton", "Add node button should have correct identifier")
        XCTAssertEqual(menu.addToggleNodeButton.identifier, "addToggleNodeButton", "Add toggle node button should have correct identifier")
        XCTAssertEqual(menu.addEdgeButton.identifier, "addEdgeButton", "Add edge button should have correct identifier")
    }
    
    func testMenuGridHasAccessibilityID() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        canvas.longPress(duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        
        XCTAssertEqual(menu.menuGrid.identifier, "graphMenuGrid", "Menu grid should have correct identifier")
    }
}
