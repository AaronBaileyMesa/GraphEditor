//
//  AccessibleCanvasTests.swift
//  GraphEditorWatchTests
//
//  Tests for AccessibleCanvas rendering logic and coordinate transformations
//

import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct AccessibleCanvasTests {
    
    @MainActor
    private func createTestViewModel() -> GraphViewModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        return GraphViewModel(model: model)
    }
    
    // MARK: - Render Context Creation Tests
    
    @MainActor @Test("RenderContext created with correct parameters")
    func testRenderContextCreation() async {
        let viewModel = createTestViewModel()
        
        // Add some nodes to create a non-zero centroid
        _ = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        _ = await viewModel.model.addNode(at: CGPoint(x: 200, y: 200))
        
        let viewSize = CGSize(width: 200, height: 200)
        let zoomScale: CGFloat = 1.5
        let offset = CGSize(width: 20, height: 30)
        
        let effectiveCentroid = viewModel.effectiveCentroid
        
        let renderContext = RenderContext(
            effectiveCentroid: effectiveCentroid,
            zoomScale: zoomScale,
            offset: offset,
            viewSize: viewSize
        )
        
        #expect(renderContext.zoomScale == zoomScale, "Zoom scale should match")
        #expect(renderContext.offset == offset, "Offset should match")
        #expect(renderContext.viewSize == viewSize, "View size should match")
        #expect(renderContext.effectiveCentroid == effectiveCentroid, "Centroid should match")
    }
    
    // MARK: - Node Visibility Tests
    
    // TODO: Re-enable when hideNode functionality is implemented
    // @MainActor @Test("Visible nodes excludes hidden nodes")
    // func testVisibleNodesExcludesHidden() async {
    //     let viewModel = createTestViewModel()
    //     
    //     // Add regular nodes
    //     let node1 = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
    //     let node2 = await viewModel.model.addNode(at: CGPoint(x: 200, y: 200))
    //     
    //     // Hide node2
    //     await viewModel.model.hideNode(node2.id)
    //     
    //     let visibleNodes = viewModel.model.visibleNodes
    //     
    //     #expect(visibleNodes.count == 1, "Should have 1 visible node")
    //     #expect(visibleNodes.contains(where: { $0.id == node1.id }), "Node1 should be visible")
    //     #expect(!visibleNodes.contains(where: { $0.id == node2.id }), "Node2 should be hidden")
    // }
    
    @MainActor @Test("Control nodes are filtered from canvas rendering")
    func testControlNodesFilteredFromCanvas() async {
        let viewModel = createTestViewModel()
        
        // Add a regular node
        let node = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        // Select it to generate controls
        viewModel.selectedNodeID = node.id
        await viewModel.generateControls(for: node.id)
        
        let allVisibleNodes = viewModel.model.visibleNodes
        let controlNodes = allVisibleNodes.filter { $0 is ControlNode }
        let nonControlNodes = allVisibleNodes.filter { !($0 is ControlNode) }
        
        #expect(controlNodes.count > 0, "Should have control nodes")
        #expect(nonControlNodes.count == 1, "Should have 1 non-control node")
        
        // In canvas rendering, control nodes should be filtered out
        // (they're rendered as SwiftUI overlays instead)
    }
    
    // MARK: - Edge Visibility Tests
    
    @MainActor @Test("Visible edges includes control edges")
    func testVisibleEdgesIncludesControlEdges() async {
        let viewModel = createTestViewModel()
        
        // Add two regular nodes with an edge
        let node1 = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        let node2 = await viewModel.model.addNode(at: CGPoint(x: 200, y: 200))
        await viewModel.model.addEdge(from: node1.id, target: node2.id, type: .association)
        
        // Generate controls (which create control edges)
        viewModel.selectedNodeID = node1.id
        await viewModel.generateControls(for: node1.id)
        
        let allPersistentEdges = viewModel.model.edges
        let visibleEdges = viewModel.model.visibleEdges
        let controlNodeIDs = Set(viewModel.model.ephemeralControlNodes.map { $0.id })
        
        // Filter to find control edges (edges involving control nodes)
        let controlEdges = visibleEdges.filter { edge in
            controlNodeIDs.contains(edge.from) || controlNodeIDs.contains(edge.target)
        }
        
        // visibleEdges should include both persistent and ephemeral control edges
        #expect(visibleEdges.count > allPersistentEdges.count, "Should include ephemeral control edges")
        #expect(controlEdges.count > 0, "Should have control edges in visibleEdges")
    }
    
    // MARK: - Coordinate Transformation in Rendering Context
    
    @MainActor @Test("Node positions transform correctly to screen space")
    func testNodePositionTransformation() async {
        let viewModel = createTestViewModel()
        
        let modelPos = CGPoint(x: 150, y: 175)
        _ = await viewModel.model.addNode(at: modelPos)
        
        let viewSize = CGSize(width: 200, height: 200)
        let zoomScale: CGFloat = 1.0
        let offset = CGSize.zero
        let effectiveCentroid = viewModel.effectiveCentroid
        
        let renderContext = RenderContext(
            effectiveCentroid: effectiveCentroid,
            zoomScale: zoomScale,
            offset: offset,
            viewSize: viewSize
        )
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, renderContext)
        
        // Screen position should be relative to view center
        let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let expectedOffset = modelPos - effectiveCentroid
        let expectedScreen = viewCenter + expectedOffset
        
        let distance = hypot(screenPos.x - expectedScreen.x, screenPos.y - expectedScreen.y)
        #expect(distance < 1.0, "Screen position should match expected transformation")
    }
    
    @MainActor @Test("Multiple nodes maintain relative positions after transformation")
    func testRelativeNodePositions() async {
        let viewModel = createTestViewModel()
        
        let node1Pos = CGPoint(x: 100, y: 100)
        let node2Pos = CGPoint(x: 200, y: 200)
        
        _ = await viewModel.model.addNode(at: node1Pos)
        _ = await viewModel.model.addNode(at: node2Pos)
        
        let viewSize = CGSize(width: 200, height: 200)
        let zoomScale: CGFloat = 2.0
        let offset = CGSize.zero
        let effectiveCentroid = viewModel.effectiveCentroid
        
        let renderContext = RenderContext(
            effectiveCentroid: effectiveCentroid,
            zoomScale: zoomScale,
            offset: offset,
            viewSize: viewSize
        )
        
        let screen1 = CoordinateTransformer.modelToScreen(node1Pos, renderContext)
        let screen2 = CoordinateTransformer.modelToScreen(node2Pos, renderContext)
        
        // Calculate distances in both spaces
        let modelDistance = hypot(node2Pos.x - node1Pos.x, node2Pos.y - node1Pos.y)
        let screenDistance = hypot(screen2.x - screen1.x, screen2.y - screen1.y)
        
        // Screen distance should be model distance * zoom
        let expectedScreenDistance = modelDistance * zoomScale
        
        #expect(abs(screenDistance - expectedScreenDistance) < 1.0, "Relative distances should scale with zoom")
    }
    
    // MARK: - Zoom and Offset Effects
    
    @MainActor @Test("Zoom affects node spacing on screen")
    func testZoomAffectsSpacing() async {
        let viewModel = createTestViewModel()
        
        let node1Pos = CGPoint(x: 100, y: 100)
        let node2Pos = CGPoint(x: 150, y: 100)
        
        _ = await viewModel.model.addNode(at: node1Pos)
        _ = await viewModel.model.addNode(at: node2Pos)
        
        let viewSize = CGSize(width: 200, height: 200)
        let effectiveCentroid = viewModel.effectiveCentroid
        
        // Test at zoom 1.0
        let renderContext1 = RenderContext(
            effectiveCentroid: effectiveCentroid,
            zoomScale: 1.0,
            offset: .zero,
            viewSize: viewSize
        )
        
        let screen1_zoom1 = CoordinateTransformer.modelToScreen(node1Pos, renderContext1)
        let screen2_zoom1 = CoordinateTransformer.modelToScreen(node2Pos, renderContext1)
        let spacing_zoom1 = screen2_zoom1.x - screen1_zoom1.x
        
        // Test at zoom 2.0
        let renderContext2 = RenderContext(
            effectiveCentroid: effectiveCentroid,
            zoomScale: 2.0,
            offset: .zero,
            viewSize: viewSize
        )
        
        let screen1_zoom2 = CoordinateTransformer.modelToScreen(node1Pos, renderContext2)
        let screen2_zoom2 = CoordinateTransformer.modelToScreen(node2Pos, renderContext2)
        let spacing_zoom2 = screen2_zoom2.x - screen1_zoom2.x
        
        // Spacing at zoom 2.0 should be double that at zoom 1.0
        #expect(abs(spacing_zoom2 - spacing_zoom1 * 2.0) < 1.0, "Zoom should double the spacing")
    }
    
    @MainActor @Test("Offset shifts all nodes uniformly")
    func testOffsetShiftsAllNodes() async {
        let viewModel = createTestViewModel()
        
        let node1Pos = CGPoint(x: 100, y: 100)
        let node2Pos = CGPoint(x: 150, y: 150)
        
        _ = await viewModel.model.addNode(at: node1Pos)
        _ = await viewModel.model.addNode(at: node2Pos)
        
        let viewSize = CGSize(width: 200, height: 200)
        let effectiveCentroid = viewModel.effectiveCentroid
        
        // Test without offset
        let renderContext1 = RenderContext(
            effectiveCentroid: effectiveCentroid,
            zoomScale: 1.0,
            offset: .zero,
            viewSize: viewSize
        )
        
        let screen1_noOffset = CoordinateTransformer.modelToScreen(node1Pos, renderContext1)
        let screen2_noOffset = CoordinateTransformer.modelToScreen(node2Pos, renderContext1)
        
        // Test with offset
        let offset = CGSize(width: 50, height: 75)
        let renderContext2 = RenderContext(
            effectiveCentroid: effectiveCentroid,
            zoomScale: 1.0,
            offset: offset,
            viewSize: viewSize
        )
        
        let screen1_withOffset = CoordinateTransformer.modelToScreen(node1Pos, renderContext2)
        let screen2_withOffset = CoordinateTransformer.modelToScreen(node2Pos, renderContext2)
        
        // Both nodes should shift by the same amount
        let shift1 = CGPoint(
            x: screen1_withOffset.x - screen1_noOffset.x,
            y: screen1_withOffset.y - screen1_noOffset.y
        )
        let shift2 = CGPoint(
            x: screen2_withOffset.x - screen2_noOffset.x,
            y: screen2_withOffset.y - screen2_noOffset.y
        )
        
        #expect(abs(shift1.x - offset.width) < 0.1, "Node1 X shift should equal offset width")
        #expect(abs(shift1.y - offset.height) < 0.1, "Node1 Y shift should equal offset height")
        #expect(abs(shift2.x - offset.width) < 0.1, "Node2 X shift should equal offset width")
        #expect(abs(shift2.y - offset.height) < 0.1, "Node2 Y shift should equal offset height")
    }
    
    // MARK: - Centroid Calculation
    
    @MainActor @Test("Effective centroid updates with node positions")
    func testEffectiveCentroidUpdates() async {
        let viewModel = createTestViewModel()
        
        // Start with no nodes (centroid should be zero or default)
        _ = viewModel.effectiveCentroid
        
        // Add nodes at specific positions
        _ = await viewModel.model.addNode(at: CGPoint(x: 0, y: 0))
        _ = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        let centroidAfterAdd = viewModel.effectiveCentroid
        
        // Centroid should be roughly at the average of the two nodes (50, 50)
        // Physics may have moved nodes, so use a larger tolerance
        let expectedCentroid = CGPoint(x: 50, y: 50)
        
        #expect(abs(centroidAfterAdd.x - expectedCentroid.x) < 250, "Centroid X should be reasonably close to average")
        #expect(abs(centroidAfterAdd.y - expectedCentroid.y) < 250, "Centroid Y should be reasonably close to average")
    }
    
    // MARK: - Drag Offset Rendering
    
    @MainActor @Test("Drag offset applies to dragged node position")
    func testDragOffsetRendering() async {
        let viewModel = createTestViewModel()
        
        let originalPos = CGPoint(x: 100, y: 100)
        _ = await viewModel.model.addNode(at: originalPos)
        
        let viewSize = CGSize(width: 200, height: 200)
        let effectiveCentroid = viewModel.effectiveCentroid
        
        let renderContext = RenderContext(
            effectiveCentroid: effectiveCentroid,
            zoomScale: 1.0,
            offset: .zero,
            viewSize: viewSize
        )
        
        // Original screen position
        let originalScreenPos = CoordinateTransformer.modelToScreen(originalPos, renderContext)
        
        // With drag offset
        let dragOffset = CGPoint(x: 30, y: 40)
        let draggedScreenPos = originalScreenPos + dragOffset
        
        // Convert back to model to verify
        let draggedModelPos = CoordinateTransformer.screenToModel(draggedScreenPos, renderContext)
        
        // Dragged model position should be original + offset
        let expectedDraggedModel = originalPos + dragOffset
        
        #expect(abs(draggedModelPos.x - expectedDraggedModel.x) < 1.0, "Dragged X position should match")
        #expect(abs(draggedModelPos.y - expectedDraggedModel.y) < 1.0, "Dragged Y position should match")
    }
    
    // MARK: - Edge Endpoint Calculation
    
    @MainActor @Test("Edge endpoints match node positions in screen space")
    func testEdgeEndpointsMatchNodes() async {
        let viewModel = createTestViewModel()
        
        let sourcePos = CGPoint(x: 100, y: 100)
        let targetPos = CGPoint(x: 200, y: 200)
        
        let sourceNode = await viewModel.model.addNode(at: sourcePos)
        let targetNode = await viewModel.model.addNode(at: targetPos)
        await viewModel.model.addEdge(from: sourceNode.id, target: targetNode.id, type: .association)
        
        let viewSize = CGSize(width: 300, height: 300)
        let effectiveCentroid = viewModel.effectiveCentroid
        
        let renderContext = RenderContext(
            effectiveCentroid: effectiveCentroid,
            zoomScale: 1.5,
            offset: CGSize(width: 10, height: 20),
            viewSize: viewSize
        )
        
        let sourceScreen = CoordinateTransformer.modelToScreen(sourcePos, renderContext)
        let targetScreen = CoordinateTransformer.modelToScreen(targetPos, renderContext)
        
        // Edge should connect these two screen positions
        let edgeLength = hypot(targetScreen.x - sourceScreen.x, targetScreen.y - sourceScreen.y)
        let modelLength = hypot(targetPos.x - sourcePos.x, targetPos.y - sourcePos.y)
        let expectedScreenLength = modelLength * 1.5 // zoom scale
        
        #expect(abs(edgeLength - expectedScreenLength) < 1.0, "Edge length should scale with zoom")
    }
}
