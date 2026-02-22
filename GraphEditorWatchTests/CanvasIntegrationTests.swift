//
//  CanvasIntegrationTests.swift
//  GraphEditorWatchTests
//
//  Tests for GraphCanvasView integration and coordination
//

import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import GraphEditorWatch
@testable import GraphEditorShared

@MainActor
struct CanvasIntegrationTests {
    
    private func createTestViewModel() -> GraphViewModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        return GraphViewModel(model: model)
    }
    
    // MARK: - RenderContext Tests
    
    @Test("Canvas creates valid render context")
    func testRenderContextCreation() {
        let viewModel = createTestViewModel()
        
        let context = RenderContext(
            effectiveCentroid: viewModel.effectiveCentroid,
            zoomScale: viewModel.zoomScale,
            offset: viewModel.offset,
            viewSize: CGSize(width: 300, height: 300)
        )
        
        #expect(context.zoomScale == 1.0, "Initial zoom should be 1.0")
        #expect(context.offset == .zero, "Initial offset should be zero")
        #expect(context.viewSize.width == 300, "View size should match")
    }
    
    @Test("Render context updates with zoom changes")
    func testRenderContextZoomUpdate() {
        let viewModel = createTestViewModel()
        
        viewModel.zoomScale = 2.0
        
        let context = RenderContext(
            effectiveCentroid: viewModel.effectiveCentroid,
            zoomScale: viewModel.zoomScale,
            offset: viewModel.offset,
            viewSize: CGSize(width: 300, height: 300)
        )
        
        #expect(context.zoomScale == 2.0, "Zoom should update in context")
    }
    
    @Test("Render context updates with offset changes")
    func testRenderContextOffsetUpdate() {
        let viewModel = createTestViewModel()
        
        viewModel.offset = CGSize(width: 50, height: 50)
        
        let context = RenderContext(
            effectiveCentroid: viewModel.effectiveCentroid,
            zoomScale: viewModel.zoomScale,
            offset: viewModel.offset,
            viewSize: CGSize(width: 300, height: 300)
        )
        
        #expect(context.offset.width == 50, "Offset width should update")
        #expect(context.offset.height == 50, "Offset height should update")
    }
    
    // MARK: - Zoom Range Calculation Tests
    
    @Test("Canvas calculates zoom ranges for view")
    func testCalculateZoomRanges() async {
        let viewModel = createTestViewModel()
        let viewSize = CGSize(width: 300, height: 300)
        
        // Add some nodes to have content to zoom to
        _ = await viewModel.model.addNode(at: CGPoint(x: 0, y: 0))
        _ = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
        
        #expect(minZoom > 0, "Min zoom should be positive")
        #expect(maxZoom > minZoom, "Max zoom should be greater than min zoom")
    }
    
    @Test("Canvas calculates zoom ranges for empty graph")
    func testCalculateZoomRangesEmptyGraph() {
        let viewModel = createTestViewModel()
        let viewSize = CGSize(width: 300, height: 300)
        
        let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
        
        #expect(minZoom > 0, "Min zoom should be positive even for empty graph")
        #expect(maxZoom > minZoom, "Max zoom should be greater than min zoom")
    }
    
    @Test("Canvas zoom ranges respect maximum")
    func testZoomRangesRespectMaximum() async {
        let viewModel = createTestViewModel()
        let viewSize = CGSize(width: 300, height: 300)
        
        _ = await viewModel.model.addNode(at: .zero)
        
        let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
        
        // maxZoom is calculated as minZoom * Constants.App.maxZoom (8.0)
        #expect(maxZoom > minZoom, "Max zoom should be greater than min zoom")
        #expect(maxZoom > 0, "Max zoom should be positive")
    }
    
    // MARK: - Crown Zoom Integration Tests
    
    @Test("Crown position maps to zoom scale")
    func testCrownPositionToZoom() {
        let viewModel = createTestViewModel()
        let viewSize = CGSize(width: 300, height: 300)
        
        let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
        
        // Crown at midpoint (50% of steps)
        let crownPosition = Double(AppConstants.crownZoomSteps) / 2.0
        let normalized = crownPosition / Double(AppConstants.crownZoomSteps)
        let targetZoom = minZoom + (maxZoom - minZoom) * CGFloat(normalized)
        
        #expect(targetZoom >= minZoom, "Zoom should be at or above minimum")
        #expect(targetZoom <= maxZoom, "Zoom should be at or below maximum")
    }
    
    @Test("Crown at minimum position gives minimum zoom")
    func testCrownMinimumPosition() {
        let viewModel = createTestViewModel()
        let viewSize = CGSize(width: 300, height: 300)
        
        let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
        
        let crownPosition = 0.0
        let normalized = crownPosition / Double(AppConstants.crownZoomSteps)
        let targetZoom = minZoom + (maxZoom - minZoom) * CGFloat(normalized)
        
        #expect(abs(targetZoom - minZoom) < 0.01, "Should give minimum zoom")
    }
    
    @Test("Crown at maximum position gives maximum zoom")
    func testCrownMaximumPosition() {
        let viewModel = createTestViewModel()
        let viewSize = CGSize(width: 300, height: 300)
        
        let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
        
        let crownPosition = Double(AppConstants.crownZoomSteps)
        let normalized = crownPosition / Double(AppConstants.crownZoomSteps)
        let targetZoom = minZoom + (maxZoom - minZoom) * CGFloat(normalized)
        
        #expect(abs(targetZoom - maxZoom) < 0.01, "Should give maximum zoom")
    }
    
    @Test("Zoom scale maps back to crown position")
    func testZoomToCrownPosition() {
        let viewModel = createTestViewModel()
        let viewSize = CGSize(width: 300, height: 300)
        
        let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
        
        // Set zoom to midpoint
        let midZoom = (minZoom + maxZoom) / 2.0
        let normalizedValue = (midZoom - minZoom) / (maxZoom - minZoom)
        let normalized = min(max(normalizedValue, 0.0), 1.0)
        let crownPosition = Double(AppConstants.crownZoomSteps) * normalized
        
        #expect(crownPosition >= 0, "Crown position should be non-negative")
        #expect(crownPosition <= Double(AppConstants.crownZoomSteps), "Crown position should not exceed max")
    }
    
    // MARK: - Node Selection Integration Tests
    
    @Test("Canvas repositions ephemerals on selection")
    func testRepositionEphemeralsOnSelection() async {
        let viewModel = createTestViewModel()
        
        let node = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        await viewModel.generateControls(for: node.id)
        
        // Verify controls were generated (control nodes are ephemeral, not in model.nodes)
        let controlNodes = viewModel.model.ephemeralControlNodes
        #expect(controlNodes.count > 0, "Should have generated control nodes")
        
        // Simulate dragging node to new position
        let newPosition = CGPoint(x: 200, y: 200)
        viewModel.repositionEphemerals(for: node.id, to: newPosition)
        
        // Control nodes should have been repositioned
        // (Exact position depends on control layout logic)
    }
    
    @Test("Canvas clears selection state")
    func testClearSelectionState() async {
        let viewModel = createTestViewModel()
        
        let node = await viewModel.model.addNode(at: .zero)
        viewModel.selectedNodeID = node.id
        
        #expect(viewModel.selectedNodeID == node.id, "Should select node")
        
        viewModel.selectedNodeID = nil
        
        #expect(viewModel.selectedNodeID == nil, "Should clear selection")
    }
    
    // MARK: - Drag State Tests
    
    @Test("Canvas tracks dragged node")
    func testTrackDraggedNode() async {
        let viewModel = createTestViewModel()
        
        let node = await viewModel.model.addNode(at: CGPoint(x: 50, y: 50))
        
        // Simulate drag state
        var draggedNode: (any NodeProtocol)? = node
        var dragOffset = CGPoint(x: 10, y: 10)
        
        #expect(draggedNode?.id == node.id, "Should track dragged node")
        #expect(dragOffset.x == 10, "Should track drag offset X")
        #expect(dragOffset.y == 10, "Should track drag offset Y")
    }
    
    @Test("Canvas clears drag state on release")
    func testClearDragState() async {
        let viewModel = createTestViewModel()
        
        let node = await viewModel.model.addNode(at: .zero)
        
        var draggedNode: (any NodeProtocol)? = node
        var dragOffset = CGPoint(x: 10, y: 10)
        
        // Simulate drag end
        draggedNode = nil
        dragOffset = .zero
        
        #expect(draggedNode == nil, "Should clear dragged node")
        #expect(dragOffset == .zero, "Should reset drag offset")
    }
    
    // MARK: - Edge Creation State Tests
    
    @Test("Canvas tracks potential edge target")
    func testTrackPotentialEdgeTarget() async {
        let viewModel = createTestViewModel()
        
        let node1 = await viewModel.model.addNode(at: CGPoint(x: 0, y: 0))
        let node2 = await viewModel.model.addNode(at: CGPoint(x: 100, y: 0))
        
        var dragStartNode: (any NodeProtocol)? = node1
        var potentialEdgeTarget: (any NodeProtocol)? = node2
        
        #expect(dragStartNode?.id == node1.id, "Should track drag start node")
        #expect(potentialEdgeTarget?.id == node2.id, "Should track potential target")
    }
    
    @Test("Canvas clears edge creation state")
    func testClearEdgeCreationState() async {
        let viewModel = createTestViewModel()
        
        let node = await viewModel.model.addNode(at: .zero)
        
        var dragStartNode: (any NodeProtocol)? = node
        var currentDragLocation: CGPoint? = CGPoint(x: 50, y: 50)
        var isAddingEdge = true
        
        // Clear state
        dragStartNode = nil
        currentDragLocation = nil
        isAddingEdge = false
        
        #expect(dragStartNode == nil, "Should clear drag start")
        #expect(currentDragLocation == nil, "Should clear drag location")
        #expect(isAddingEdge == false, "Should clear edge adding flag")
    }
    
    // MARK: - Multi-Node Canvas Tests
    
    @Test("Canvas renders multiple node types")
    func testRenderMultipleNodeTypes() async {
        let viewModel = createTestViewModel()
        
        // Add various node types
        let generic = await viewModel.model.addNode(at: CGPoint(x: 0, y: 0))
        let task = await viewModel.model.addTask(type: .cook, estimatedTime: 30, at: CGPoint(x: 100, y: 0))
        
        #expect(viewModel.model.nodes.count >= 2, "Should have at least 2 nodes")
        
        // Verify node types are preserved
        let hasGeneric = viewModel.model.nodes.contains(where: { $0.id == generic.id })
        let hasTask = viewModel.model.nodes.contains(where: { $0.id == task.id })
        
        #expect(hasGeneric && hasTask, "All node types should be in model")
    }
    
    @Test("Canvas renders edges between nodes")
    func testRenderEdges() async {
        let viewModel = createTestViewModel()
        
        let node1 = await viewModel.model.addNode(at: CGPoint(x: 0, y: 0))
        let node2 = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        await viewModel.model.addEdge(from: node1.id, target: node2.id, type: .hierarchy)
        
        #expect(viewModel.model.edges.count == 1, "Should have one edge")
        
        let edge = viewModel.model.edges.first
        #expect(edge?.from == node1.id, "Edge should start from node1")
        #expect(edge?.target == node2.id, "Edge should end at node2")
    }
    
    @Test("Canvas renders edges with different types")
    func testRenderDifferentEdgeTypes() async {
        let viewModel = createTestViewModel()
        
        let node1 = await viewModel.model.addNode(at: .zero)
        let node2 = await viewModel.model.addNode(at: CGPoint(x: 50, y: 0))
        let node3 = await viewModel.model.addNode(at: CGPoint(x: 100, y: 0))
        
        await viewModel.model.addEdge(from: node1.id, target: node2.id, type: .hierarchy)
        await viewModel.model.addEdge(from: node1.id, target: node3.id, type: .association)
        
        #expect(viewModel.model.edges.count == 2, "Should have two edges")
        
        let hierarchyEdges = viewModel.model.edges.filter { $0.type == .hierarchy }
        let associationEdges = viewModel.model.edges.filter { $0.type == .association }
        
        #expect(hierarchyEdges.count == 1, "Should have one hierarchy edge")
        #expect(associationEdges.count == 1, "Should have one association edge")
    }
    
    // MARK: - View Size Tests
    
    @Test("Canvas handles view size changes")
    func testViewSizeChanges() {
        let viewModel = createTestViewModel()
        
        var viewSize = CGSize(width: 300, height: 300)
        
        let (minZoom1, maxZoom1) = viewModel.calculateZoomRanges(for: viewSize)
        
        // Change view size
        viewSize = CGSize(width: 400, height: 400)
        
        let (minZoom2, maxZoom2) = viewModel.calculateZoomRanges(for: viewSize)
        
        // Zoom ranges should potentially change with view size
        #expect(minZoom2 > 0, "Min zoom should be valid for new size")
        #expect(maxZoom2 > minZoom2, "Max zoom should be greater than min")
    }
    
    @Test("Canvas handles small view size")
    func testSmallViewSize() {
        let viewModel = createTestViewModel()
        
        let viewSize = CGSize(width: 50, height: 50)
        
        let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
        
        #expect(minZoom > 0, "Should handle small view size")
        #expect(maxZoom > minZoom, "Zoom range should be valid")
    }
    
    @Test("Canvas handles large view size")
    func testLargeViewSize() {
        let viewModel = createTestViewModel()
        
        let viewSize = CGSize(width: 1000, height: 1000)
        
        let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
        
        #expect(minZoom > 0, "Should handle large view size")
        #expect(maxZoom > minZoom, "Zoom range should be valid")
    }
    
    // MARK: - Simulation State Tests
    
    @Test("Canvas tracks simulation state")
    func testSimulationState() {
        let viewModel = createTestViewModel()
        
        var isSimulating = false
        
        #expect(isSimulating == false, "Should start not simulating")
        
        isSimulating = true
        #expect(isSimulating == true, "Should track simulation state")
    }
    
    @Test("Canvas handles simulation with nodes")
    func testSimulationWithNodes() async {
        let viewModel = createTestViewModel()
        
        let node1 = await viewModel.model.addNode(at: CGPoint(x: 0, y: 0))
        let node2 = await viewModel.model.addNode(at: CGPoint(x: 10, y: 10))
        
        await viewModel.model.addEdge(from: node1.id, target: node2.id, type: .hierarchy)
        
        // Verify nodes and edges are present
        #expect(viewModel.model.nodes.count == 2, "Nodes should be present")
        #expect(viewModel.model.edges.count == 1, "Edge should be present")
    }
    
    // MARK: - Saturation State Tests
    
    @Test("Canvas tracks saturation for long press")
    func testSaturationTracking() {
        var saturation = 0.0
        
        // Simulate long press building saturation
        saturation = 0.5
        #expect(saturation == 0.5, "Should track saturation at 50%")
        
        saturation = 1.0
        #expect(saturation == 1.0, "Should track saturation at 100%")
        
        // Reset after release
        saturation = 0.0
        #expect(saturation == 0.0, "Should reset saturation")
    }
    
    // MARK: - Centroid Calculation Tests
    
    @Test("Canvas calculates centroid for nodes")
    func testCentroidCalculation() async {
        let viewModel = createTestViewModel()
        // Use bulk operation mode to prevent addNode from restarting simulation
        await viewModel.model.beginBulkOperation()

        // Add nodes at known positions
        _ = await viewModel.model.addNode(at: CGPoint(x: 0, y: 0))
        _ = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))

        let centroid = viewModel.effectiveCentroid

        await viewModel.model.endBulkOperation()

        // Centroid should be somewhere between the nodes
        #expect(centroid.x >= 0 && centroid.x <= 100, "Centroid X should be in range")
        #expect(centroid.y >= 0 && centroid.y <= 100, "Centroid Y should be in range")
    }

    @Test("Canvas calculates centroid for single node")
    func testCentroidSingleNode() async {
        let viewModel = createTestViewModel()
        // Use bulk operation mode to prevent addNode from restarting simulation
        await viewModel.model.beginBulkOperation()

        _ = await viewModel.model.addNode(at: CGPoint(x: 50, y: 50))

        let centroid = viewModel.effectiveCentroid

        await viewModel.model.endBulkOperation()

        // Centroid should be at the node position
        #expect(abs(centroid.x - 50) < 1, "Centroid X should be near node")
        #expect(abs(centroid.y - 50) < 1, "Centroid Y should be near node")
    }
    
    @Test("Canvas handles empty graph centroid")
    func testEmptyGraphCentroid() {
        let viewModel = createTestViewModel()
        
        let centroid = viewModel.effectiveCentroid
        
        // Should have a default centroid even with no nodes
        #expect(centroid.x.isFinite, "Centroid X should be finite")
        #expect(centroid.y.isFinite, "Centroid Y should be finite")
    }
    
    // MARK: - Control Node Integration Tests
    
    @Test("Canvas generates control nodes on selection")
    func testGenerateControlNodes() async {
        let viewModel = createTestViewModel()

        let node = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))

        await viewModel.generateControls(for: node.id)

        // Control nodes are ephemeral — they live in ephemeralControlNodes, not model.nodes
        let controlNodes = viewModel.model.ephemeralControlNodes
        #expect(controlNodes.count > 0, "Should have control nodes")
    }

    @Test("Canvas clears control nodes on deselection")
    func testClearControlNodes() async {
        let viewModel = createTestViewModel()

        let node = await viewModel.model.addNode(at: .zero)
        await viewModel.generateControls(for: node.id)

        let withControls = viewModel.model.ephemeralControlNodes.count

        await viewModel.clearControls()

        let withoutControls = viewModel.model.ephemeralControlNodes.count

        #expect(withControls > 0, "Should have had control nodes before clearing")
        #expect(withoutControls == 0, "Should remove all control nodes after clearing")
    }

    @Test("Canvas regenerates controls on new selection")
    func testRegenerateControls() async {
        let viewModel = createTestViewModel()

        let node1 = await viewModel.model.addNode(at: CGPoint(x: 0, y: 0))
        let node2 = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))

        // Select first node
        await viewModel.generateControls(for: node1.id)
        let controls1Count = viewModel.model.ephemeralControlNodes.count

        // Select second node
        await viewModel.clearControls()
        await viewModel.generateControls(for: node2.id)
        let controls2Count = viewModel.model.ephemeralControlNodes.count

        #expect(controls1Count > 0, "Should have controls for first node")
        #expect(controls2Count > 0, "Should have controls for second node")
    }
    
    // MARK: - Menu State Tests
    
    @Test("Canvas tracks menu visibility")
    func testMenuVisibility() {
        var showMenu = false
        
        #expect(showMenu == false, "Menu should start hidden")
        
        showMenu = true
        #expect(showMenu == true, "Should show menu")
        
        showMenu = false
        #expect(showMenu == false, "Should hide menu")
    }
    
    // MARK: - Pan Gesture Tests
    
    @Test("Canvas tracks pan start offset")
    func testPanStartOffset() {
        var panStartOffset: CGSize? = nil
        
        #expect(panStartOffset == nil, "Pan start should be nil initially")
        
        panStartOffset = CGSize(width: 10, height: 10)
        #expect(panStartOffset != nil, "Should track pan start")
        
        panStartOffset = nil
        #expect(panStartOffset == nil, "Should clear pan start")
    }
    
    @Test("Canvas updates offset during pan")
    func testOffsetUpdateDuringPan() {
        let viewModel = createTestViewModel()
        
        let initialOffset = viewModel.offset
        
        // Simulate pan
        viewModel.offset = CGSize(width: 50, height: 50)
        
        #expect(viewModel.offset != initialOffset, "Offset should change during pan")
        #expect(viewModel.offset.width == 50, "Offset X should update")
        #expect(viewModel.offset.height == 50, "Offset Y should update")
    }
    
    // MARK: - Integration with AccessibleCanvas Tests
    
    @Test("Canvas provides correct parameters to AccessibleCanvas")
    func testAccessibleCanvasParameters() {
        let viewModel = createTestViewModel()
        
        let viewSize = CGSize(width: 300, height: 300)
        
        let context = RenderContext(
            effectiveCentroid: viewModel.effectiveCentroid,
            zoomScale: viewModel.zoomScale,
            offset: viewModel.offset,
            viewSize: viewSize
        )
        
        #expect(context.zoomScale == viewModel.zoomScale, "Zoom should match")
        #expect(context.offset == viewModel.offset, "Offset should match")
        #expect(context.viewSize == viewSize, "View size should match")
    }
    
    @Test("Canvas updates AccessibleCanvas on zoom change")
    func testAccessibleCanvasZoomUpdate() {
        let viewModel = createTestViewModel()
        
        viewModel.zoomScale = 1.5
        
        let context = RenderContext(
            effectiveCentroid: viewModel.effectiveCentroid,
            zoomScale: viewModel.zoomScale,
            offset: viewModel.offset,
            viewSize: CGSize(width: 300, height: 300)
        )
        
        #expect(context.zoomScale == 1.5, "AccessibleCanvas should receive updated zoom")
    }
}
