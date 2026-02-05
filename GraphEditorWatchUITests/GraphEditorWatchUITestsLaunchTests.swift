//
//  GraphEditorWatchUITestsLaunchTests.swift
//  GraphEditorWatchUITests
//
//  Created by handcart on 8/4/25.
//

import XCTest

final class GraphEditorWatchUITestsLaunchTests: XCTestCase {

    override static var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    @MainActor
    func testLaunch() {
        let app = XCUIApplication()
        app.configureForUITesting()
        app.launchAndWait()
        
        let canvas = GraphCanvasPage(app: app)
        canvas.waitForCanvas(timeout: 10.0)
        
        app.takeScreenshot(named: "Launch Screen", testCase: self)
        XCTAssertTrue(canvas.exists, "Canvas should exist after launch")
    }
    
    func testLaunchWithEmptyGraph() {
        let app = XCUIApplication()
        app.configureForUITesting(skipLoading: true)
        app.launchAndWait()
        
        let canvas = GraphCanvasPage(app: app)
        canvas.waitForCanvas(timeout: 10.0)
        XCTAssertTrue(canvas.exists, "Canvas should exist with empty graph")
    }
    
    func testLaunchWithMockStorage() {
        let app = XCUIApplication()
        app.configureForUITesting(withMockStorage: true)
        app.launchAndWait()
        
        let canvas = GraphCanvasPage(app: app)
        canvas.waitForCanvas(timeout: 10.0)
        XCTAssertTrue(canvas.exists, "Canvas should exist with mock storage")
    }
    
    func testLaunchWithoutSimulation() {
        let app = XCUIApplication()
        app.configureForUITesting(disableSimulation: true)
        app.launchAndWait()
        
        let canvas = GraphCanvasPage(app: app)
        canvas.waitForCanvas(timeout: 10.0)
        XCTAssertTrue(canvas.exists, "Canvas should exist without simulation")
    }
    
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.configureForUITesting()
            app.launch()
            app.terminate()
        }
    }
}
