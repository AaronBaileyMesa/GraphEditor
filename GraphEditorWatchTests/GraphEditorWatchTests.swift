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
    
    @Test func testUndoRedoMixedOperations() async throws {
        let storage = MockGraphStorage()
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let initialNodeCount = await MainActor.run { model.nodes.count }
        let initialEdgeCount = await MainActor.run { model.edges.count }
        
        // Specify node to delete (e.g., first in cycle removes 2 edges)
        let nodeToDelete = await MainActor.run { model.nodes[0].id }
        let connectedEdges = await MainActor.run { model.edges.filter { $0.from == nodeToDelete || $0.target == nodeToDelete }.count }
        await model.deleteNode(withID: nodeToDelete) // Now 2n, 1e
        
        await model.addNode(at: CGPoint.zero) // Now 3n, 1e — no *manual* snapshot (internal one handles)
        
        #expect(await MainActor.run { model.nodes.count } == initialNodeCount, "After add: count back to initial")
        #expect(await MainActor.run { model.edges.count } == initialEdgeCount - connectedEdges, "Edges reduced by connected count")
        
        await model.undo() // To post-delete
        #expect(await MainActor.run { model.nodes.count } == initialNodeCount - 1, "Undo reverts to post-delete")
        #expect(await MainActor.run { model.edges.count } == initialEdgeCount - connectedEdges, "Edges match post-delete")
        
        await model.undo() // To initial
        #expect(await MainActor.run { model.nodes.count } == initialNodeCount, "Second undo restores initial")
        #expect(await MainActor.run { model.edges.count } == initialEdgeCount, "Edges restored")
        
        await model.redo() // To post-delete
        #expect(await model.nodes.count == initialNodeCount - 1, "Redo applies delete")
        
        await model.redo() // To post-add
        #expect(await model.nodes.count == initialNodeCount, "Redo applies add")
    }
    
    @Test func testInitializationWithDefaults() async throws {
        let storage = MockGraphStorage()
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(await model.nodes.count >= 3, "Should load default or saved nodes")
        #expect(await model.edges.count >= 3, "Should load default edges")
    }
    
    @Test func testSnapshotAndUndo() async throws {
        let storage = MockGraphStorage()
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let initialNodes = await model.nodes
        await model.snapshot()
        await model.addNode(at: CGPoint.zero)
        #expect(await model.nodes.count == initialNodes.count + 1, "Node added")
        await model.undo()
        let restoredNodes = await model.nodes
        let idsMatch = Set(restoredNodes.map { $0.id }) == Set(initialNodes.map { $0.id })
        let labelsMatch = Set(restoredNodes.map { $0.label }) == Set(initialNodes.map { $0.label })
        let positionsMatch = zip(restoredNodes.sorted(by: { $0.id.uuidString < $1.id.uuidString }), initialNodes.sorted(by: { $0.id.uuidString < $1.id.uuidString })).allSatisfy { approximatelyEqual($0.position, $1.position, accuracy: 1e-5) }
        #expect(idsMatch && labelsMatch && positionsMatch, "Undo restores state")
    }
    
    @Test func testDeleteNodeAndEdges() async throws {
        let storage = MockGraphStorage()
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(await !model.nodes.isEmpty, "Assumes default nodes exist")
        let nodeID = await model.nodes[0].id
        let initialEdgeCount = await model.edges.count
        await model.deleteNode(withID: nodeID)
        #expect(await model.nodes.first { $0.id == nodeID } == nil, "Node deleted")
        #expect(await model.edges.count < initialEdgeCount, "Edges reduced")
    }
    
    @Test func testSaveLoadRoundTrip() async throws {
        let storage = MockGraphStorage()
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let originalNodeCount = await model.nodes.count
        let originalEdges = await model.edges
        // Modify and snapshot to trigger save
        await model.addNode(at: CGPoint.zero)
        await model.snapshot()
        // New instance to trigger load
        let newModel = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(await newModel.nodes.count == originalNodeCount + 1, "Loaded nodes include added one")
        #expect(await newModel.edges == originalEdges, "Edges unchanged")
    }
    
    /*
    // New: Basic convergence test with tightened threshold
    // New: Basic convergence test with tightened threshold
    @Test(arguments: 1..<5) func testConvergencePropertyBased(seed: Int) throws {
        let model = GraphModel(storage: MockGraphStorage(), physicsEngine: mockPhysicsEngine())
        srand48(seed)  // Seed random for reproducibility
        //print(model.nodes.map { ($0.label, $0.position) })
        model.nodes = (0..<5).map { _ in
            Node(label: Int(drand48() * 10), position: CGPoint(x: CGFloat(drand48() * 300), y: CGFloat(drand48() * 300)))
        }
        model.edges = (0..<3).map { _ in
            GraphEdge(from: model.nodes[Int(drand48() * 5)].id, to: model.nodes[Int(drand48() * 5)].id)
        }
        
        model.startSimulation()
        // Manual loop for test with substeps
        for _ in 0..<Constants.Physics.maxSimulationSteps {
            var nodes = model.nodes
            var activeAccum = false  // Accumulator declared here (outside inner loop)
            for _ in 0..<20 {  // Increased substeps as suggested
                let (updatedNodes, stepActive) = model.physicsEngine.simulationStep(nodes: nodes, edges: model.edges)
                nodes = updatedNodes
                activeAccum = activeAccum || stepActive  // Update accumulator
                if !stepActive { break }  // Optional: Early break if inactive in a substep
            }
            model.nodes = nodes
            if !activeAccum { break }  // Now uses the accumulator (in scope)
        }
        
        let totalVel = model.nodes.reduce(0.0) { $0 + $1.velocity.magnitude }
        #expect(totalVel < 2.0 * CGFloat(model.nodes.count), "Velocities near zero for seed \(seed)")
    }
    // New/Fixed: Property-based convergence test with tightened threshold and proper parameterization
    @Test func testSimulationConvergence() {
        let tolerance: CGFloat = 0.05
        let model = GraphModel(storage: MockGraphStorage(), physicsEngine: mockPhysicsEngine())
        model.nodes = [
            Node(label: 1, position: CGPoint(x: 100, y: 100), velocity: CGPoint(x: 10, y: 10)),
            Node(label: 2, position: CGPoint(x: 200, y: 200), velocity: CGPoint(x: -10, y: -10))
        ]
        model.edges = [GraphEdge(from: model.nodes[0].id, to: model.nodes[1].id)]
        
        model.startSimulation()
        for _ in 0..<Constants.Physics.maxSimulationSteps {
            var nodes = model.nodes
            var activeAccum = false
            let subSteps = 20  // Increased as suggested
            for _ in 0..<subSteps {
                let edges = model.edges
                let (updatedNodes, stepActive) = model.physicsEngine.simulationStep(nodes: nodes, edges: edges)
                nodes = updatedNodes
                activeAccum = activeAccum || stepActive
                if !stepActive { break }  // Optional early break
            }
            model.nodes = nodes
            if !activeAccum { break }
        }
        
        #expect(model.nodes[0].velocity.magnitude < 1.2 + tolerance, "Node 1 velocity converges to near-zero")
        #expect(model.nodes[1].velocity.magnitude < 1.2 + tolerance, "Node 2 velocity converges to near-zero")
    }
     */
}

struct CoordinateTransformerTests {
    @Test func testCoordinateRoundTrip() {
        let viewSize = CGSize(width: 205, height: 251)  // Apple Watch Ultra 2 points
        let centroid = CGPoint(x: 150, y: 150)
        let modelPos = CGPoint(x: 167.78, y: 165.66)  // From your log
        let zoom: CGFloat = 1.0
        let offset = CGSize.zero
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Round-trip should match original model position")
    }
    
    @Test func testCoordinateRoundTripWithZoomAndOffset() {
        let viewSize = CGSize(width: 205, height: 251)
        let centroid = CGPoint(x: 56.73, y: 161.10)  // From your log
        let modelPos = CGPoint(x: -40.27, y: 52.60)
        let zoom: CGFloat = 1.0
        let offset = CGSize(width: 81, height: 111.5)
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Round-trip with zoom and offset should match")
    }
}

struct GestureTests {
    @Test func testDragCreatesEdge() async throws {
        let storage = MockGraphStorage()
        let physicsEngine = GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = await GraphModel(storage: storage, physicsEngine: physicsEngine)
        
        // Setup: Clear default nodes/edges if needed, but since test assumes empty edges after adding, adjust expectations.
        // Note: GraphModel init adds defaults if empty, so to match test intent, we'll clear them here for the test.
        await MainActor.run { model.nodes = [] }
        await MainActor.run { model.edges = [] }
        await model.addNode(at: CGPoint(x: 0, y: 0))
        await model.addNode(at: CGPoint(x: 50, y: 50))
        #expect(await model.edges.isEmpty, "No edges initially")
        
        let viewModel = await GraphViewModel(model: model)
        let draggedNode: (any NodeProtocol)? = await model.nodes[0]
        let potentialEdgeTarget: (any NodeProtocol)? = await model.nodes[1]
        
        // Mock gesture properties instead of creating Value
        let mockTranslation = CGSize(width: 50, height: 50)
        let dragOffset: CGPoint = CGPoint(x: mockTranslation.width / 1.0, y: mockTranslation.height / 1.0)  // Assume zoomScale=1
        
        let dragDistance = hypot(mockTranslation.width, mockTranslation.height)
        if let node = draggedNode,
           let index = await viewModel.model.nodes.firstIndex(where: { $0.id == node.id }) {
            await viewModel.snapshot()
            if dragDistance < AppConstants.tapThreshold {
                // Tap logic (skipped)
            } else {
                // Drag logic
                if let target = potentialEdgeTarget, target.id != node.id {
                    // Break up complex predicate
                    let fromID = node.id
                    let toID = target.id
                    let edgeExists = await MainActor.run {
                        viewModel.model.edges.contains { edge in
                            (edge.from == fromID && edge.to == toID) ||
                            (edge.from == toID && edge.to == fromID)
                        }
                    }
                    if !edgeExists {
                        await MainActor.run { viewModel.model.edges.append(GraphEdge(from: fromID, target: toID)) }
                        await viewModel.model.startSimulation()
                    } else {
                        // Move logic (skipped, but update to use vars)
                        await MainActor.run { viewModel.model.nodes[index].position = CGPoint(x: viewModel.model.nodes[index].position.x + dragOffset.x, y: viewModel.model.nodes[index].position.y + dragOffset.y) }
                        await viewModel.model.startSimulation()
                    }
                }
            }
        }
        
        await #expect(viewModel.model.edges.count == 1, "Edge created after simulated drag")
        let newEdge = await viewModel.model.edges.first
        #expect(newEdge != nil, "New edge exists")
        if let newEdge = newEdge {
            #expect(newEdge.from == draggedNode?.id, "Edge from correct node")
            #expect(newEdge.target == potentialEdgeTarget?.id, "Edge to correct node")
        }
    }
}

struct AccessibilityTests {
    private func mockPhysicsEngine() -> GraphEditorShared.PhysicsEngine {
        GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
    }
    
    @Test func testGraphDescription() async throws {
        let storage = MockGraphStorage()
        // Preload with dummy to avoid defaults and set nextNodeLabel to 1
        storage.nodes = [Node(label: 0, position: .zero)]
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        await MainActor.run { model.nextNodeLabel = 1 }  // Set post-init if required
                await model.addNode(at: .zero)
                await model.addNode(at: CGPoint(x: 10, y: 10))
        
                await MainActor.run { model.edges.append(GraphEdge(from: model.nodes[0].id, target: model.nodes[1].id)) }  // Or await model.addEdge(...) if added
        
                let descNoSelect = await MainActor.run { model.graphDescription(selectedID: nil, selectedEdgeID: nil) }
        #expect(descNoSelect == "Graph with 2 nodes and 1 directed edge. No node or edge selected.", "Correct desc without selection")
        
                let descWithSelect = await MainActor.run { model.graphDescription(selectedID: model.nodes[0].id, selectedEdgeID: nil) }
        #expect(descWithSelect == "Graph with 2 nodes and 1 directed edge. Node 1 selected, outgoing to: 2; incoming from: none.", "Correct desc with selection")
    }
}
