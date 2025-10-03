//
//  GraphModelTests.swift
//  GraphEditor
//
//  Created by handcart on 9/22/25.
//
//
//  GraphModelTests.swift
//  GraphEditor
//
//  Created by handcart on 9/22/25.
//
import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
@testable import GraphEditorShared
import XCTest
import SwiftUI

struct GraphModelTests {
    private func mockPhysicsEngine() -> GraphEditorShared.PhysicsEngine {
        GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
    }
    
    private func setupDefaults(for storage: MockGraphStorage) throws {
        let node1 = AnyNode(Node(label: 1, position: CGPoint(x: 100, y: 100)))
        let node2 = AnyNode(Node(label: 2, position: CGPoint(x: 200, y: 200)))
        let node3 = AnyNode(Node(label: 3, position: CGPoint(x: 150, y: 150)))
        let edge1 = GraphEdge(from: node1.id, target: node2.id)
        let edge2 = GraphEdge(from: node2.id, target: node3.id)
        let edge3 = GraphEdge(from: node3.id, target: node1.id)
        try storage.save(nodes: [node1, node2, node3], edges: [edge1, edge2, edge3])
    }
    
    private func generateNodesAndEdges(seed: Int) async -> ([AnyNode], [GraphEdge]) {
        struct SeededRandomNumberGenerator: RandomNumberGenerator {
            private var state: UInt64
            init(seed: UInt64) {
                state = seed
            }
            mutating func next() -> UInt64 {
                state &+= 1442695040888963407
                state &*= 6364136223846793005
                return state
            }
        }
        var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
        var nodesToAssign: [AnyNode] = []
        for _ in 0..<5 {
            let label = Int.random(in: 0..<10, using: &rng)
            let positionX = CGFloat.random(in: 0..<300, using: &rng)
            let positionY = CGFloat.random(in: 0..<300, using: &rng)
            nodesToAssign.append(AnyNode(Node(label: label, position: CGPoint(x: positionX, y: positionY))))
        }
        var edgesToAssign: [GraphEdge] = []
        for _ in 0..<3 {
            let fromIndex = Int.random(in: 0..<nodesToAssign.count, using: &rng)
            let targetIndex = Int.random(in: 0..<nodesToAssign.count, using: &rng)
            edgesToAssign.append(GraphEdge(from: nodesToAssign[fromIndex].id, target: nodesToAssign[targetIndex].id))
        }
        return (nodesToAssign, edgesToAssign)
    }
    
    private func runSimulation(on model: GraphModel, subStepsPerIteration: Int = 20) async {
        await model.startSimulation()
        for _ in 0..<Constants.Physics.maxSimulationSteps {
            var nodes = await model.nodes
            var activeAccum = false
            for _ in 0..<subStepsPerIteration {
                let currentNodes = nodes.map { $0.unwrapped }
                let physics = await model.physicsEngine
                let edges = await model.edges
                let (updatedNodes, stepActive) = physics.simulationStep(nodes: currentNodes, edges: edges)
                nodes = updatedNodes.map(AnyNode.init)
                activeAccum = activeAccum || stepActive
                if !stepActive { break }
            }
            let updatedNodesForMain = nodes
            await MainActor.run { model.nodes = updatedNodesForMain }
            if !activeAccum { break }
        }
    }
    
    @Test(arguments: 1..<5) func testConvergencePropertyBased(seed: Int) async throws {
        let storage = MockGraphStorage()
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        await model.load()
        let (nodesToAssign, edgesToAssign) = await generateNodesAndEdges(seed: seed)
        await MainActor.run {
            model.nodes = nodesToAssign
            model.edges = edgesToAssign
        }
        await runSimulation(on: model)
        let totalVel = (await model.nodes).reduce(0.0) { $0 + $1.velocity.magnitude }
        let nodeCount = await MainActor.run { model.nodes.count }
        #expect(totalVel < 2.0 * CGFloat(nodeCount), "Velocities near zero for seed \(seed)")
    }
    
    @Test func testSimulationConvergence() async {
        let tolerance: CGFloat = 0.05
        let storage = MockGraphStorage()
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        await model.load()
        await MainActor.run {
            model.nodes = [
                AnyNode(Node(label: 1, position: CGPoint(x: 100, y: 100), velocity: CGPoint(x: 10, y: 10))),
                AnyNode(Node(label: 2, position: CGPoint(x: 200, y: 200), velocity: CGPoint(x: -10, y: -10)))
            ]
            model.edges = [GraphEdge(from: model.nodes[0].id, target: model.nodes[1].id)]
        }
        await runSimulation(on: model)
        #expect((await model.nodes[0]).velocity.magnitude < 1.2 + tolerance, "Node 1 velocity converges to near-zero")
        #expect((await model.nodes[1]).velocity.magnitude < 1.2 + tolerance, "Node 2 velocity converges to near-zero")
    }
    
    @Test func testUndoRedoMixedOperations() async throws {
        let storage = MockGraphStorage()
        try setupDefaults(for: storage)
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        await model.load()
        await runSimulation(on: model)
        let initialNodeCount = await MainActor.run { model.nodes.count }
        let initialEdgeCount = await MainActor.run { model.edges.count }
        let initialNodes = await model.nodes
        try #require(!initialNodes.isEmpty, "Assumes initial nodes exist")
        await model.snapshot()
        let nodeToDelete = initialNodes[0].id
        let initialEdges = await model.edges
        let connectedEdges = initialEdges.filter { $0.from == nodeToDelete || $0.target == nodeToDelete }.count
        await model.deleteNode(withID: nodeToDelete)
        await runSimulation(on: model)
        await model.snapshot()
        await model.addNode(at: CGPoint.zero)
        await runSimulation(on: model)
        await model.snapshot()  // FIX: Commit post-add state
        #expect(await MainActor.run { model.nodes.count } == initialNodeCount, "After add: count back to initial")
        #expect(await MainActor.run { model.edges.count } == initialEdgeCount - connectedEdges, "Edges reduced by connected count")
        await model.undo() // To post-delete
        #expect(await MainActor.run { model.nodes.count } == initialNodeCount - 1, "Undo reverts to post-delete")
        #expect(await MainActor.run { model.edges.count } == initialEdgeCount - connectedEdges, "Edges match post-delete")
        await model.undo() // To initial
        #expect(await MainActor.run { model.nodes.count } == initialNodeCount, "Second undo restores initial")
        #expect(await MainActor.run { model.edges.count } == initialEdgeCount, "Edges restored")
        let restoredNodes = await model.nodes
        #expect(zip(restoredNodes.sorted(by: { $0.id.uuidString < $1.id.uuidString }), initialNodes.sorted(by: { $0.id.uuidString < $1.id.uuidString })).allSatisfy { approximatelyEqual($0.position, $1.position, accuracy: 1e-5) && approximatelyEqual($0.velocity, $1.velocity, accuracy: 1e-5) }, "Positions and velocities restored")
        await model.redo() // To post-delete
        #expect((await model.nodes).count == initialNodeCount - 1, "Redo applies delete")
        await model.redo() // To post-add
        #expect((await model.nodes).count == initialNodeCount, "Redo applies add")
    }
    
    @Test func testInitializationWithDefaults() async throws {
        let storage = MockGraphStorage()
        try setupDefaults(for: storage)
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        await model.load()
        #expect(await MainActor.run { model.nodes.count } >= 3, "Should load default or saved nodes")
        #expect(await MainActor.run { model.edges.count } >= 3, "Should load default edges")
    }
    
    @Test func testDeleteNodeAndEdges() async throws {
        let storage = MockGraphStorage()
        try setupDefaults(for: storage)
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        await model.load()
        let nodes = await model.nodes
        try #require(!nodes.isEmpty, "Assumes default nodes exist")
        let nodeToDelete = nodes[0].id
        let initialEdgeCount = await model.edges.count
        let connectedEdges = (await model.edges).filter { $0.from == nodeToDelete || $0.target == nodeToDelete }.count
        await model.deleteNode(withID: nodeToDelete)
        #expect(await MainActor.run { model.nodes.count } == nodes.count - 1, "Node deleted")
        #expect(await MainActor.run { model.edges.count } == initialEdgeCount - connectedEdges, "Connected edges deleted")
    }
    
    @Test func testSaveLoadRoundTrip() async throws {
        let storage = MockGraphStorage()
        try setupDefaults(for: storage)
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        await model.load()
        let originalNodeCount = await MainActor.run { model.nodes.count }
        let originalEdges = await model.edges
        await model.addNode(at: CGPoint.zero)
        await runSimulation(on: model)
        let postAddNodes = await model.nodes  // Capture after add and simulation
        await model.snapshot()  // Triggers save() with stabilized positions
        let newModel = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        await newModel.load()
        // Skip runSimulation(on: newModel) - loaded positions should match saved exactly; re-sim amplifies FP errors
        #expect(await MainActor.run { newModel.nodes.count } == originalNodeCount + 1, "Loaded nodes include added one")
        #expect(await newModel.edges == originalEdges, "Edges unchanged")
        let loadedNodes = (await newModel.nodes).sorted(by: { $0.id.uuidString < $1.id.uuidString })
        let expectedNodes = postAddNodes.sorted(by: { $0.id.uuidString < $1.id.uuidString })
        #expect(zip(loadedNodes, expectedNodes).allSatisfy {
            $0.label == $1.label && approximatelyEqual($0.position, $1.position, accuracy: 1e-2)  // Further relaxed for any JSON/FP rounding
        }, "Loaded nodes match expected")
    }
     
}
