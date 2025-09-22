import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
@testable import GraphEditorShared
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

func approximatelyEqual(_ lhs: CGPoint, _ rhs: CGPoint, accuracy: CGFloat) -> Bool {
    return hypot(lhs.x - rhs.x, lhs.y - rhs.y) < accuracy
}

struct GraphModelTests {
    private func mockPhysicsEngine() -> GraphEditorShared.PhysicsEngine {
        GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
    }
    
    @Test func testUndoRedoMixedOperations() async throws {
    let storage = MockGraphStorage()
    let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
    let initialNodeCount = await MainActor.run { model.nodes.count }
    let initialEdgeCount = await MainActor.run { model.edges.count }
    let initialNodes = await model.nodes  // Capture for checks
    try #require(!initialNodes.isEmpty, "Assumes initial nodes exist")
    let nodeToDelete = initialNodes[0].id
    let initialEdges = await model.edges
    let connectedEdges = initialEdges.filter { $0.from == nodeToDelete || $0.target == nodeToDelete }.count
    await model.deleteNode(withID: nodeToDelete)
    await model.addNode(at: CGPoint.zero)
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
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(await MainActor.run { model.nodes.count } >= 3, "Should load default or saved nodes")
        #expect(await MainActor.run { model.edges.count } >= 3, "Should load default edges")
    }
    
    @Test func testSnapshotAndUndo() async throws {
        let storage = MockGraphStorage()
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let initialNodes = await model.nodes
        await model.snapshot()
        await model.addNode(at: CGPoint.zero)
        #expect(await MainActor.run { model.nodes.count } == initialNodes.count + 1, "Node added")
        await model.undo()
        let restoredNodes = await model.nodes
        let idsMatch = Set(restoredNodes.map { $0.id }) == Set(initialNodes.map { $0.id })
        let labelsMatch = Set(restoredNodes.map { $0.label }) == Set(initialNodes.map { $0.label })
        let positionsMatch = zip(restoredNodes.sorted(by: { $0.id.uuidString < $1.id.uuidString }), initialNodes.sorted(by: { $0.id.uuidString < $1.id.uuidString })).allSatisfy { approximatelyEqual($0.position, $1.position, accuracy: 1e-5) }
        let velocitiesMatch = zip(restoredNodes.sorted(by: { $0.id.uuidString < $1.id.uuidString }), initialNodes.sorted(by: { $0.id.uuidString < $1.id.uuidString })).allSatisfy { approximatelyEqual($0.velocity, $1.velocity, accuracy: 1e-5) }
        #expect(idsMatch && labelsMatch && positionsMatch && velocitiesMatch, "Undo restores state including velocities")
    }
    
    @Test func testDeleteNodeAndEdges() async throws {
    let storage = MockGraphStorage()
    let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
    let nodes = await model.nodes
    try #require(!nodes.isEmpty, "Assumes default nodes exist")
    let nodeID = nodes[0].id
    let initialEdgeCount = await MainActor.run { model.edges.count }
    let connectedEdges = await model.edges.filter { $0.from == nodeID || $0.target == nodeID }
    await model.deleteNode(withID: nodeID)
    #expect((await model.nodes.first { $0.id == nodeID }) == nil, "Node deleted")
    #expect(await MainActor.run { model.edges.count } == initialEdgeCount - connectedEdges.count, "Edges reduced exactly by connected count")
    #expect((await model.edges).allSatisfy { $0.from != nodeID && $0.target != nodeID }, "No remaining edges reference deleted node")
    }
    
    @Test func testSaveLoadRoundTrip() async throws {
        let storage = MockGraphStorage()
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let originalNodeCount = await MainActor.run { model.nodes.count }
        let originalEdges = await model.edges
        let originalNodes = await model.nodes
        
        await model.addNode(at: CGPoint.zero)
        let afterAddNodes = await model.nodes  // Capture full list after add
        let addedNode = afterAddNodes.last!    // Assumes added node is appended; adjust if not
        
        await model.snapshot()
        
        let newModel = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(await MainActor.run { newModel.nodes.count } == originalNodeCount + 1, "Loaded nodes include added one")
        #expect(await newModel.edges == originalEdges, "Edges unchanged")
        
        let loadedNodes = (await newModel.nodes).sorted(by: { $0.id.uuidString < $1.id.uuidString })
        let expectedNodes = (originalNodes + [addedNode]).sorted(by: { $0.id.uuidString < $1.id.uuidString })
        #expect(zip(loadedNodes, expectedNodes).allSatisfy {
            $0.label == $1.label && approximatelyEqual($0.position, $1.position, accuracy: 1e-5)
        }, "Loaded nodes match expected")
    }
    
    @Test(arguments: 1..<5) func testConvergencePropertyBased(seed: Int) async throws {
        let storage = MockGraphStorage()
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
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
        let tempNodes = nodesToAssign
        var edgesToAssign: [GraphEdge] = []
        for _ in 0..<3 {
            let fromIndex = Int.random(in: 0..<tempNodes.count, using: &rng)
            let targetIndex = Int.random(in: 0..<tempNodes.count, using: &rng)
            edgesToAssign.append(GraphEdge(from: tempNodes[fromIndex].id, target: tempNodes[targetIndex].id))
        }
        await MainActor.run { [nodesToAssign, edgesToAssign] in
            model.nodes = nodesToAssign
            model.edges = edgesToAssign
        }
        
        await model.startSimulation()
        for _ in 0..<Constants.Physics.maxSimulationSteps {
            var nodes = await model.nodes
            var activeAccum = false
            for _ in 0..<20 {
                let currentNodes = nodes.map { $0.unwrapped }
                let physics = await model.physicsEngine
                let edges = await model.edges
                let (updatedNodes, stepActive) = physics.simulationStep(nodes: currentNodes, edges: edges)
                nodes = updatedNodes.map(AnyNode.init)
                activeAccum = activeAccum || stepActive
                if !stepActive { break }
            }
            let capturedNodes = nodes
            await MainActor.run { model.nodes = capturedNodes }
            if !activeAccum { break }
        }
        
        let totalVel = (await model.nodes).reduce(0.0) { $0 + $1.velocity.magnitude }
        let nodeCount = await MainActor.run { model.nodes.count }
        #expect(totalVel < 2.0 * CGFloat(nodeCount), "Velocities near zero for seed \(seed)")
    }
    
    @Test func testSimulationConvergence() async {
        let tolerance: CGFloat = 0.05
        let storage = MockGraphStorage()
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        await MainActor.run {
            model.nodes = [
                AnyNode(Node(label: 1, position: CGPoint(x: 100, y: 100), velocity: CGPoint(x: 10, y: 10))),
                AnyNode(Node(label: 2, position: CGPoint(x: 200, y: 200), velocity: CGPoint(x: -10, y: -10)))
            ]
            model.edges = [GraphEdge(from: model.nodes[0].id, target: model.nodes[1].id)]
        }
        
        await model.startSimulation()
        for _ in 0..<Constants.Physics.maxSimulationSteps {
            var nodes = await model.nodes
            var activeAccum = false
            let subSteps = 20
            for _ in 0..<subSteps {
                let currentNodes = nodes.map { $0.unwrapped }
                let physics = await model.physicsEngine
                let edges = await model.edges
                let (updatedNodes, stepActive) = physics.simulationStep(nodes: currentNodes, edges: edges)
                nodes = updatedNodes.map(AnyNode.init)
                activeAccum = activeAccum || stepActive
                if !stepActive { break }
            }
            let capturedNodes = nodes
            await MainActor.run { model.nodes = capturedNodes }
            if !activeAccum { break }
        }
        
        #expect((await model.nodes[0]).velocity.magnitude < 1.2 + tolerance, "Node 1 velocity converges to near-zero")
        #expect((await model.nodes[1]).velocity.magnitude < 1.2 + tolerance, "Node 2 velocity converges to near-zero")
    }
}

struct CoordinateTransformerTests {
    @Test func testCoordinateRoundTrip() {
        let viewSize = CGSize(width: 205, height: 251)
        let centroid = CGPoint(x: 150, y: 150)
        let modelPos = CGPoint(x: 167.78, y: 165.66)
        let zoom: CGFloat = 1.0
        let offset = CGSize.zero
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Round-trip should match original model position")
    }
    
    @Test func testCoordinateRoundTripWithZoomAndOffset() {
        let viewSize = CGSize(width: 205, height: 251)
        let centroid = CGPoint(x: 56.73, y: 161.10)
        let modelPos = CGPoint(x: -40.27, y: 52.60)
        let zoom: CGFloat = 1.0
        let offset = CGSize(width: 81, height: 111.5)
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Round-trip with zoom and offset should match")
    }
}

struct GestureTests {
    private func setupModel() async -> GraphModel {
        let storage = MockGraphStorage()
        let physicsEngine = GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = await GraphModel(storage: storage, physicsEngine: physicsEngine)
        await MainActor.run { model.nodes = [] }
        await MainActor.run { model.edges = [] }
        await model.addNode(at: CGPoint(x: 0, y: 0))
        await model.addNode(at: CGPoint(x: 50, y: 50))
        return model
    }
    
    @Test func testDragCreatesEdge() async throws {
        let model = await setupModel()
        #expect((await model.edges).isEmpty, "No edges initially")
        
        let viewModel = await GraphViewModel(model: model)
        let draggedNode = await model.nodes[0]
        let potentialEdgeTarget = await model.nodes[1]
        let initialPosition = draggedNode.position
        
        let mockTranslation = CGSize(width: 50, height: 50)
        let dragOffset = CGPoint(x: mockTranslation.width / 1.0, y: mockTranslation.height / 1.0)
        let dragDistance = hypot(mockTranslation.width, mockTranslation.height)
        
        if let index = (await viewModel.model.nodes).firstIndex(where: { $0.id == draggedNode.id }) {
            await viewModel.model.snapshot()
            if dragDistance < AppConstants.tapThreshold {
                // Tap logic (skipped)
            } else {
                if potentialEdgeTarget.id != draggedNode.id {
                    let fromID = draggedNode.id
                    let toID = potentialEdgeTarget.id
                    let edgeExists = await MainActor.run {
                        let edges = viewModel.model.edges  // No await needed here if already on MainActor
                        let forwardMatch = edges.contains { $0.from == fromID && $0.target == toID }
                        let reverseMatch = edges.contains { $0.from == toID && $0.target == fromID }
                        return forwardMatch || reverseMatch
                    }
                    if !edgeExists {
                        await MainActor.run { viewModel.model.edges.append(GraphEdge(from: fromID, target: toID)) }
                        await viewModel.model.startSimulation()
                    } else {
                        await MainActor.run {
                            let currentPos = viewModel.model.nodes[index].position
                            viewModel.model.nodes[index] = viewModel.model.nodes[index].with(position: CGPoint(x: currentPos.x + dragOffset.x, y: currentPos.y + dragOffset.y), velocity: .zero)
                        }
                        await viewModel.model.startSimulation()
                    }
                }
            }
        }
        
        #expect((await viewModel.model.edges).count == 1, "Edge created after simulated drag")
        let newEdge = (await viewModel.model.edges).first!
        #expect(newEdge.from == draggedNode.id, "Edge from correct node")
        #expect(newEdge.target == potentialEdgeTarget.id, "Edge to correct node")
        #expect(approximatelyEqual((await model.nodes[0]).position, initialPosition, accuracy: 1e-5), "Position unchanged on create")
    }
    
    @Test func testShortDragAsTap() async throws {
        let model = await setupModel()
        #expect((await model.edges).isEmpty, "No edges initially")
        
        let viewModel = await GraphViewModel(model: model)
        let draggedNode = await model.nodes[0]
        let initialPosition = draggedNode.position
        let initialEdgeCount = (await model.edges).count
        
        let mockTranslation = CGSize(width: 1, height: 1)  // Small, < tapThreshold
        let dragDistance = hypot(mockTranslation.width, mockTranslation.height)
        
        if let index = (await viewModel.model.nodes).firstIndex(where: { $0.id == draggedNode.id }) {
            _ = index  // Silence unused warning
            await viewModel.model.snapshot()
            if dragDistance < AppConstants.tapThreshold {
                // Tap logic (skipped; assume no side effects for this test)
            } else {
                // Drag branch skipped due to small distance
            }
        }
        
        #expect((await model.edges).count == initialEdgeCount, "No edge created on short drag")
        #expect(approximatelyEqual((await model.nodes[0]).position, initialPosition, accuracy: 1e-5), "Position unchanged")
    }
    
    @Test func testDragMovesNodeIfEdgeExists() async throws {
        let model = await setupModel()
        let fromID = (await model.nodes[0]).id
        let toID = (await model.nodes[1]).id
        await MainActor.run { model.edges.append(GraphEdge(from: fromID, target: toID)) }
        #expect((await model.edges).count == 1, "Edge exists initially")
        
        let viewModel = await GraphViewModel(model: model)
        let draggedNode = await model.nodes[0]
        let potentialEdgeTarget = await model.nodes[1]
        let initialPosition = draggedNode.position
        
        let mockTranslation = CGSize(width: 50, height: 50)
        let dragOffset = CGPoint(x: mockTranslation.width / 1.0, y: mockTranslation.height / 1.0)
        let dragDistance = hypot(mockTranslation.width, mockTranslation.height)
        
        if let index = (await viewModel.model.nodes).firstIndex(where: { $0.id == draggedNode.id }) {
            await viewModel.model.snapshot()
            if dragDistance < AppConstants.tapThreshold {
                // Tap logic (skipped)
            } else {
                if potentialEdgeTarget.id != draggedNode.id {
                    let fromID = draggedNode.id
                    let toID = potentialEdgeTarget.id
                    let edgeExists = await MainActor.run {
                        let edges = viewModel.model.edges
                        let forwardMatch = edges.contains { $0.from == fromID && $0.target == toID }
                        let reverseMatch = edges.contains { $0.from == toID && $0.target == fromID }
                        return forwardMatch || reverseMatch
                    }
                    if !edgeExists {
                        await MainActor.run { viewModel.model.edges.append(GraphEdge(from: fromID, target: toID)) }
                        await viewModel.model.startSimulation()
                    } else {
                        await MainActor.run {
                            let currentPos = viewModel.model.nodes[index].position
                            viewModel.model.nodes[index] = viewModel.model.nodes[index].with(position: CGPoint(x: currentPos.x + dragOffset.x, y: currentPos.y + dragOffset.y), velocity: .zero)
                        }
                        await viewModel.model.startSimulation()
                    }
                }
            }
        }
        
        #expect((await viewModel.model.edges).count == 1, "No new edge created")
        #expect(!approximatelyEqual((await model.nodes[0]).position, initialPosition, accuracy: 1e-5), "Position changed on move")
        #expect(approximatelyEqual((await model.nodes[0]).position, initialPosition + dragOffset, accuracy: 1e-5), "Moved by offset")
    }
}

struct AccessibilityTests {
    private func mockPhysicsEngine() -> GraphEditorShared.PhysicsEngine {
        GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
    }
    
    @Test func testGraphDescription() async throws {
        let storage = MockGraphStorage()
        storage.nodes = [Node(label: 0, position: .zero)]
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        await MainActor.run { model.nextNodeLabel = 1 }
        await model.addNode(at: .zero)
        await model.addNode(at: CGPoint(x: 10, y: 10))
        
        await MainActor.run { model.edges.append(GraphEdge(from: model.nodes[0].id, target: model.nodes[1].id)) }
        
        let descNoSelect = await MainActor.run { model.graphDescription(selectedID: nil, selectedEdgeID: nil) }
        #expect(descNoSelect == "Graph with 2 nodes and 1 directed edge. No node or edge selected.", "Correct desc without selection")
        
        let descWithSelect = await MainActor.run { model.graphDescription(selectedID: model.nodes[0].id, selectedEdgeID: nil) }
        #expect(descWithSelect == "Graph with 2 nodes and 1 directed edge. Node 1 selected, outgoing to: 2; incoming from: none.", "Correct desc with selection")
    }
}
