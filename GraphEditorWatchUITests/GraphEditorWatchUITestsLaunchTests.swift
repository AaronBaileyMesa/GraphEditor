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

    override func setUpWithError() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        
        // NEW: Add arguments BEFORE launch for consistency
        app.launchArguments.append("--uitest-mock-storage")
        app.launchArguments.append("--uitest-no-simulation")
        
        app.terminate()
        app.launch()
        
        Thread.sleep(forTimeInterval: 2.0)  // Reduce from 5s
        
        print("Post-launch hierarchy: \(app.debugDescription)")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Post-launch screenshot"
        attachment.lifetime = .keepAlways
        add(attachment)

        let canvas = app.otherElements["GraphCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 20), "Graph canvas should appear on launch")  // Keep 20s for now
    }
    
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        
        // NEW: Set arguments BEFORE launch
        app.launchArguments.append("--uitest-mock-storage")
        app.launchArguments.append("--uitest-no-simulation")
        
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
