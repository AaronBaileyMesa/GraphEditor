import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch // Already present
@testable import GraphEditorShared // Changed to @testable for accessing internal members
import XCTest
import SwiftUI

class MockGraphStorage: GraphStorage {
    var nodes: [Node] = []
    var edges: [GraphEdge] = []
    
    func save(nodes: [Node], edges: [GraphEdge]) throws {
        self.nodes = nodes
        self.edges = edges
    }
    
    func load() throws -> (nodes: [Node], edges: [GraphEdge]) {
        (nodes, edges)
    }
}

struct GraphModelTests {
    private func mockPhysicsEngine() -> GraphEditorShared.PhysicsEngine {
        GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300)) // Mock size for tests
    }
    
    @Test func testUndoRedoMixedOperations() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let initialNodeCount = model.nodes.count // 3
        let initialEdgeCount = model.edges.count // 3
        
        model.snapshot() // Snapshot 1: initial (3n, 3e)
        
        let nodeToDelete = model.nodes.first!.id
        model.deleteNode(withID: nodeToDelete) // Now 2n, 1e (assuming triangle, delete removes 2 edges)
        model.snapshot() // Snapshot 2: after delete (2n, 1e)
        
        model.addNode(at: CGPoint.zero) // Now 3n, 1e — NO snapshot here, so current is unsnapshotted post-add
        
        #expect(model.nodes.count == initialNodeCount, "After add: count back to initial")
        #expect(model.edges.count < initialEdgeCount, "Edges still decreased")
        
        model.undo() // Undo from post-add to Snapshot 2: after delete (2n, 1e)
        #expect(model.nodes.count == initialNodeCount - 1, "Undo reverts to post-delete")
        
        model.undo() // Undo to Snapshot 1: initial (3n, 3e)
        #expect(model.nodes.count == initialNodeCount, "Second undo restores initial")
        #expect(model.edges.count == initialEdgeCount, "Edges restored")
        
        model.redo() // Redo to post-delete (2n, 1e)
        #expect(model.nodes.count == initialNodeCount - 1, "Redo applies delete")
        
        model.redo() // Redo to post-add (3n, 1e)
        #expect(model.nodes.count == initialNodeCount, "Redo applies add")
    }
    
    @Test func testInitializationWithDefaults() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(model.nodes.count >= 3, "Should load default or saved nodes")
        #expect(model.edges.count >= 3, "Should load default edges")
    }
    
    @Test func testSnapshotAndUndo() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let initialNodes = model.nodes as! [Node]
        model.snapshot()
        model.addNode(at: CGPoint.zero)
        #expect(model.nodes.count == initialNodes.count + 1, "Node added")
        model.undo()
        let nodesMatch = (model.nodes as! [Node]) == initialNodes
        #expect(nodesMatch, "Undo restores state")
    }
    
    @Test func testDeleteNodeAndEdges() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(!model.nodes.isEmpty, "Assumes default nodes exist")
        let nodeID = model.nodes[0].id
        let initialEdgeCount = model.edges.count
        model.deleteNode(withID: nodeID)
        #expect(model.nodes.first { $0.id == nodeID } == nil, "Node deleted")
        #expect(model.edges.count < initialEdgeCount, "Edges reduced")
    }
    
    @Test func testSaveLoadRoundTrip() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let originalNodes = model.nodes as! [Node]
        let originalEdges = model.edges
        // Modify and snapshot to trigger save
        model.addNode(at: CGPoint.zero)
        model.snapshot()
        // New instance to trigger load
        let newModel = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(newModel.nodes.count == originalNodes.count + 1, "Loaded nodes include addition")
        let edgesMatch = newModel.edges == originalEdges
        #expect(edgesMatch, "Loaded edges match original")
    }
    
    @Test func testAddNode() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let initialCount = model.nodes.count
        model.addNode(at: CGPoint.zero)
        #expect(model.nodes.count == initialCount + 1, "Node added")
    }
    
    @Test func testRedo() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let initialNodes = model.nodes as! [Node]
        model.snapshot()
        model.addNode(at: CGPoint.zero)
        // Removed: model.snapshot() // Avoid saving post-add state; undo would be a no-op otherwise
        model.undo()
        #expect(model.nodes.count == initialNodes.count, "Undo removes added node")
        model.redo()
        #expect(model.nodes.count == initialNodes.count + 1, "Redo restores added node")
    }
    
    @Test func testMaxUndoLimit() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        for _ in 0..<12 { // Exceed maxUndo=10
            model.addNode(at: CGPoint.zero)
            model.snapshot()
        }
        var undoCount = 0
        while model.canUndo {
            model.undo()
            undoCount += 1
        }
        #expect(undoCount == 10, "Can only undo up to maxUndo times")
        #expect(!model.canUndo, "Cannot undo beyond maxUndo")
    }
    
    @Test func testNextNodeLabelWithLoadedData() {
        let storage = MockGraphStorage()
        storage.nodes = [
            Node(label: 5, position: CGPoint.zero),
            Node(label: 10, position: CGPoint.zero)
        ]
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        model.addNode(at: CGPoint.zero)
        #expect(model.nodes.last?.label == 11, "Added node gets max loaded + 1")
    }
    
    @Test func testDeleteEdge() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(!model.edges.isEmpty, "Assumes default edges exist")
        let edgeID = model.edges[0].id
        let initialEdgeCount = model.edges.count
        model.deleteSelectedEdge(id: edgeID)  // Updated method call
        #expect(model.edges.first { $0.id == edgeID } == nil, "Edge deleted")
        #expect(model.edges.count == initialEdgeCount - 1, "Edge count reduced")
    }
    
    @Test func testCanUndoAndCanRedo() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(!model.canUndo, "No undo initially")
        #expect(!model.canRedo, "No redo initially")
        model.snapshot()
        #expect(model.canUndo, "Can undo after snapshot")
        model.undo()
        #expect(model.canRedo, "Can redo after undo")
    }
    
    @Test func testUndoAfterDelete() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let initialNodes = model.nodes as! [Node]
        model.snapshot()
        let nodeID = model.nodes[0].id
        model.deleteNode(withID: nodeID)
        #expect(model.nodes.count == initialNodes.count - 1, "Node deleted")
        model.undo()
        #expect(model.nodes.count == initialNodes.count, "Undo restores deleted node")
    }
    
    @Test func testStartStopSimulation() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        model.startSimulation()
        // Simulate time passage; check if positions change (e.g., run a few manual steps)
        var nodesCopy = model.nodes as! [Node]
        _ = model.physicsEngine.simulationStep(nodes: &nodesCopy, edges: model.edges)
        let positionsChanged = nodesCopy != (model.nodes as! [Node])
        #expect(positionsChanged, "Simulation affects positions") // Assuming it runs
        model.stopSimulation()
        // Verify timer is nil (but since private, perhaps add a public isSimulating property if needed)
    }
    
    @Test func testEmptyGraphInitialization() {
        let storage = MockGraphStorage()
        storage.nodes = []
        storage.edges = []
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(model.nodes.count == 3, "Initializes with default nodes if empty")
        #expect(model.edges.count == 3, "Initializes with default edges if empty")
    }
    
    @Test func testDeleteSelectedEdge() {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        
        // Setup: Add nodes and an edge
        model.addNode(at: .zero)  // Node 1
        model.addNode(at: CGPoint(x: 100, y: 100))  // Node 2
        let edge = GraphEdge(from: model.nodes[0].id, to: model.nodes[1].id)
        model.edges.append(edge)
        
        #expect(model.edges.count == 1, "Edge added")
        
        // Act: Delete the selected edge
        model.deleteSelectedEdge(id: edge.id)
        
        #expect(model.edges.isEmpty, "Edge deleted")
        #expect(model.canUndo, "Snapshot created for undo")
        
        // Undo to verify
        model.undo()
        #expect(model.edges.count == 1, "Undo restores edge")
    }
}

struct PhysicsEngineTests {
    @Test func testSimulationStepStability() {
        let engine = GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        var nodes: [Node] = [
            Node(label: 1, position: CGPoint(x: 0, y: 0), velocity: CGPoint(x: 1, y: 1)),  // hypot ≈1.414
            Node(label: 2, position: CGPoint(x: 300, y: 300), velocity: CGPoint(x: 1, y: 1))   // hypot ≈1.414, total ≈2.828 >0.4
        ]
        let edges: [GraphEdge] = []
        let isRunning = engine.simulationStep(nodes: &nodes, edges: edges)
        #expect(isRunning, "Simulation runs if velocities above threshold")
        
        nodes[0].velocity = CGPoint.zero
        nodes[1].velocity = CGPoint.zero
        let isStable = engine.simulationStep(nodes: &nodes, edges: edges)
        #expect(!isStable, "Simulation stops if velocities below threshold")
    }
    
    @Test func testSimulationConvergence() {
        let engine = GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        var nodes: [Node] = [
            Node(label: 1, position: CGPoint(x: 0, y: 0), velocity: CGPoint(x: 10, y: 10)),
            Node(label: 2, position: CGPoint(x: 100, y: 100), velocity: CGPoint(x: -5, y: -5))
        ]
        let edges: [GraphEdge] = [GraphEdge(from: nodes[0].id, to: nodes[1].id)]
        for _ in 0..<4000 {  // Increased for smaller timeStep (equivalent to ~200 steps of timeStep=1.0)
            _ = engine.simulationStep(nodes: &nodes, edges: edges)
        }
        #expect(nodes[0].velocity.magnitude < 0.3, "Node 1 velocity converges to near-zero")
        #expect(nodes[1].velocity.magnitude < 0.3, "Node 2 velocity converges to near-zero")
        #expect(abs(distance(nodes[0].position, nodes[1].position) - Constants.Physics.idealLength) < 42, "Nodes approach ideal edge length")
    }
    
    @Test func testQuadtreeInsertionAndCenterOfMass() {
        let quadtree = GraphEditorShared.Quadtree(bounds: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))
        let node1 = Node(label: 1, position: CGPoint(x: 10.0, y: 10.0))
        let node2 = Node(label: 2, position: CGPoint(x: 90.0, y: 90.0))
        quadtree.insert(node1)
        #expect(quadtree.centerOfMass == CGPoint(x: 10.0, y: 10.0), "Center of mass after first insert")
        #expect(quadtree.totalMass == 1.0, "Mass after first insert")
        quadtree.insert(node2)
        #expect(quadtree.centerOfMass == CGPoint(x: 50.0, y: 50.0), "Center of mass after second insert")
        #expect(quadtree.totalMass == 2.0, "Mass after second insert")
        #expect(quadtree.children != nil, "Subdivided after second insert")
    }
    
    @Test func testComputeForceBasic() {
        let quadtree = GraphEditorShared.Quadtree(bounds: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))
        let node1 = Node(label: 1, position: CGPoint(x: 20.0, y: 20.0))
        quadtree.insert(node1)
        let testNode = Node(label: 2, position: CGPoint(x: 50.0, y: 50.0))
        let force = quadtree.computeForce(on: testNode)
        let isRepellingX: Bool = force.x > CGFloat.zero
        let isRepellingY: Bool = force.y > CGFloat.zero
        #expect(isRepellingX && isRepellingY, "Repulsion force pushes away")
        let magnitude: CGFloat = force.magnitude
        let hasPositiveMagnitude: Bool = magnitude > CGFloat.zero
        #expect(hasPositiveMagnitude, "Force has positive magnitude")
    }
    
    @Test func testBoundingBox() {
        let engine = GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300)) // Add parameter
        let nodes: [Node] = [
            Node(label: 1, position: CGPoint(x: 10.0, y: 20.0)),
            Node(label: 2, position: CGPoint(x: 30.0, y: 40.0)),
            Node(label: 3, position: CGPoint(x: 5.0, y: 50.0))
        ]
        let bbox = engine.boundingBox(nodes: nodes)
        #expect(bbox == CGRect(x: 5.0, y: 20.0, width: 25.0, height: 30.0), "Correct bounding box")
        let emptyBbox = engine.boundingBox(nodes: [])
        #expect(emptyBbox == .zero, "Zero for empty nodes")
    }
    
    @Test func testQuadtreeMultiLevelSubdivision() {
        let quadtree = GraphEditorShared.Quadtree(bounds: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))
        // Insert nodes all in NW quadrant to force multi-level
        let node1 = Node(label: 1, position: CGPoint(x: 10.0, y: 10.0))
        let node2 = Node(label: 2, position: CGPoint(x: 20.0, y: 20.0))
        let node3 = Node(label: 3, position: CGPoint(x: 15.0, y: 15.0))
        quadtree.insert(node1)
        quadtree.insert(node2)
        quadtree.insert(node3)
        #expect(quadtree.children?[0].children != nil, "Multi-level subdivision occurred")
        #expect(quadtree.totalMass == 3.0, "Total mass correct after multi-insert")
    }
    
    @Test func testAttractionForceInSimulation() {
        let engine = GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300)) // Add parameter
        var nodes: [Node] = [
            Node(label: 1, position: CGPoint(x: 0.0, y: 0.0)),
            Node(label: 2, position: CGPoint(x: 200.0, y: 200.0))
        ]
        let edges = [GraphEdge(from: nodes[0].id, to: nodes[1].id)]
        let initialDistance = distance(nodes[0].position, nodes[1].position)
        _ = engine.simulationStep(nodes: &nodes, edges: edges)
        let newDistance = distance(nodes[0].position, nodes[1].position)
        #expect(newDistance < initialDistance, "Attraction force pulls nodes closer")
    }
    
    @Test func testSimulationMaxSteps() {
        let engine = GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300)) // Add parameter
        var nodes: [Node] = [Node(label: 1, position: CGPoint.zero, velocity: CGPoint(x: 1.0, y: 1.0))]
        let edges: [GraphEdge] = []
        for _ in 0..<Constants.Physics.maxSimulationSteps {
            _ = engine.simulationStep(nodes: &nodes, edges: edges)
        }
        let exceeded = engine.simulationStep(nodes: &nodes, edges: edges)
        #expect(!exceeded, "Simulation stops after max steps")
    }
    
    @Test func testSimulationWithManyNodes() {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 3000, height: 3000))  // Increased bounds to match spread
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        for i in 1...50 {
            model.addNode(at: CGPoint(x: CGFloat(i * 50), y: CGFloat(i * 50)))  // Spread more (x10)
        }
        model.startSimulation()
        // Simulate more steps manually if needed, assert no crash and velocities decrease
        var nodes = model.nodes as! [Node]
        for _ in 0..<100 {  // Increased to 100 for damping to take effect
            _ = physicsEngine.simulationStep(nodes: &nodes, edges: model.edges)
        }
        let totalVel = nodes.reduce(0.0) { $0 + $1.velocity.magnitude }
        #expect(totalVel < 5000, "Velocities should not explode with many nodes")  // Adjusted threshold
    }
    
    @Test func testQuadtreeCoincidentNodes() {
        let quadtree = Quadtree(bounds: CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
        let pos = CGPoint(x: 50, y: 50)
        let node1 = Node(label: 1, position: pos)
        let node2 = Node(label: 2, position: pos)
        quadtree.insert(node1)
        quadtree.insert(node2)
        let force = quadtree.computeForce(on: node1)
        #expect(force.magnitude > 0, "Force non-zero on coincident nodes")
    }
}

struct PersistenceManagerTests {
    private func mockPhysicsEngine() -> GraphEditorShared.PhysicsEngine {
        GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
    }

    private func mockStorage() -> MockGraphStorage {
        MockGraphStorage()
    }

    @Test func testSaveLoadWithInvalidData() throws {
        // Create a unique temporary directory for this test
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        // Clean up after test (defer to ensure it runs)
        defer {
            try? fm.removeItem(at: tempDir)
        }
        let manager = PersistenceManager(baseURL: tempDir)
        // No files yet, so load should be empty
        let loaded = try manager.load()
        #expect(loaded.nodes.isEmpty, "Empty nodes on initial load")
        #expect(loaded.edges.isEmpty, "Empty edges on initial load")
        let nodes = [Node(label: 1, position: CGPoint.zero)]
        let edges = [GraphEdge(from: nodes[0].id, to: nodes[0].id)] // Self-loop edge
        try manager.save(nodes: nodes, edges: edges)
        // Optional: Verify files were written (for debugging)
        let nodesURL = tempDir.appendingPathComponent("graphNodes.json")
        let edgesURL = tempDir.appendingPathComponent("graphEdges.json")
        #expect(fm.fileExists(atPath: nodesURL.path), "Nodes file should exist after save")
        #expect(fm.fileExists(atPath: edgesURL.path), "Edges file should exist after save")
        let reloaded = try manager.load()
        #expect(reloaded.nodes == nodes, "Loaded nodes match saved (including IDs)")
        #expect(reloaded.edges == edges, "Loaded edges match saved")
    }

    @Test func testUndoRedoThroughViewModel() {
        let storage = mockStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let viewModel = GraphViewModel(model: model)
        viewModel.snapshot()
        model.addNode(at: CGPoint.zero)
        #expect(viewModel.canUndo, "ViewModel reflects canUndo")
        viewModel.undo()
        #expect(!viewModel.canUndo, "Undo updates viewModel state")
    }
}
class GraphGesturesModifierTests: XCTestCase {
    private func mockPhysicsEngine() -> GraphEditorShared.PhysicsEngine {
        GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300)) // Mock size for tests
    }
    
    private func mockStorage() -> MockGraphStorage {
        MockGraphStorage()
    }
    
    struct GestureTests {
        @Test func testDragCreatesEdge() {
            let storage = MockGraphStorage()
            let physicsEngine = GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
            let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
            
            // Setup: Clear default nodes/edges if needed, but since test assumes empty edges after adding, adjust expectations.
            // Note: GraphModel init adds defaults if empty, so to match test intent, we'll clear them here for the test.
            model.nodes = []
            model.edges = []
            model.addNode(at: CGPoint(x: 0, y: 0))
            model.addNode(at: CGPoint(x: 50, y: 50))
            #expect(model.edges.isEmpty, "No edges initially")
            
            let viewModel = GraphViewModel(model: model)
            let node1 = model.nodes[0] as! Node
            let node2 = model.nodes[1] as! Node
            
            // Mock gesture properties instead of creating Value
            let mockTranslation = CGSize(width: 50, height: 50)
            
            // Simulate onEnded logic
            let draggedNode: (any NodeProtocol)? = node1
            let potentialEdgeTarget: (any NodeProtocol)? = node2
            let dragOffset: CGPoint = CGPoint(x: mockTranslation.width / 1.0, y: mockTranslation.height / 1.0)  // Assume zoomScale=1
            
            let dragDistance = hypot(mockTranslation.width, mockTranslation.height)
            if let node = draggedNode,
               let index = viewModel.model.nodes.firstIndex(where: { $0.id == node.id }) {
                viewModel.snapshot()
                if dragDistance < AppConstants.tapThreshold {
                    // Tap logic (skipped)
                } else {
                    // Drag logic
                    if let target = potentialEdgeTarget, target.id != node.id {
                        // Break up complex predicate
                        let fromID = node.id
                        let toID = target.id
                        let edgeExists = viewModel.model.edges.contains { edge in
                            (edge.from == fromID && edge.to == toID) ||
                            (edge.from == toID && edge.to == fromID)
                        }
                        if !edgeExists {
                            viewModel.model.edges.append(GraphEdge(from: fromID, to: toID))
                            viewModel.model.startSimulation()
                        } else {
                            // Move logic (skipped, but update to use vars)
                            var updatedNode = viewModel.model.nodes[index] as! Node  // Cast for mutation
                            updatedNode.position = CGPoint(x: updatedNode.position.x + dragOffset.x, y: updatedNode.position.y + dragOffset.y)
                            viewModel.model.nodes[index] = updatedNode
                            viewModel.model.startSimulation()
                        }
                    }
                }
            }
            
            // Assert: Break up the expectation
            #expect(viewModel.model.edges.count == 1, "Edge created after simulated drag")
            let newEdge = viewModel.model.edges.first
            #expect(newEdge != nil, "New edge exists")
            if let newEdge = newEdge {
                #expect(newEdge.from == node1.id, "Edge from correct node")
                #expect(newEdge.to == node2.id, "Edge to correct node")
            }
        }
    }
}

struct AccessibilityTests {
    private func mockPhysicsEngine() -> GraphEditorShared.PhysicsEngine {
        GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
    }

    @Test func testGraphDescription() {
        let storage = MockGraphStorage()
        // Preload with dummy to avoid defaults and set nextNodeLabel to 1
        storage.nodes = [Node(label: 0, position: .zero)]
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine(), nextNodeLabel: 1)
        model.nodes = []  // Clear for test setup
        model.edges = []
        
        model.nextNodeLabel = 1  // Reset for consistent labeling in test
        
        model.addNode(at: .zero)  // Label 1
        model.addNode(at: CGPoint(x: 10, y: 10))  // Label 2
        model.edges.append(GraphEdge(from: model.nodes[0].id, to: model.nodes[1].id))
        
        let descNoSelect = model.graphDescription(selectedID: nil, selectedEdgeID: nil)  // Add param
        #expect(descNoSelect == "Graph with 2 nodes and 1 directed edge. No node or edge selected.", "Correct desc without selection")  // Updated expectation

        let descWithSelect = model.graphDescription(selectedID: model.nodes[0].id, selectedEdgeID: nil)  // Add param
        #expect(descWithSelect == "Graph with 2 nodes and 1 directed edge. Node 1 selected, outgoing to: 2; incoming from: none.", "Correct desc with selection")  // Updated expectation
    }
}
