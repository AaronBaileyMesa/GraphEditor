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
            isSimulating: .constant(true)
        )
    }
    
    @MainActor @Test func testHitTestNodesInScreenSpace() async {
        let viewModel = await setupViewModel()
        _ = createModifier(viewModel: viewModel,
                                      selectedNodeID: .constant(nil),
                                      selectedEdgeID: .constant(nil))
        
        let nodes = [AnyNode(Node(label: 1, position: CGPoint(x: 100, y: 100)))]
        let context = GestureContext(zoomScale: 1.0, offset: CGSize.zero, viewSize: CGSize(width: 300, height: 300), effectiveCentroid: CGPoint.zero)
        // Compute screen pos: viewCenter (150,150) + zoom * (model - centroid) + offset = (150,150) + 1*(100-0,100-0) + (0,0) = (250,250)
        let screenTapPos = CGPoint(x: 250, y: 250)
        let hitContext = HitTestContext(zoomScale: context.zoomScale, offset: context.offset, viewSize: context.viewSize, effectiveCentroid: context.effectiveCentroid)
        let hitNode = HitTestHelper.closestNode(at: screenTapPos, visibleNodes: nodes, context: hitContext)
        #expect(hitNode != nil, "Should hit node within radius")
    }
    
    @Test func testPointToLineDistance() async {
        let viewModel = await setupViewModel()
        let modifier = createModifier(viewModel: viewModel,
                                      selectedNodeID: .constant(nil),
                                      selectedEdgeID: .constant(nil))
        let dist = await MainActor.run {
            modifier.pointToLineDistance(point: CGPoint(x: 0, y: 1), from: CGPoint.zero, endPoint: CGPoint(x: 2, y: 0))
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
        let context = GestureContext(zoomScale: 1.0, offset: CGSize.zero, viewSize: CGSize(width: 300, height: 300), effectiveCentroid: CGPoint.zero)
        
        // Compute screen pos for model .zero: (150,150) + 1*(0-0,0-0) + (0,0) = (150,150)
        let screenTapPos = CGPoint(x: 150, y: 150)
        _ = await MainActor.run {
            modifier.handleTap(at: screenTapPos, visibleNodes: nodes, visibleEdges: edges, context: context)
        }
        // Assert on mocked bindings
        #expect(testSelectedNodeID != nil, "Node should be selected after tap")
        #expect(testSelectedEdgeID == nil, "No edge selected")
    }
}
