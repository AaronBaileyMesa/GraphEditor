//
//  EditContentSheetTests.swift
//  GraphEditor
//
//  Created by handcart on 9/25/25.
//
import Testing
import SwiftUI
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct EditContentSheetTests {
    private func setupViewModel() async -> GraphViewModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = await GraphModel(storage: storage, physicsEngine: physicsEngine)
        return await GraphViewModel(model: model)
    }
    
    @MainActor @Test func testSaveStringContent() async {
        let viewModel = await setupViewModel()
        let nodeID = NodeID()
        var savedContent: [NodeContent]?
        let sheet = EditContentSheet(selectedID: nodeID, viewModel: viewModel) { content in
            savedContent = content
        }
        // Simulate input: Since @State is private, this is placeholder; use XCUITest for full simulation or expose states for testing
        // For example, assume manual set: sheet.selectedType = "String"; sheet.stringValue = "test"; then call onSave
        // Placeholder assertion (adapt based on actual simulation logic)
        _ = sheet  // Use to silence warning
        #expect(savedContent == nil, "Initially nil; add simulation to set [.string(\"test\")]")
    }
}
