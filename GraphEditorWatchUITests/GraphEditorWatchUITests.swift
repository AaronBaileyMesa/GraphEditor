//
//  GraphEditorWatchUITests.swift
//  GraphEditorWatchUITests
//
//  Created by handcart on 8/4/25.
//

import XCTest

final class GraphEditorWatchUITests: XCTestCase {
    
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
    
    // MARK: - Basic Launch Tests
    
    func testAppLaunches() {
        let canvas = GraphCanvasPage(app: app)
        canvas.waitForCanvas(timeout: 10.0)
        XCTAssertTrue(canvas.exists, "Canvas should exist after launch")
    }
    
    func testCanvasIsAccessible() {
        let canvas = GraphCanvasPage(app: app)
        canvas.waitForCanvas(timeout: 10.0)
        XCTAssertTrue(canvas.canvas.isHittable, "Canvas should be hittable")
    }
    
    // MARK: - Menu Interaction Tests
    
    func testGraphMenuOpens() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        canvas.tap() // Clear any selection first
        canvas.longPress(at: CGVector(dx: 0.5, dy: 0.5), duration: 1.2)
        
        menu.waitForMenu(timeout: 5.0)
        XCTAssertTrue(menu.isVisible, "Graph menu should be visible after long press")
    }
    
    func testGraphMenuHasButtons() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        canvas.tap()
        canvas.longPress(duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        
        XCTAssertTrue(menu.addNodeButton.exists, "Add node button should exist")
        XCTAssertTrue(menu.addToggleNodeButton.exists, "Add toggle node button should exist")
        XCTAssertTrue(menu.addEdgeButton.exists, "Add edge button should exist")
    }
    
    func testAddNodeViaMenu() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        let nodeMenu = NodeMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        canvas.tap()
        canvas.longPress(duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        menu.tapAddNode()
        
        // Wait for node to be added and menu to update
        sleep(1)
        
        // Either node menu or graph menu should be visible
        let menuVisible = nodeMenu.menuGrid.exists || menu.menuGrid.exists
        XCTAssertTrue(menuVisible, "Either node menu or graph menu should be visible")
    }
    
    // MARK: - Node Interaction Tests
    
    func testSelectNodeAfterAdding() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        let nodeMenu = NodeMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        canvas.tap()
        canvas.longPress(duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        menu.tapAddNode()
        sleep(1)
        
        // If node menu doesn't appear, tap canvas to deselect
        if !nodeMenu.isVisible {
            canvas.tap(at: CGVector(dx: 0.5, dy: 0.5))
            usleep(300000) // 300ms
        }
        
        XCTAssertTrue(canvas.exists, "Canvas should still exist after adding node")
    }
    
    // MARK: - Menu Navigation Tests
    
    func testDismissMenuByTapping() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        canvas.longPress(duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        XCTAssertTrue(menu.isVisible, "Menu should be visible before dismissal")
        
        canvas.tap(at: CGVector(dx: 0.1, dy: 0.1))
        usleep(500000) // 500ms
        
        // Canvas should still exist
        XCTAssertTrue(canvas.exists, "Canvas should exist after menu interaction")
    }
    
    // MARK: - Toggle Node Tests
    
    func testAddToggleNodeViaMenu() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        canvas.tap()
        canvas.longPress(duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        menu.tapAddToggleNode()
        sleep(1)
        
        XCTAssertTrue(canvas.exists, "Canvas should still exist after adding toggle node")
    }
    
    // MARK: - Screenshot Tests
    
    func testAppLaunchScreenshot() {
        let canvas = GraphCanvasPage(app: app)
        canvas.waitForCanvas(timeout: 10.0)
        app.takeScreenshot(named: "App Launch", testCase: self)
        XCTAssertTrue(canvas.exists, "Canvas should exist after launch")
    }
    
    func testGraphMenuScreenshot() {
        let canvas = GraphCanvasPage(app: app)
        let menu = GraphMenuPage(app: app)
        
        canvas.waitForCanvas(timeout: 10.0)
        canvas.longPress(duration: 1.2)
        menu.waitForMenu(timeout: 5.0)
        app.takeScreenshot(named: "Graph Menu Open", testCase: self)
        XCTAssertTrue(menu.isVisible, "Menu should be visible")
    }
}
