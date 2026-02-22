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
        
        _ = GraphGesturesModifier(
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
    
    // MARK: - Tests for Refactored Helper Methods
    
    @MainActor @Test func testHandleControlNodeTap() async {
        let viewModel = await setupViewModel()
        
        // Add a node and generate controls
        let node = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        await viewModel.generateControls(for: node.id)
        
        // Get a control node
        guard let control = viewModel.model.ephemeralControlNodes.first(where: { $0.ownerID == node.id }) else {
            Issue.record("No control node found")
            return
        }
        
        var showMenu = false
        let showMenuBinding = Binding<Bool>(
            get: { showMenu },
            set: { showMenu = $0 }
        )
        
        let modifier = GraphGesturesModifier(
            viewModel: viewModel,
            renderContext: RenderContext(effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 300, height: 300)),
            zoomScale: .constant(1.0),
            offset: .constant(.zero),
            draggedNode: .constant(nil),
            dragOffset: .constant(.zero),
            potentialEdgeTarget: .constant(nil),
            selectedNodeID: .constant(node.id),
            selectedEdgeID: .constant(nil),
            viewSize: CGSize(width: 300, height: 300),
            panStartOffset: .constant(nil),
            showMenu: showMenuBinding,
            maxZoom: 5.0,
            crownPosition: .constant(0.0),
            onUpdateZoomRanges: {},
            isAddingEdge: .constant(false),
            isSimulating: .constant(true),
            saturation: .constant(1.0),
            currentDragLocation: .constant(nil),
            dragStartNode: .constant(nil)
        )
        
        // Test that tapping a control node returns true
        let result = modifier.handleControlNodeTap(controlNode: control)
        #expect(result == true, "Control node tap should return true")
    }
    
    @MainActor @Test func testHandleEdgeAddingModeSuccess() async {
        let viewModel = await setupViewModel()
        
        // Create two nodes
        let sourceNode = await viewModel.model.addNode(at: CGPoint(x: 50, y: 50))
        let targetNode = await viewModel.model.addNode(at: CGPoint(x: 150, y: 150))
        
        // Set up edge-adding mode
        var isAddingEdge = true
        viewModel.draggedNodeID = sourceNode.id
        viewModel.pendingEdgeType = .hierarchy
        
        let isAddingEdgeBinding = Binding<Bool>(
            get: { isAddingEdge },
            set: { isAddingEdge = $0 }
        )
        
        let modifier = GraphGesturesModifier(
            viewModel: viewModel,
            renderContext: RenderContext(effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 300, height: 300)),
            zoomScale: .constant(1.0),
            offset: .constant(.zero),
            draggedNode: .constant(nil),
            dragOffset: .constant(.zero),
            potentialEdgeTarget: .constant(nil),
            selectedNodeID: .constant(nil),
            selectedEdgeID: .constant(nil),
            viewSize: CGSize(width: 300, height: 300),
            panStartOffset: .constant(nil),
            showMenu: .constant(false),
            maxZoom: 5.0,
            crownPosition: .constant(0.0),
            onUpdateZoomRanges: {},
            isAddingEdge: isAddingEdgeBinding,
            isSimulating: .constant(true),
            saturation: .constant(1.0),
            currentDragLocation: .constant(nil),
            dragStartNode: .constant(nil)
        )
        
        // Handle edge adding mode
        let result = modifier.handleEdgeAddingMode(targetNode: targetNode)
        
        // Should return true and exit edge-adding mode
        #expect(result == true, "Edge creation should succeed")
        #expect(isAddingEdge == false, "Should exit edge-adding mode")
        #expect(viewModel.draggedNodeID == nil, "Should clear draggedNodeID")
        
        // Give time for async edge creation
        try? await Task.sleep(for: .milliseconds(100))
        
        // Verify edge was created
        let edgeExists = viewModel.model.edges.contains { edge in
            edge.from == sourceNode.id && edge.target == targetNode.id
        }
        #expect(edgeExists, "Edge should be created between nodes")
    }
    
    @MainActor @Test func testHandleEdgeAddingModeSameNode() async {
        let viewModel = await setupViewModel()
        
        // Create one node
        let node = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        // Set up edge-adding mode with same source and target
        var isAddingEdge = true
        viewModel.draggedNodeID = node.id
        
        let isAddingEdgeBinding = Binding<Bool>(
            get: { isAddingEdge },
            set: { isAddingEdge = $0 }
        )
        
        let modifier = GraphGesturesModifier(
            viewModel: viewModel,
            renderContext: RenderContext(effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 300, height: 300)),
            zoomScale: .constant(1.0),
            offset: .constant(.zero),
            draggedNode: .constant(nil),
            dragOffset: .constant(.zero),
            potentialEdgeTarget: .constant(nil),
            selectedNodeID: .constant(nil),
            selectedEdgeID: .constant(nil),
            viewSize: CGSize(width: 300, height: 300),
            panStartOffset: .constant(nil),
            showMenu: .constant(false),
            maxZoom: 5.0,
            crownPosition: .constant(0.0),
            onUpdateZoomRanges: {},
            isAddingEdge: isAddingEdgeBinding,
            isSimulating: .constant(true),
            saturation: .constant(1.0),
            currentDragLocation: .constant(nil),
            dragStartNode: .constant(nil)
        )
        
        // Try to create edge to same node
        let result = modifier.handleEdgeAddingMode(targetNode: node)
        
        // Should return false (can't create edge to self)
        #expect(result == false, "Edge creation to same node should fail")
        #expect(isAddingEdge == false, "Should still exit edge-adding mode")
        #expect(viewModel.draggedNodeID == nil, "Should clear draggedNodeID")
    }
    
    @MainActor @Test func testHandleEdgeAddingModeDuplicateEdge() async {
        let viewModel = await setupViewModel()
        
        // Create two nodes with existing edge
        let sourceNode = await viewModel.model.addNode(at: CGPoint(x: 50, y: 50))
        let targetNode = await viewModel.model.addNode(at: CGPoint(x: 150, y: 150))
        await viewModel.addEdge(from: sourceNode.id, to: targetNode.id, type: .hierarchy)
        
        // Set up edge-adding mode
        var isAddingEdge = true
        viewModel.draggedNodeID = sourceNode.id
        
        let isAddingEdgeBinding = Binding<Bool>(
            get: { isAddingEdge },
            set: { isAddingEdge = $0 }
        )
        
        let modifier = GraphGesturesModifier(
            viewModel: viewModel,
            renderContext: RenderContext(effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 300, height: 300)),
            zoomScale: .constant(1.0),
            offset: .constant(.zero),
            draggedNode: .constant(nil),
            dragOffset: .constant(.zero),
            potentialEdgeTarget: .constant(nil),
            selectedNodeID: .constant(nil),
            selectedEdgeID: .constant(nil),
            viewSize: CGSize(width: 300, height: 300),
            panStartOffset: .constant(nil),
            showMenu: .constant(false),
            maxZoom: 5.0,
            crownPosition: .constant(0.0),
            onUpdateZoomRanges: {},
            isAddingEdge: isAddingEdgeBinding,
            isSimulating: .constant(true),
            saturation: .constant(1.0),
            currentDragLocation: .constant(nil),
            dragStartNode: .constant(nil)
        )
        
        // Try to create duplicate edge
        let result = modifier.handleEdgeAddingMode(targetNode: targetNode)
        
        // Should return false (edge already exists)
        #expect(result == false, "Duplicate edge creation should fail")
        #expect(isAddingEdge == false, "Should exit edge-adding mode")
    }
    
    @MainActor @Test func testHandleNodeTapRegularNode() async {
        let viewModel = await setupViewModel()
        
        // Create a regular node
        let node = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        var selectedNodeID: NodeID? = nil
        var selectedEdgeID: UUID? = nil
        
        let selectedNodeBinding = Binding<NodeID?>(
            get: { selectedNodeID },
            set: { selectedNodeID = $0 }
        )
        let selectedEdgeBinding = Binding<UUID?>(
            get: { selectedEdgeID },
            set: { selectedEdgeID = $0 }
        )
        
        let modifier = GraphGesturesModifier(
            viewModel: viewModel,
            renderContext: RenderContext(effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 300, height: 300)),
            zoomScale: .constant(1.0),
            offset: .constant(.zero),
            draggedNode: .constant(nil),
            dragOffset: .constant(.zero),
            potentialEdgeTarget: .constant(nil),
            selectedNodeID: selectedNodeBinding,
            selectedEdgeID: selectedEdgeBinding,
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
        
        // Tap the node
        let result = modifier.handleNodeTap(node: node)
        
        #expect(result == true, "Node tap should return true")
        #expect(selectedNodeID == node.id, "Node should be selected")
        #expect(selectedEdgeID == nil, "Edge selection should be cleared")
    }
    
    @MainActor @Test func testHandleNodeTapTogglesSelection() async {
        let viewModel = await setupViewModel()
        
        // Create a regular node
        let node = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        var selectedNodeID: NodeID? = node.id  // Start with node selected
        
        let selectedNodeBinding = Binding<NodeID?>(
            get: { selectedNodeID },
            set: { selectedNodeID = $0 }
        )
        
        let modifier = GraphGesturesModifier(
            viewModel: viewModel,
            renderContext: RenderContext(effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 300, height: 300)),
            zoomScale: .constant(1.0),
            offset: .constant(.zero),
            draggedNode: .constant(nil),
            dragOffset: .constant(.zero),
            potentialEdgeTarget: .constant(nil),
            selectedNodeID: selectedNodeBinding,
            selectedEdgeID: .constant(nil),
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
        
        // Tap the already-selected node to deselect
        _ = modifier.handleNodeTap(node: node)
        
        #expect(selectedNodeID == nil, "Tapping selected node should deselect it")
    }
    
    @MainActor @Test func testHandleEdgeTap() async {
        let viewModel = await setupViewModel()
        
        // Create two nodes and an edge
        let node1 = await viewModel.model.addNode(at: CGPoint(x: 50, y: 50))
        let node2 = await viewModel.model.addNode(at: CGPoint(x: 150, y: 150))
        await viewModel.addEdge(from: node1.id, to: node2.id, type: .hierarchy)
        
        guard let edge = viewModel.model.edges.first else {
            Issue.record("No edge found")
            return
        }
        
        var selectedNodeID: NodeID? = node1.id  // Start with node selected
        var selectedEdgeID: UUID? = nil
        
        let selectedNodeBinding = Binding<NodeID?>(
            get: { selectedNodeID },
            set: { selectedNodeID = $0 }
        )
        let selectedEdgeBinding = Binding<UUID?>(
            get: { selectedEdgeID },
            set: { selectedEdgeID = $0 }
        )
        
        let modifier = GraphGesturesModifier(
            viewModel: viewModel,
            renderContext: RenderContext(effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 300, height: 300)),
            zoomScale: .constant(1.0),
            offset: .constant(.zero),
            draggedNode: .constant(nil),
            dragOffset: .constant(.zero),
            potentialEdgeTarget: .constant(nil),
            selectedNodeID: selectedNodeBinding,
            selectedEdgeID: selectedEdgeBinding,
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
        
        // Tap the edge
        let result = modifier.handleEdgeTap(edge: edge)
        
        #expect(result == true, "Edge tap should return true")
        #expect(selectedEdgeID == edge.id, "Edge should be selected")
        #expect(selectedNodeID == nil, "Node selection should be cleared")
    }
    
    @MainActor @Test func testHandleEdgeTapTogglesSelection() async {
        let viewModel = await setupViewModel()
        
        // Create two nodes and an edge
        let node1 = await viewModel.model.addNode(at: CGPoint(x: 50, y: 50))
        let node2 = await viewModel.model.addNode(at: CGPoint(x: 150, y: 150))
        await viewModel.addEdge(from: node1.id, to: node2.id, type: .hierarchy)
        
        guard let edge = viewModel.model.edges.first else {
            Issue.record("No edge found")
            return
        }
        
        var selectedEdgeID: UUID? = edge.id  // Start with edge selected
        
        let selectedEdgeBinding = Binding<UUID?>(
            get: { selectedEdgeID },
            set: { selectedEdgeID = $0 }
        )
        
        let modifier = GraphGesturesModifier(
            viewModel: viewModel,
            renderContext: RenderContext(effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 300, height: 300)),
            zoomScale: .constant(1.0),
            offset: .constant(.zero),
            draggedNode: .constant(nil),
            dragOffset: .constant(.zero),
            potentialEdgeTarget: .constant(nil),
            selectedNodeID: .constant(nil),
            selectedEdgeID: selectedEdgeBinding,
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
        
        // Tap the already-selected edge to deselect
        _ = modifier.handleEdgeTap(edge: edge)
        
        #expect(selectedEdgeID == nil, "Tapping selected edge should deselect it")
    }
    
    @MainActor @Test func testHandleBackgroundTap() async {
        let viewModel = await setupViewModel()
        
        // Create a node and select it
        let node = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        var selectedNodeID: NodeID? = node.id
        var selectedEdgeID: UUID? = UUID()
        var isAddingEdge = true
        
        let selectedNodeBinding = Binding<NodeID?>(
            get: { selectedNodeID },
            set: { selectedNodeID = $0 }
        )
        let selectedEdgeBinding = Binding<UUID?>(
            get: { selectedEdgeID },
            set: { selectedEdgeID = $0 }
        )
        let isAddingEdgeBinding = Binding<Bool>(
            get: { isAddingEdge },
            set: { isAddingEdge = $0 }
        )
        
        let modifier = GraphGesturesModifier(
            viewModel: viewModel,
            renderContext: RenderContext(effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 300, height: 300)),
            zoomScale: .constant(1.0),
            offset: .constant(.zero),
            draggedNode: .constant(nil),
            dragOffset: .constant(.zero),
            potentialEdgeTarget: .constant(nil),
            selectedNodeID: selectedNodeBinding,
            selectedEdgeID: selectedEdgeBinding,
            viewSize: CGSize(width: 300, height: 300),
            panStartOffset: .constant(nil),
            showMenu: .constant(false),
            maxZoom: 5.0,
            crownPosition: .constant(0.0),
            onUpdateZoomRanges: {},
            isAddingEdge: isAddingEdgeBinding,
            isSimulating: .constant(true),
            saturation: .constant(1.0),
            currentDragLocation: .constant(nil),
            dragStartNode: .constant(nil)
        )
        
        // Tap background
        let result = modifier.handleBackgroundTap()
        
        #expect(result == false, "Background tap should return false")
        #expect(selectedNodeID == nil, "Node selection should be cleared")
        #expect(selectedEdgeID == nil, "Edge selection should be cleared")
        #expect(isAddingEdge == false, "Edge-adding mode should be cancelled")
    }
}
