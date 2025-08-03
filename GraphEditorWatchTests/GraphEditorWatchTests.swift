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
}
