import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch  // Updated module name
import GraphEditorShared  // For Node, GraphEdge, etc.

struct GraphModelTests {

    @Test func testInitializationWithDefaults() {
        let model = GraphModel()
        #expect(model.nodes.count >= 3, "Should load default or saved nodes")
        #expect(model.edges.count >= 3, "Should load default edges")
    }
    
    @Test func testSnapshotAndUndo() {
        let model = GraphModel()
        let initialNodes = model.nodes
        model.snapshot()
        model.addNode(at: .zero)
        #expect(model.nodes.count == initialNodes.count + 1, "Node added")
        model.undo()
        #expect(model.nodes == initialNodes, "Undo restores state")
    }
    
    @Test func testDeleteNodeAndEdges() {
        let model = GraphModel()
        #expect(!model.nodes.isEmpty, "Assumes default nodes exist")
        let nodeID = model.nodes[0].id
        let initialEdgeCount = model.edges.count
        model.deleteNode(withID: nodeID)
        #expect(model.nodes.first { $0.id == nodeID } == nil, "Node deleted")
        #expect(model.edges.count < initialEdgeCount, "Edges reduced")
    }
    
    @Test func testSaveLoadRoundTrip() throws {
        let model = GraphModel()
        model.save()
        let newModel = GraphModel()
        newModel.load()
        #expect(newModel.nodes.count == model.nodes.count, "Node count matches")
    }
    
    @Test func testAddNode() {
        let model = GraphModel()
        let initialCount = model.nodes.count
        model.addNode(at: .zero)
        #expect(model.nodes.count == initialCount + 1, "Node added")
    }
    
    @Test func testSimulationStep() {
        let model = GraphModel()
        var nodes = model.nodes
        let edges = model.edges
        // Assuming PhysicsEngine is accessible; if private, expose or mock
        let engine = PhysicsEngine()
        let isRunning = engine.simulationStep(nodes: &nodes, edges: edges)
        #expect(isRunning, "Simulation should run if not stable")
    }
}
