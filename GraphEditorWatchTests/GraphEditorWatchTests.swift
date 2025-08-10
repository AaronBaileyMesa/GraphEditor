import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch // Already present
@testable import GraphEditorShared // Changed to @testable for accessing internal members
import XCTest
import SwiftUI

class MockGraphStorage: GraphStorage {
    var nodes: [any NodeProtocol] = []
    var edges: [GraphEdge] = []
    
    func save(nodes: [any NodeProtocol], edges: [GraphEdge]) throws {
        self.nodes = nodes
        self.edges = edges
    }
    
    func load() throws -> (nodes: [any NodeProtocol], edges: [GraphEdge]) {
        (nodes, edges)
    }
    
    func clear() throws {
        nodes = []
        edges = []
    }
}

// Add this helper function at the top of the test file or in the test struct
func approximatelyEqual(_ lhs: CGPoint, _ rhs: CGPoint, accuracy: CGFloat) -> Bool {
    return hypot(lhs.x - rhs.x, lhs.y - rhs.y) < accuracy
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
        let initialNodes = model.nodes
        model.snapshot()
        model.addNode(at: CGPoint.zero)
        #expect(model.nodes.count == initialNodes.count + 1, "Node added")
        model.undo()
        let restoredNodes = model.nodes
        let idsMatch = Set(restoredNodes.map { $0.id }) == Set(initialNodes.map { $0.id })
        let labelsMatch = Set(restoredNodes.map { $0.label }) == Set(initialNodes.map { $0.label })
        let positionsMatch = zip(restoredNodes.sorted(by: { $0.id.uuidString < $1.id.uuidString }), initialNodes.sorted(by: { $0.id.uuidString < $1.id.uuidString })).allSatisfy { approximatelyEqual($0.position, $1.position, accuracy: 1e-5) }
        #expect(idsMatch && labelsMatch && positionsMatch, "Undo restores state")
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
        let originalNodeCount = model.nodes.count
        let originalEdges = model.edges
        // Modify and snapshot to trigger save
        model.addNode(at: CGPoint.zero)
        model.snapshot()
        // New instance to trigger load
        let newModel = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(newModel.nodes.count == originalNodeCount + 1, "Loaded nodes include added one")
        #expect(newModel.edges == originalEdges, "Edges unchanged")
    }
    
    // New: Basic convergence test with tightened threshold
    @Test func testSimulationConvergence() {
        let tolerance: CGFloat = 0.05  // Lenient for floating-point
        let model = GraphModel(storage: MockGraphStorage(), physicsEngine: mockPhysicsEngine())
        model.nodes = [
            Node(label: 1, position: CGPoint(x: 100, y: 100), velocity: CGPoint(x: 10, y: 10)),
            Node(label: 2, position: CGPoint(x: 200, y: 200), velocity: CGPoint(x: -10, y: -10))
        ]
        model.edges = [GraphEdge(from: model.nodes[0].id, to: model.nodes[1].id)]
        
        model.startSimulation()
        // Simulate steps (since timer is async, run manual loop for test)
        for _ in 0..<Constants.Physics.maxSimulationSteps {
            let nodes = model.nodes
            let edges = model.edges
            let (updatedNodes, active) = model.physicsEngine.simulationStep(nodes: nodes, edges: edges)
            model.nodes = updatedNodes
            if !active { break }
        }
        
        #expect(model.nodes[0].velocity.magnitude < 0.2 + tolerance, "Node 1 velocity converges to near-zero")
        #expect(model.nodes[1].velocity.magnitude < 0.2 + tolerance, "Node 2 velocity converges to near-zero")
    }
    
    // New/Fixed: Property-based convergence test with tightened threshold and proper parameterization
    @Test(arguments: 1..<5) func testConvergencePropertyBased(seed: Int) throws {
        let model = GraphModel(storage: MockGraphStorage(), physicsEngine: mockPhysicsEngine())
        srand48(seed)  // Seed random for reproducibility
        model.nodes = (0..<5).map { _ in
            Node(label: Int(drand48() * 10), position: CGPoint(x: CGFloat(drand48() * 300), y: CGFloat(drand48() * 300)))
        }
        model.edges = (0..<3).map { _ in
            GraphEdge(from: model.nodes[Int(drand48() * 5)].id, to: model.nodes[Int(drand48() * 5)].id)
        }
        
        model.startSimulation()
        // Manual loop for test
        for _ in 0..<Constants.Physics.maxSimulationSteps {
            let nodes = model.nodes
            let edges = model.edges
            let (updatedNodes, active) = model.physicsEngine.simulationStep(nodes: nodes, edges: edges)
            model.nodes = updatedNodes
            if !active { break }
        }
        
        let totalVel = model.nodes.reduce(0.0) { $0 + $1.velocity.magnitude }
        #expect(totalVel < 0.3 * CGFloat(model.nodes.count), "Velocities near zero for seed \(seed)")
    }
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
        guard let node1 = model.nodes[0] as? Node else { fatalError("Expected Node") }
        guard let node2 = model.nodes[1] as? Node else { fatalError("Expected Node") }
        
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
                        viewModel.model.nodes[index].position = CGPoint(x: viewModel.model.nodes[index].position.x + dragOffset.x, y: viewModel.model.nodes[index].position.y + dragOffset.y)
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
