//
//  GraphGesturesModifierTests.swift
//  GraphEditorWatch
//
//  Created by handcart on 9/25/25.
//
import Testing
import SwiftUI
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct GraphGesturesModifierTests {
    private func setupViewModel() async -> GraphViewModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = await MainActor.run { GraphModel(storage: storage, physicsEngine: physicsEngine) }
        return await MainActor.run { GraphViewModel(model: model) }
    }
    
    private func createModifier(viewModel: GraphViewModel,
                                selectedNodeID: Binding<NodeID?>,
                                selectedEdgeID: Binding<UUID?>) -> GraphGesturesModifier {
        GraphGesturesModifier(
            viewModel: viewModel,
            renderContext: RenderContext(effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 300, height: 300)),
            zoomScale: .constant(1.0),
            offset: .constant(.zero),
            draggedNode: .constant(nil),
            dragOffset: .constant(.zero),
            potentialEdgeTarget: .constant(nil),
            selectedNodeID: selectedNodeID,
            selectedEdgeID: selectedEdgeID,
            viewSize: CGSize(width: 300, height: 300),
            panStartOffset: .constant(nil),
            showMenu: .constant(false),
            maxZoom: 5.0,
            crownPosition: .constant(0.0),
            onUpdateZoomRanges: {},
            isAddingEdge: .constant(false),
            isSimulating: .constant(true),
            saturation: .constant(1.0),
            currentDragLocation: .constant(nil),
            dragStartNode: .constant(nil)
        )
    }
    
    @MainActor @Test func testHitTestNodesInScreenSpace() async {
        let viewModel = await setupViewModel()
        _ = createModifier(viewModel: viewModel,
                                      selectedNodeID: .constant(nil),
                                      selectedEdgeID: .constant(nil))
        
        let nodes = [AnyNode(Node(label: 1, position: CGPoint(x: 100, y: 100)))]
        let renderContext = RenderContext(effectiveCentroid: CGPoint.zero, zoomScale: 1.0, offset: CGSize.zero, viewSize: CGSize(width: 300, height: 300))
        // Compute screen pos: viewCenter (150,150) + zoom * (model - centroid) + offset = (150,150) + 1*(100-0,100-0) + (0,0) = (250,250)
        let screenTapPos = CGPoint(x: 250, y: 250)
        let hitNode = HitTestHelper.closestNode(at: screenTapPos, visibleNodes: nodes, renderContext: renderContext)
        #expect(hitNode != nil, "Should hit node within radius")
    }
    
    @Test func testPointToLineDistance() async {
        let viewModel = await setupViewModel()
        _ = createModifier(viewModel: viewModel,
                                      selectedNodeID: .constant(nil),
                                      selectedEdgeID: .constant(nil))
        let dist = await MainActor.run {
            HitTestHelper.pointToLineDistance(point: CGPoint(x: 0, y: 1), from: CGPoint.zero, to: CGPoint(x: 2, y: 0))
        }
        #expect(dist == 1.0, "Perpendicular distance to line")
    }
    
    @Test func testHandleTap() async {
        let viewModel = await setupViewModel()
        var testSelectedNodeID: NodeID?
        var testSelectedEdgeID: UUID?
        let selectedNodeBinding = Binding<NodeID?>(
            get: { testSelectedNodeID },
            set: { testSelectedNodeID = $0 }
        )
        let selectedEdgeBinding = Binding<UUID?>(
            get: { testSelectedEdgeID },
            set: { testSelectedEdgeID = $0 }
        )
        let modifier = createModifier(viewModel: viewModel,
                                      selectedNodeID: selectedNodeBinding,
                                      selectedEdgeID: selectedEdgeBinding)
        let nodes = [AnyNode(Node(label: 1, position: CGPoint.zero))]
        let edges = [GraphEdge(from: nodes[0].id, target: nodes[0].id)]  // Self-edge for test
//        let renderContext = RenderContext(effectiveCentroid: CGPoint.zero, zoomScale: 1.0, offset: CGSize.zero, viewSize: CGSize(width: 300, height: 300))
        
        // Compute screen pos for model .zero: (150,150) + 1*(0-0,0-0) + (0,0) = (150,150)
        let screenTapPos = CGPoint(x: 150, y: 150)
        // Note: handleTap is private; to test, consider making it internal or testing via public API.
        // For compilation, this test assumes handleTap is made internal in the source file.
        _ = await MainActor.run {
            modifier.handleTap(at: screenTapPos, visibleNodes: nodes, visibleEdges: edges)
        }
        // Assert on mocked bindings
        #expect(testSelectedNodeID != nil, "Node should be selected after tap")
        #expect(testSelectedEdgeID == nil, "No edge selected")
    }
}
