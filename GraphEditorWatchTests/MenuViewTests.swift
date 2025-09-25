//
//  MenuViewTests.swift
//  GraphEditor
//
//  Created by handcart on 9/25/25.
//
import Testing
import SwiftUI
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct MenuViewTests {
    private func setupViewModel() async -> GraphViewModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = await GraphModel(storage: storage, physicsEngine: physicsEngine)
        return await GraphViewModel(model: model)
    }

    @Test func testEditSectionDeleteNode() async {
        let viewModel = await setupViewModel()
        let node = AnyNode(Node(label: 1, position: .zero))
        await MainActor.run { viewModel.model.nodes = [node] }
        _ = EditSection(viewModel: viewModel, selectedNodeID: node.id, selectedEdgeID: nil, onDismiss: {}, onEditNode: {})
        
        // Simulate button tap (manual test logic; for full UI test, use XCUITest)
        await viewModel.deleteNode(withID: node.id)
        #expect(await viewModel.model.nodes.isEmpty, "Node deleted")
    }
}
