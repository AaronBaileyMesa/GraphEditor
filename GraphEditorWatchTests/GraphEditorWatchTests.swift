import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch  // Updated module name
import GraphEditorShared  // For Node, GraphEdge, etc.

class MockGraphStorage: GraphStorage {
    var nodes: [Node] = []
    var edges: [GraphEdge] = []
    
    func save(nodes: [Node], edges: [GraphEdge]) {
        self.nodes = nodes
        self.edges = edges
    }
    
    func load() -> (nodes: [Node], edges: [GraphEdge]) {
        (nodes, edges)
    }
}

struct GraphModelTests {

    @Test func testInitializationWithDefaults() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage)
        #expect(model.nodes.count >= 3, "Should load default or saved nodes")
        #expect(model.edges.count >= 3, "Should load default edges")
    }
    
    @Test func testSnapshotAndUndo() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage)
        let initialNodes = model.nodes
        model.snapshot()
        model.addNode(at: .zero)
        #expect(model.nodes.count == initialNodes.count + 1, "Node added")
        model.undo()
        #expect(model.nodes == initialNodes, "Undo restores state")
    }
    
    @Test func testDeleteNodeAndEdges() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage)
        #expect(!model.nodes.isEmpty, "Assumes default nodes exist")
        let nodeID = model.nodes[0].id
        let initialEdgeCount = model.edges.count
        model.deleteNode(withID: nodeID)
        #expect(model.nodes.first { $0.id == nodeID } == nil, "Node deleted")
        #expect(model.edges.count < initialEdgeCount, "Edges reduced")
    }
    
    @Test func testSaveLoadRoundTrip() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage)
        let originalNodes = model.nodes
        let originalEdges = model.edges
        // Modify and snapshot to trigger save
        model.addNode(at: .zero)
        model.snapshot()
        // New instance to trigger load
        let newModel = GraphModel(storage: storage)
        #expect(newModel.nodes.count == originalNodes.count + 1, "Loaded nodes include addition")
        #expect(newModel.edges == originalEdges, "Loaded edges match original")
    }
    
    @Test func testAddNode() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage)
        let initialCount = model.nodes.count
        model.addNode(at: .zero)
        #expect(model.nodes.count == initialCount + 1, "Node added")
    }
    
    @Test func testRedo() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage)
        let initialNodes = model.nodes
        model.snapshot()
        model.addNode(at: .zero)
        // Removed: model.snapshot()  // Avoid saving post-add state; undo would be a no-op otherwise
        model.undo()
        #expect(model.nodes.count == initialNodes.count, "Undo removes added node")
        model.redo()
        #expect(model.nodes.count == initialNodes.count + 1, "Redo restores added node")
    }
    
    @Test func testMaxUndoLimit() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage)
        for _ in 0..<12 {  // Exceed maxUndo=10
            model.addNode(at: .zero)
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
            Node(label: 5, position: .zero),
            Node(label: 10, position: .zero)
        ]
        let model = GraphModel(storage: storage)
        model.addNode(at: .zero)
        #expect(model.nodes.last?.label == 11, "Added node gets max loaded + 1")
    }

    @Test func testDeleteEdge() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage)
        #expect(!model.edges.isEmpty, "Assumes default edges exist")
        let edgeID = model.edges[0].id
        let initialEdgeCount = model.edges.count
        model.deleteEdge(withID: edgeID)
        #expect(model.edges.first { $0.id == edgeID } == nil, "Edge deleted")
        #expect(model.edges.count == initialEdgeCount - 1, "Edge count reduced")
    }

    @Test func testCanUndoAndCanRedo() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage)
        #expect(!model.canUndo, "No undo initially")
        #expect(!model.canRedo, "No redo initially")
        model.snapshot()
        #expect(model.canUndo, "Can undo after snapshot")
        model.undo()
        #expect(model.canRedo, "Can redo after undo")
    }
    
}

struct PhysicsEngineTests {
    
    @Test func testQuadtreeInsertionAndCenterOfMass() {
        var quadtree = Quadtree(bounds: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))
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
        var quadtree = Quadtree(bounds: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))
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
    
    @Test func testSimulationStepStability() {
        let engine = PhysicsEngine()
        var nodes: [Node] = [
            Node(label: 1, position: CGPoint(x: 0.0, y: 0.0), velocity: CGPoint(x: 0.1, y: 0.1)),
            Node(label: 2, position: CGPoint(x: 100.0, y: 100.0), velocity: CGPoint(x: 0.01, y: 0.01))
        ]
        let edges: [GraphEdge] = []
        let isRunning = engine.simulationStep(nodes: &nodes, edges: edges)
        #expect(isRunning, "Simulation runs if velocities above threshold")
        nodes[0].velocity = .zero
        nodes[1].velocity = .zero
        let isStable = engine.simulationStep(nodes: &nodes, edges: edges)
        #expect(!isStable, "Simulation stops if velocities below threshold")
    }
    
    @Test func testBoundingBox() {
        let engine = PhysicsEngine()
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
}
