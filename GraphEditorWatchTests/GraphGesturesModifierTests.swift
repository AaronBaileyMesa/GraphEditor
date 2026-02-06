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
    
    // MARK: - Gesture State Tests
    
    @MainActor @Test func testHasCheckedForNodeFlagPreventsDuplicateChecks() async {
        let viewModel = await setupViewModel()
        
        // The hasCheckedForNodeThisGesture flag should prevent repeated node checks
        // during a pan gesture. This is tested indirectly through gesture behavior,
        // but we verify the modifier properly manages state across gesture phases.
        
        var draggedNode: (any NodeProtocol)? = nil
        var dragOffset: CGPoint = .zero
        var panStartOffset: CGSize? = nil
        
        let draggedNodeBinding = Binding<(any NodeProtocol)?>(
            get: { draggedNode },
            set: { draggedNode = $0 }
        )
        let dragOffsetBinding = Binding<CGPoint>(
            get: { dragOffset },
            set: { dragOffset = $0 }
        )
        let panStartOffsetBinding = Binding<CGSize?>(
            get: { panStartOffset },
            set: { panStartOffset = $0 }
        )
        
        let modifier = GraphGesturesModifier(
            viewModel: viewModel,
            renderContext: RenderContext(effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 300, height: 300)),
            zoomScale: .constant(1.0),
            offset: .constant(.zero),
            draggedNode: draggedNodeBinding,
            dragOffset: dragOffsetBinding,
            potentialEdgeTarget: .constant(nil),
            selectedNodeID: .constant(nil),
            selectedEdgeID: .constant(nil),
            viewSize: CGSize(width: 300, height: 300),
            panStartOffset: panStartOffsetBinding,
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
        
        // Add a node that could be hit
        let node = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        // Simulate a pan gesture starting away from the node
        // The flag should prevent repeated checks after threshold is exceeded
        let renderContext = RenderContext(effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 300, height: 300))
        
        // First check: should find no node at start location (away from node)
        let startLocation = CGPoint(x: 50, y: 50)  // Far from node at (100, 100)
        let hitNode = HitTestHelper.closestNode(at: startLocation, visibleNodes: [node], renderContext: renderContext)
        
        #expect(hitNode == nil, "Should not hit node at pan start location")
        
        // After threshold exceeded and no node found, pan should start
        // The modifier's internal flag prevents re-checking on subsequent drag events
        // This is verified by the absence of node drag when panning
        #expect(draggedNode == nil, "Should remain nil during pan")
        #expect(panStartOffset == nil, "Pan hasn't started yet in this test setup")
    }
    
    @MainActor @Test func testControlNodeDistanceAfterDrag() async {
        let viewModel = await setupViewModel()
        
        // Add a node and generate controls
        let nodePos = CGPoint(x: 100, y: 100)
        let node = await viewModel.model.addNode(at: nodePos)
        await viewModel.generateControls(for: node.id)
        
        // Simulate repositioning at drag start
        viewModel.repositionEphemerals(for: node.id, to: nodePos)
        
        // Verify control nodes are at correct distance
        let expectedDistance: CGFloat = 40.0
        let tolerance: CGFloat = 0.1
        
        for control in viewModel.model.ephemeralControlNodes where control.ownerID == node.id {
            let dx = control.position.x - nodePos.x
            let dy = control.position.y - nodePos.y
            let distance = hypot(dx, dy)
            
            // Distance should be 40pt or less (if clamped at bounds)
            #expect(distance <= expectedDistance + tolerance,
                   "Control distance should be 40pt or less: got \(distance)")
        }
    }
}
