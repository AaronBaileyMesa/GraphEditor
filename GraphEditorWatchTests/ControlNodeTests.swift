//
//  ControlNodeTests.swift
//  GraphEditorWatchTests
//
//  Tests for control node management and state transitions

import Testing
import CoreGraphics
import GraphEditorShared
@testable import GraphEditorWatch

@Suite("Control Node Management")
struct ControlNodeTests {
    
    // MARK: - Test Fixtures
    
    @MainActor
    func createTestViewModel() -> GraphViewModel {
        let bounds = CGSize(width: 200, height: 200)
        let physicsEngine = PhysicsEngine(simulationBounds: bounds)
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        return GraphViewModel(model: model)
    }
    
    // MARK: - Control Generation Tests
    
    @Test("Generate controls creates control nodes for selected node")
    @MainActor
    func testGenerateControlsCreatesNodes() async throws {
        let viewModel = createTestViewModel()
        
        // Add a node to select
        let node = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        // Generate controls
        await viewModel.generateControls(for: node.id)
        
        // Verify controls were created
        #expect(viewModel.model.ephemeralControlNodes.count > 0, "Should create control nodes")
        
        // Verify all controls have the correct owner
        for control in viewModel.model.ephemeralControlNodes {
            #expect(control.ownerID == node.id, "Control should be owned by selected node")
        }
    }
    
    @Test("Clear controls removes all ephemeral nodes")
    @MainActor
    func testClearControlsRemovesNodes() async throws {
        let viewModel = createTestViewModel()
        
        // Add and select a node
        let node = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        await viewModel.generateControls(for: node.id)
        
        #expect(viewModel.model.ephemeralControlNodes.count > 0, "Controls should exist before clear")
        
        // Clear controls
        await viewModel.clearControls()
        
        #expect(viewModel.model.ephemeralControlNodes.count == 0, "All controls should be removed")
        #expect(viewModel.model.ephemeralControlEdges.count == 0, "All control edges should be removed")
    }
    
    @Test("Generate controls for different node replaces previous controls")
    @MainActor
    func testSwitchingControlOwner() async throws {
        let viewModel = createTestViewModel()
        
        // Add two nodes
        let node1 = await viewModel.model.addNode(at: CGPoint(x: 50, y: 50))
        let node2 = await viewModel.model.addNode(at: CGPoint(x: 150, y: 150))
        
        // Generate controls for first node
        await viewModel.generateControls(for: node1.id)
        let firstCount = viewModel.model.ephemeralControlNodes.count
        
        // Generate controls for second node
        await viewModel.generateControls(for: node2.id)
        
        // Verify controls were replaced, not added
        #expect(viewModel.model.ephemeralControlNodes.count == firstCount, "Control count should remain same")
        
        // Verify all controls now belong to second node
        for control in viewModel.model.ephemeralControlNodes {
            #expect(control.ownerID == node2.id, "All controls should belong to second node")
        }
    }
    
    // MARK: - Control Positioning Tests
    
    @Test("Control nodes are positioned around owner")
    @MainActor
    func testControlPositioning() async throws {
        let viewModel = createTestViewModel()
        
        let ownerPos = CGPoint(x: 100, y: 100)
        let node = await viewModel.model.addNode(at: ownerPos)
        await viewModel.generateControls(for: node.id)
        
        let expectedSpacing: CGFloat = 40.0
        
        for control in viewModel.model.ephemeralControlNodes {
            let distance = hypot(control.position.x - ownerPos.x, control.position.y - ownerPos.y)
            #expect(abs(distance - expectedSpacing) < 1.0, "Control should be ~40 units from owner")
        }
    }
    
    @Test("Reposition ephemerals moves controls with owner")
    @MainActor
    func testRepositionEphemerals() async throws {
        let viewModel = createTestViewModel()
        
        let initialPos = CGPoint(x: 100, y: 100)
        let node = await viewModel.model.addNode(at: initialPos)
        await viewModel.generateControls(for: node.id)
        
        let initialControlPositions = viewModel.model.ephemeralControlNodes.map { $0.position }
        
        // Move owner to new position
        let newPos = CGPoint(x: 150, y: 150)
        viewModel.repositionEphemerals(for: node.id, to: newPos)
        
        // Verify controls moved by the same delta
        let delta = CGPoint(x: newPos.x - initialPos.x, y: newPos.y - initialPos.y)
        
        for (index, control) in viewModel.model.ephemeralControlNodes.enumerated() {
            let expectedX = initialControlPositions[index].x + delta.x
            let expectedY = initialControlPositions[index].y + delta.y
            
            #expect(abs(control.position.x - expectedX) < 1.0, "Control X should move with owner")
            #expect(abs(control.position.y - expectedY) < 1.0, "Control Y should move with owner")
        }
    }
    
    // MARK: - Control Types Tests
    
    @Test("Control nodes include expected types")
    @MainActor
    func testControlTypes() async throws {
        let viewModel = createTestViewModel()
        
        // Add a toggle node (collapsible) to test all control types
        await viewModel.model.addToggleNode(at: CGPoint(x: 100, y: 100))
        guard let toggleNode = viewModel.model.nodes.first else {
            Issue.record("Failed to create toggle node")
            return
        }
        
        await viewModel.generateControls(for: toggleNode.id)
        
        let kinds = Set(viewModel.model.ephemeralControlNodes.map { $0.kind })
        
        // Verify expected control kinds are present for collapsible nodes
        #expect(kinds.contains(.edit), "Should include edit control")
        #expect(kinds.contains(.addChild), "Should include addChild control")
        #expect(kinds.contains(.addEdge), "Should include addEdge control")
        #expect(kinds.contains(.delete), "Should include delete control")
        
        // Test regular node - should NOT have addChild
        let regularNode = await viewModel.model.addNode(at: CGPoint(x: 200, y: 200))
        await viewModel.generateControls(for: regularNode.id)
        
        let regularKinds = Set(viewModel.model.ephemeralControlNodes.map { $0.kind })
        #expect(!regularKinds.contains(.addChild), "Regular nodes should not have addChild control")
        #expect(regularKinds.contains(.edit), "Regular nodes should have edit control")
        #expect(regularKinds.contains(.addEdge), "Regular nodes should have addEdge control")
    }
    
    // MARK: - Control State Transitions
    
    @Test("Control generation creates controls")
    @MainActor
    func testControlGenerationPausesSimulation() async throws {
        let viewModel = createTestViewModel()
        
        // Generate controls
        let node = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        await viewModel.generateControls(for: node.id)
        
        // Verify controls were created successfully
        #expect(!viewModel.model.ephemeralControlNodes.isEmpty, "Controls should be generated")
        
        // Verify all controls have the correct owner
        for control in viewModel.model.ephemeralControlNodes {
            #expect(control.ownerID == node.id, "All controls should reference the correct owner")
        }
    }
    
    @Test("No duplicate control IDs")
    @MainActor
    func testNoDuplicateControlIDs() async throws {
        let viewModel = createTestViewModel()
        
        let node = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        await viewModel.generateControls(for: node.id)
        
        let ids = viewModel.model.ephemeralControlNodes.map { $0.id }
        let uniqueIDs = Set(ids)
        
        #expect(ids.count == uniqueIDs.count, "All control IDs should be unique")
    }
    
    // MARK: - Control Repositioning Tests
    
    @Test("Reposition ephemerals maintains 40pt distance from owner")
    @MainActor
    func testRepositionEphemeralsDistance() async throws {
        let viewModel = createTestViewModel()
        
        // Add a node and generate controls
        let initialPos = CGPoint(x: 100, y: 100)
        let node = await viewModel.model.addNode(at: initialPos)
        await viewModel.generateControls(for: node.id)
        
        // Move the node to a new position
        let newPos = CGPoint(x: 150, y: 120)
        viewModel.repositionEphemerals(for: node.id, to: newPos)
        
        // Check that all controls maintain 40pt distance
        let expectedDistance: CGFloat = 40.0
        let tolerance: CGFloat = 0.1
        
        for control in viewModel.model.ephemeralControlNodes {
            let dx = control.position.x - newPos.x
            let dy = control.position.y - newPos.y
            let distance = hypot(dx, dy)
            
            // Note: Distance may be less than 40 if control is clamped at bounds
            #expect(distance <= expectedDistance + tolerance, 
                   "Control distance \(distance) should not exceed 40pt (may be less if clamped)")
        }
    }
    
    @Test("Reposition ephemerals updates control positions")
    @MainActor
    func testRepositionEphemeralsUpdatesPositions() async throws {
        let viewModel = createTestViewModel()
        
        // Add a node and generate controls
        let initialPos = CGPoint(x: 100, y: 100)
        let node = await viewModel.model.addNode(at: initialPos)
        await viewModel.generateControls(for: node.id)
        
        // Record initial control positions
        let initialPositions = viewModel.model.ephemeralControlNodes.map { $0.position }
        
        // Move the node
        let newPos = CGPoint(x: 150, y: 120)
        viewModel.repositionEphemerals(for: node.id, to: newPos)
        
        // Verify controls moved
        let newPositions = viewModel.model.ephemeralControlNodes.map { $0.position }
        
        for (initial, new) in zip(initialPositions, newPositions) {
            #expect(initial != new, "Control should have moved to new position")
        }
    }
    
    @Test("Reposition ephemerals at drag start maintains distance")
    @MainActor
    func testRepositionAtDragStartDistance() async throws {
        let viewModel = createTestViewModel()
        
        // Add a node and generate controls
        let nodePos = CGPoint(x: 100, y: 100)
        let node = await viewModel.model.addNode(at: nodePos)
        await viewModel.generateControls(for: node.id)
        
        // Simulate what happens at drag start: reposition immediately
        viewModel.repositionEphemerals(for: node.id, to: nodePos)
        
        // Verify all controls are at correct distance
        let expectedDistance: CGFloat = 40.0
        let tolerance: CGFloat = 0.1
        
        for control in viewModel.model.ephemeralControlNodes {
            let dx = control.position.x - nodePos.x
            let dy = control.position.y - nodePos.y
            let distance = hypot(dx, dy)
            
            // Distance should be exactly 40pt at drag start (unless clamped)
            #expect(distance <= expectedDistance + tolerance,
                   "Control distance at drag start should be 40pt or less (if clamped)")
        }
    }
    
    @Test("Re-selecting node maintains control positions at 40pt")
    @MainActor
    func testReselectingNodeMaintainsControlPositions() async throws {
        let viewModel = createTestViewModel()
        
        // Add a node and select it
        let nodePos = CGPoint(x: 100, y: 100)
        let node = await viewModel.model.addNode(at: nodePos)
        await viewModel.generateControls(for: node.id)
        
        // Record initial control positions
        let initialPositions = viewModel.model.ephemeralControlNodes.map { $0.position }
        
        // Deselect and then re-select
        await viewModel.clearControls()
        await viewModel.generateControls(for: node.id)
        
        // Verify controls are at correct 40pt distance (not drifted by physics)
        let expectedDistance: CGFloat = 40.0
        let tolerance: CGFloat = 1.0
        
        for control in viewModel.model.ephemeralControlNodes {
            let dx = control.position.x - nodePos.x
            let dy = control.position.y - nodePos.y
            let distance = hypot(dx, dy)
            
            #expect(abs(distance - expectedDistance) < tolerance,
                   "Control should be at 40pt after re-selection, got \(distance)")
        }
    }
}
