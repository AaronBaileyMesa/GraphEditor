// File: Tests/GraphEditorWatchTests/GraphEditorWatchTests.swift
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
    
    @Test func testSaveLoadRoundTrip() {
        let model = GraphModel()
        let originalNodes = model.nodes
        let originalEdges = model.edges
        // Modify and snapshot to trigger save
        model.addNode(at: .zero)
        model.snapshot()
        // New instance to trigger load
        let newModel = GraphModel()
        #expect(newModel.nodes.count == originalNodes.count + 1, "Loaded nodes include addition")
        #expect(newModel.edges == originalEdges, "Loaded edges match original")
    }
    
    @Test func testAddNode() {
        let model = GraphModel()
        let initialCount = model.nodes.count
        model.addNode(at: .zero)
        #expect(model.nodes.count == initialCount + 1, "Node added")
    }
    
    @Test func testSimulationStep() {
            let storage = MockGraphStorage()
            let model = GraphModel(storage: storage)
            var nodes = model.nodes
            let edges = model.edges
            let isRunning = model.physicsEngine.simulationStep(nodes: &nodes, edges: edges)
            #expect(isRunning, "Simulation should run if not stable")
        }
}



// File: GraphEditorShared/Tests/GraphEditorSharedTests/GraphEditorSharedTests.swift
import Testing
import Foundation  // For UUID, JSONEncoder, JSONDecoder
import CoreGraphics  // For CGPoint
@testable import GraphEditorShared

struct GraphEditorSharedTests {

    @Test func testNodeInitializationAndEquality() {
        let id = UUID()
        let node1 = Node(id: id, label: 1, position: CGPoint(x: 10, y: 20))
        let node2 = Node(id: id, label: 1, position: CGPoint(x: 10, y: 20))
        #expect(node1 == node2, "Nodes with same properties should be equal")
        
        let node3 = Node(id: UUID(), label: 2, position: .zero)
        #expect(node1 != node3, "Nodes with different IDs/labels should not be equal")
    }
    
    @Test func testNodeCodingRoundTrip() throws {
        let node = Node(id: UUID(), label: 1, position: CGPoint(x: 5, y: 10), velocity: CGPoint(x: 1, y: 2))
        let encoder = JSONEncoder()
        let data = try encoder.encode(node)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Node.self, from: data)
        #expect(node == decoded, "Node should encode and decode without data loss")
    }
    
    @Test func testGraphEdgeInitializationAndEquality() {
        let id = UUID()
        let from = UUID()
        let to = UUID()
        let edge1 = GraphEdge(id: id, from: from, to: to)
        let edge2 = GraphEdge(id: id, from: from, to: to)
        #expect(edge1 == edge2, "Edges with same properties should be equal")
        
        let edge3 = GraphEdge(from: to, to: from)
        #expect(edge1 != edge3, "Edges with swapped from/to should not be equal")
    }
    
    @Test func testCGPointExtensions() {
        let point1 = CGPoint(x: 3, y: 4)
        let point2 = CGPoint(x: 1, y: 2)
        
        #expect(point1 + point2 == CGPoint(x: 4, y: 6), "Addition should work")
        #expect(point1 - point2 == CGPoint(x: 2, y: 2), "Subtraction should work")
        #expect(point1 * 2 == CGPoint(x: 6, y: 8), "Scalar multiplication should work")
        #expect(point1.magnitude == 5, "Magnitude should be correct")
    }
    
    @Test func testDistanceFunction() {
        let a = CGPoint(x: 0, y: 0)
        let b = CGPoint(x: 3, y: 4)
        #expect(distance(a, b) == 5, "Distance should be calculated correctly")
    }
    
    @Test func testGraphStateInitialization() {
        let nodes = [Node(id: UUID(), label: 1, position: .zero)]
        let edges = [GraphEdge(from: UUID(), to: UUID())]
        let state = GraphState(nodes: nodes, edges: edges)
        #expect(state.nodes == nodes, "Nodes should match")
        #expect(state.edges == edges, "Edges should match")
    }
    
    @Test func testCGFloatClamping() {
        let value: CGFloat = 15
        let clamped = value.clamped(to: 0...10)
        #expect(clamped == 10, "Value should clamp to upper bound")
        
        let lowValue: CGFloat = -5
        let clampedLow = lowValue.clamped(to: 0...10)
        #expect(clampedLow == 0, "Value should clamp to lower bound")
    }
    
    @Test func testCGPointMagnitudeEdgeCases() {
        let zeroPoint = CGPoint.zero
        #expect(zeroPoint.magnitude == 0, "Zero point magnitude should be 0")
        
        let negativePoint = CGPoint(x: -3, y: -4)
        #expect(negativePoint.magnitude == 5, "Magnitude should be positive for negative coordinates")
    }
    @Test func testNodeDecodingWithMissingKeys() throws {
        // Test partial data to cover error paths in init(from decoder:)
        let json = "{\"id\": \"\(UUID())\", \"label\": 1}"  // Missing position/velocity
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(Node.self, from: data)
        }
    }
    
    @Test func testGraphEdgeCodingRoundTrip() throws {
        let edge = GraphEdge(id: UUID(), from: UUID(), to: UUID())
        let encoder = JSONEncoder()
        let data = try encoder.encode(edge)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GraphEdge.self, from: data)
        #expect(edge == decoded, "Edge should encode and decode without loss")
    }
    
    @Test func testCGSizeExtensions() {
        let size1 = CGSize(width: 10, height: 20)
        let size2 = CGSize(width: 5, height: 10)
        
        #expect(size1 / 2 == CGSize(width: 5, height: 10), "Division should work")
        #expect(size1 + size2 == CGSize(width: 15, height: 30), "Addition should work")
        
        var mutableSize = size1
        mutableSize += size2
        #expect(mutableSize == CGSize(width: 15, height: 30), "In-place addition should work")
    }
    
    @Test func testDoubleClamping() {
        let value: Double = 15
        let clamped = value.clamped(to: 0...10)
        #expect(clamped == 10, "Double should clamp to upper bound")
        
        let lowValue: Double = -5
        let clampedLow = lowValue.clamped(to: 0...10)
        #expect(clampedLow == 0, "Double should clamp to lower bound")
    }
    
    @Test func testGraphStateCoding() throws {
        let state = GraphState(nodes: [Node(id: UUID(), label: 1, position: .zero)], edges: [GraphEdge(from: UUID(), to: UUID())])
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GraphState.self, from: data)
        #expect(state.nodes == decoded.nodes, "GraphState nodes should match after coding")
        #expect(state.edges == decoded.edges, "GraphState edges should match after coding")
    }
    
    @Test func testGraphEdgeDecodingWithMissingKeys() throws {
        // Cover error paths in init(from decoder:)
        let json = "{\"id\": \"\(UUID())\", \"from\": \"\(UUID())\"}"  // Missing 'to'
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(GraphEdge.self, from: data)
        }
    }
    
    @Test func testCGPointDivisionAndZeroMagnitude() {
        let point = CGPoint(x: 10, y: 20)
        #expect(point / 2 == CGPoint(x: 5, y: 10), "Division should work")
        
        let zeroPoint = CGPoint.zero
        #expect(zeroPoint.magnitude == 0, "Zero magnitude confirmed")
        #expect(zeroPoint / 1 == .zero, "Division of zero point should remain zero")
    }
    
    @Test func testDoubleAndCGFloatClampingEdgeCases() {
        let doubleMax: Double = .greatestFiniteMagnitude
        #expect(doubleMax.clamped(to: 0...1) == 1, "Clamps max value")
        
        let cgfloatMin: CGFloat = -.greatestFiniteMagnitude
        #expect(cgfloatMin.clamped(to: 0...1) == 0, "Clamps min value")
    }
    
    @Test func testCGPointAllOperators() {
        var point1 = CGPoint(x: 5, y: 10)
        let point2 = CGPoint(x: 3, y: 4)
        let scalar: CGFloat = 2
        
        // Cover + and +=
        #expect(point1 + point2 == CGPoint(x: 8, y: 14), "Addition should work")
        point1 += point2
        #expect(point1 == CGPoint(x: 8, y: 14), "In-place addition should work")
        
        // Cover - and -=
        #expect(point1 - point2 == CGPoint(x: 5, y: 10), "Subtraction should work")
        point1 -= point2
        #expect(point1 == CGPoint(x: 5, y: 10), "In-place subtraction should work")
        
        // Cover * and *=
        #expect(point1 * scalar == CGPoint(x: 10, y: 20), "Multiplication should work")
        point1 *= scalar
        #expect(point1 == CGPoint(x: 10, y: 20), "In-place multiplication should work")
        
        // Cover /
        #expect(point1 / scalar == CGPoint(x: 5, y: 10), "Division should work")
    }
    
    @Test func testCGPointWithSizeOperators() {
        var point = CGPoint(x: 5, y: 10)
        let size = CGSize(width: 3, height: 4)
        
        #expect(point + size == CGPoint(x: 8, y: 14), "Addition with size should work")
        point += size
        #expect(point == CGPoint(x: 8, y: 14), "In-place addition with size should work")
    }
    
    @Test func testCGSizeAllOperators() {
        var size1 = CGSize(width: 10, height: 20)
        let size2 = CGSize(width: 5, height: 10)
        let scalar: CGFloat = 2
        
        // Cover + and +=
        #expect(size1 + size2 == CGSize(width: 15, height: 30), "Addition should work")
        size1 += size2
        #expect(size1 == CGSize(width: 15, height: 30), "In-place addition should work")
        
        // Cover /
        #expect(size1 / scalar == CGSize(width: 7.5, height: 15), "Division should work")
    }
    
    @Test func testClampingEdgeCases() {
        // Double clamping with extremes
        let infDouble = Double.infinity
        #expect(infDouble.clamped(to: 0...100) == 100, "Infinity clamps to upper")
        #expect((-infDouble).clamped(to: 0...100) == 0, "Negative infinity clamps to lower")
        
        // CGFloat clamping with extremes
        let infCGFloat = CGFloat.infinity
        #expect(infCGFloat.clamped(to: 0...100) == 100, "Infinity clamps to upper")
        #expect((-infCGFloat).clamped(to: 0...100) == 0, "Negative infinity clamps to lower")
        
        // NaN handling: Actual impl clamps to lower bound, so expect that
        let nanDouble = Double.nan
        #expect(nanDouble.clamped(to: 0...100) == 0, "NaN clamps to lower bound")
    }
    
    @Test func testDistanceEdgeCases() {
        let samePoint = CGPoint(x: 5, y: 5)
        #expect(distance(samePoint, samePoint) == 0, "Distance to self is 0")
        
        let negativePoints = CGPoint(x: -3, y: -4)
        let origin = CGPoint.zero
        #expect(distance(negativePoints, origin) == 5, "Distance with negatives is positive")
    }
    
}



// File: GraphEditorShared/Package.swift
// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GraphEditorShared",
    platforms: [.watchOS(.v9)],  // Set to your project's min watchOS version
    products: [
        .library(
            name: "GraphEditorShared",
            targets: ["GraphEditorShared"]),
    ],
    targets: [
        .target(
            name: "GraphEditorShared",
            path: "Sources/GraphEditorShared"  // Explicitly set path if needed
        ),
        .testTarget(
            name: "GraphEditorSharedTests",
            dependencies: ["GraphEditorShared"],
            path: "Tests/GraphEditorSharedTests"  // Explicitly set path if needed
        ),
    ]
)



// File: GraphEditorShared/Sources/GraphEditorShared/Utilities.swift
import Foundation
import CoreGraphics

public extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        max(range.lowerBound, min(self, range.upperBound))
    }
}

public extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}

public extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    
    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }
    
    static func += (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs + rhs
    }
    
    static func -= (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs - rhs
    }
    
    static func *= (lhs: inout CGPoint, rhs: CGFloat) {
        lhs = lhs * rhs
    }
    
    static func + (lhs: CGPoint, rhs: CGSize) -> CGPoint {
        CGPoint(x: lhs.x + rhs.width, y: lhs.y + rhs.height)
    }
    
    static func += (lhs: inout CGPoint, rhs: CGSize) {
        lhs = lhs + rhs
    }
    
    var magnitude: CGFloat {
        hypot(x, y)
    }
}

public extension CGSize {
    static func / (lhs: CGSize, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width / rhs, height: lhs.height / rhs)
    }
    
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
    
    static func += (lhs: inout CGSize, rhs: CGSize) {
        lhs = lhs + rhs
    }
}

// Shared utility functions
public func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    hypot(a.x - b.x, a.y - b.y)
}



// File: GraphEditorShared/Sources/GraphEditorShared/Protocols.swift
//
//  GraphStorage.swift
//  GraphEditorShared
//
//  Created by handcart on 8/1/25.
//


public protocol GraphStorage {
    func save(nodes: [Node], edges: [GraphEdge])
    func load() -> (nodes: [Node], edges: [GraphEdge])
}



// File: GraphEditorShared/Sources/GraphEditorShared/GraphTypes.swift
import SwiftUI
import Foundation

public typealias NodeID = UUID

// Represents a node in the graph with position, velocity, and permanent label.
public struct Node: Identifiable, Equatable, Codable {
    public let id: NodeID
    public let label: Int  // Permanent label, assigned on creation
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    
    enum CodingKeys: String, CodingKey {
        case id, label
        case positionX, positionY
        case velocityX, velocityY
    }
    
    public init(id: NodeID = NodeID(), label: Int, position: CGPoint, velocity: CGPoint = .zero) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        let posX = try container.decode(CGFloat.self, forKey: .positionX)
        let posY = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: posX, y: posY)
        let velX = try container.decode(CGFloat.self, forKey: .velocityX)
        let velY = try container.decode(CGFloat.self, forKey: .velocityY)
        velocity = CGPoint(x: velX, y: velY)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(velocity.x, forKey: .velocityX)
        try container.encode(velocity.y, forKey: .velocityY)
    }
}

// Represents an edge connecting two nodes.
public struct GraphEdge: Identifiable, Equatable, Codable {
    public let id: NodeID
    public let from: NodeID
    public let to: NodeID
    
    enum CodingKeys: String, CodingKey {
        case id, from, to
    }
    
    public init(id: NodeID = NodeID(), from: NodeID, to: NodeID) {
        self.id = id
        self.from = from
        self.to = to
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        from = try container.decode(NodeID.self, forKey: .from)
        to = try container.decode(NodeID.self, forKey: .to)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
    }
}

// Snapshot of the graph state for undo/redo.
public struct GraphState: Codable {
    public let nodes: [Node]
    public let edges: [GraphEdge]
    
    public init(nodes: [Node], edges: [GraphEdge]) {
        self.nodes = nodes
        self.edges = edges
    }
}



// File: GraphEditorWatch/ViewModels/GraphViewModel.swift
//
//  GraphViewModel.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//


// ViewModels/GraphViewModel.swift
import SwiftUI
import Combine
import GraphEditorShared

class GraphViewModel: ObservableObject {
    @Published var model: GraphModel
    private var cancellable: AnyCancellable?
    
    var canUndo: Bool {
        model.canUndo
    }
    
    var canRedo: Bool {
        model.canRedo
    }
    
    init(model: GraphModel) {
        self.model = model
        cancellable = model.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
    
    func snapshot() {
        model.snapshot()
    }
    
    func undo() {
        model.undo()
    }
    
    func redo() {
        model.redo()
    }
    
    func deleteNode(withID id: NodeID) {
        model.deleteNode(withID: id)
    }
    
    func deleteEdge(withID id: NodeID) {
        model.deleteEdge(withID: id)
    }
}



// File: GraphEditorWatch/Models/PhysicsEngine.swift
//
//  Constants.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//


// Models/PhysicsEngine.swift
import SwiftUI
import Foundation
import GraphEditorShared

struct Constants {
    static let stiffness: CGFloat = 0.01
    static let repulsion: CGFloat = 15000
    static let damping: CGFloat = 0.95
    static let idealLength: CGFloat = 100
    static let centeringForce: CGFloat = 0.001
    static let distanceEpsilon: CGFloat = 1e-3
    static let timeStep: CGFloat = 1 / 60
    static let velocityThreshold: CGFloat = 0.05
    static let maxSimulationSteps = 200
}

struct Quadtree {
    let bounds: CGRect
    var centerOfMass: CGPoint = .zero
    var totalMass: CGFloat = 0
    var children: [Quadtree]? = nil
    var node: Node? = nil
    
    init(bounds: CGRect) {
        self.bounds = bounds
    }
    
    mutating func insert(_ node: Node) {
        if let _ = children {
            updateCenterOfMass(with: node)
            let quadrant = getQuadrant(for: node.position)
            children?[quadrant].insert(node)
        } else {
            if let existingNode = self.node {
                subdivide()
                let existingQuadrant = getQuadrant(for: existingNode.position)
                children?[existingQuadrant].insert(existingNode)
                let newQuadrant = getQuadrant(for: node.position)
                children?[newQuadrant].insert(node)
                self.node = nil
            } else {
                self.node = node
                updateCenterOfMass(with: node)
            }
        }
    }
    
    private mutating func subdivide() {
        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2
        children = [
            Quadtree(bounds: CGRect(x: bounds.minX, y: bounds.minY, width: halfWidth, height: halfHeight)),
            Quadtree(bounds: CGRect(x: bounds.minX + halfWidth, y: bounds.minY, width: halfWidth, height: halfHeight)),
            Quadtree(bounds: CGRect(x: bounds.minX, y: bounds.minY + halfHeight, width: halfWidth, height: halfHeight)),
            Quadtree(bounds: CGRect(x: bounds.minX + halfWidth, y: bounds.minY + halfHeight, width: halfWidth, height: halfHeight))
        ]
    }
    
    private func getQuadrant(for point: CGPoint) -> Int {
        let midX = bounds.midX
        let midY = bounds.midY
        if point.x < midX {
            if point.y < midY { return 0 }
            else { return 2 }
        } else {
            if point.y < midY { return 1 }
            else { return 3 }
        }
    }
    
    private mutating func updateCenterOfMass(with node: Node) {
        // Assuming mass = 1 for each node
        centerOfMass = (centerOfMass * totalMass + node.position) / (totalMass + 1)
        totalMass += 1
    }
    
    func computeForce(on node: Node, theta: CGFloat = 0.5) -> CGPoint {
        guard totalMass > 0 else { return .zero }
        if let existingNode = self.node, existingNode.id != node.id {
            return repulsionForce(from: existingNode.position, to: node.position)
        }
        let delta = centerOfMass - node.position
        let dist = max(delta.magnitude, Constants.distanceEpsilon)
        if bounds.width / dist < theta || children == nil {
            return repulsionForce(from: centerOfMass, to: node.position, mass: totalMass)
        } else {
            var force: CGPoint = .zero
            for child in children ?? [] {
                force += child.computeForce(on: node, theta: theta)
            }
            return force
        }
    }
    
    private func repulsionForce(from: CGPoint, to: CGPoint, mass: CGFloat = 1) -> CGPoint {
        let deltaX = to.x - from.x
        let deltaY = to.y - from.y
        let dist = max(hypot(deltaX, deltaY), Constants.distanceEpsilon)
        let forceMagnitude = Constants.repulsion * mass / (dist * dist)
        return CGPoint(x: deltaX / dist * forceMagnitude, y: deltaY / dist * forceMagnitude)
    }
}

public class PhysicsEngine {
    public init() {}
    let simulationBounds: CGSize = CGSize(width: 300, height: 300)
    
    private var simulationSteps = 0
    
    func resetSimulation() {
        simulationSteps = 0
    }
    
    @discardableResult
        func simulationStep(nodes: inout [Node], edges: [GraphEdge]) -> Bool {
            if simulationSteps >= Constants.maxSimulationSteps {
                return false
            }
            simulationSteps += 1
            
            var forces: [NodeID: CGPoint] = [:]
            let center = CGPoint(x: simulationBounds.width / 2, y: simulationBounds.height / 2)
            
            // Build Quadtree for repulsion (Barnes-Hut)
            var quadtree = Quadtree(bounds: CGRect(origin: .zero, size: simulationBounds))
            for node in nodes {
                quadtree.insert(node)
            }
            
            // Repulsion using Quadtree
            for i in 0..<nodes.count {
                let repulsion = quadtree.computeForce(on: nodes[i])
                forces[nodes[i].id] = (forces[nodes[i].id] ?? .zero) + repulsion
            }
        
        // Attraction on edges
        for edge in edges {
            guard let fromIdx = nodes.firstIndex(where: { $0.id == edge.from }),
                  let toIdx = nodes.firstIndex(where: { $0.id == edge.to }) else { continue }
            let deltaX = nodes[toIdx].position.x - nodes[fromIdx].position.x
            let deltaY = nodes[toIdx].position.y - nodes[fromIdx].position.y
            let dist = max(hypot(deltaX, deltaY), Constants.distanceEpsilon)
            let forceMagnitude = Constants.stiffness * (dist - Constants.idealLength)
            let forceDirectionX = deltaX / dist
            let forceDirectionY = deltaY / dist
            let forceX = forceDirectionX * forceMagnitude
            let forceY = forceDirectionY * forceMagnitude
            let currentForceFrom = forces[nodes[fromIdx].id] ?? .zero
            forces[nodes[fromIdx].id] = CGPoint(x: currentForceFrom.x + forceX, y: currentForceFrom.y + forceY)
            let currentForceTo = forces[nodes[toIdx].id] ?? .zero
            forces[nodes[toIdx].id] = CGPoint(x: currentForceTo.x - forceX, y: currentForceTo.y - forceY)
        }
        
        // Weak centering force
        for i in 0..<nodes.count {
            let deltaX = center.x - nodes[i].position.x
            let deltaY = center.y - nodes[i].position.y
            let forceX = deltaX * Constants.centeringForce
            let forceY = deltaY * Constants.centeringForce
            let currentForce = forces[nodes[i].id] ?? .zero
            forces[nodes[i].id] = CGPoint(x: currentForce.x + forceX, y: currentForce.y + forceY)
        }
        
        // Apply forces
        for i in 0..<nodes.count {
            let id = nodes[i].id
            var node = nodes[i]
            let force = forces[id] ?? .zero
            node.velocity = CGPoint(x: node.velocity.x + force.x * Constants.timeStep, y: node.velocity.y + force.y * Constants.timeStep)
            node.velocity = CGPoint(x: node.velocity.x * Constants.damping, y: node.velocity.y * Constants.damping)
            node.position = CGPoint(x: node.position.x + node.velocity.x * Constants.timeStep, y: node.position.y + node.velocity.y * Constants.timeStep)
            node.position.x = max(0, min(simulationBounds.width, node.position.x))
            node.position.y = max(0, min(simulationBounds.height, node.position.y))
            nodes[i] = node
        }
        
        // Check if stable
        let totalVelocity = nodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }
        return totalVelocity >= Constants.velocityThreshold
    }
    
    func boundingBox(nodes: [Node]) -> CGRect {
        if nodes.isEmpty { return .zero }
        let xs = nodes.map { $0.position.x }
        let ys = nodes.map { $0.position.y }
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}



// File: GraphEditorWatch/Models/PersistenceManager.swift
// Models/PersistenceManager.swift
//
//  PersistenceManager.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//

import Foundation
import GraphEditorShared

public class PersistenceManager: GraphStorage {
    
    private let nodesFileName = "graphNodes.json"
    private let edgesFileName = "graphEdges.json"
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    public init() {}
    
    public func save(nodes: [Node], edges: [GraphEdge]) {
        let encoder = JSONEncoder()
        do {
            let nodeData = try encoder.encode(nodes)
            let nodeURL = documentsDirectory.appendingPathComponent(nodesFileName)
            try nodeData.write(to: nodeURL)
            
            let edgeData = try encoder.encode(edges)
            let edgeURL = documentsDirectory.appendingPathComponent(edgesFileName)
            try edgeData.write(to: edgeURL)
        } catch {
            print("Error saving graph: \(error)")
        }
    }
    
    public func load() -> (nodes: [Node], edges: [GraphEdge]) {
        let decoder = JSONDecoder()
        var loadedNodes: [Node] = []
        var loadedEdges: [GraphEdge] = []
        
        let nodeURL = documentsDirectory.appendingPathComponent(nodesFileName)
        if let nodeData = try? Data(contentsOf: nodeURL),
           let decodedNodes = try? decoder.decode([Node].self, from: nodeData) {
            loadedNodes = decodedNodes
        }
        
        let edgeURL = documentsDirectory.appendingPathComponent(edgesFileName)
        if let edgeData = try? Data(contentsOf: edgeURL),
           let decodedEdges = try? decoder.decode([GraphEdge].self, from: edgeData) {
            loadedEdges = decodedEdges
        }
        
        return (loadedNodes, loadedEdges)
    }
}



// File: GraphEditorWatch/Models/GraphModel.swift
// Models/GraphModel.swift
import SwiftUI
import Combine
import Foundation
import GraphEditorShared

public class GraphModel: ObservableObject {
    @Published var nodes: [Node] = []
    @Published var edges: [GraphEdge] = []
    
    private var undoStack: [GraphState] = []
    private var redoStack: [GraphState] = []
    private let maxUndo = 10
    private var nextNodeLabel = 1  // Auto-increment for node labels
    
    private let storage: GraphStorage
    internal let physicsEngine: PhysicsEngine

    private var timer: Timer? = nil
    
    // Indicates if undo is possible.
    var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    // Indicates if redo is possible.
    var canRedo: Bool {
        !redoStack.isEmpty
    }
    
    // Initializes the graph model, loading from persistence if available.
    public init(storage: GraphStorage = PersistenceManager(), physicsEngine: PhysicsEngine = PhysicsEngine()) {            self.storage = storage
            self.physicsEngine = physicsEngine
            let loaded = storage.load()
            nodes = loaded.nodes
            edges = loaded.edges
            if nodes.isEmpty && edges.isEmpty {
                nodes = [
                    Node(label: nextNodeLabel, position: CGPoint(x: 100, y: 100)),
                    Node(label: nextNodeLabel + 1, position: CGPoint(x: 200, y: 200)),
                    Node(label: nextNodeLabel + 2, position: CGPoint(x: 150, y: 300))
                ]
                nextNodeLabel += 3
                edges = [
                    GraphEdge(from: nodes[0].id, to: nodes[1].id),
                    GraphEdge(from: nodes[1].id, to: nodes[2].id),
                    GraphEdge(from: nodes[2].id, to: nodes[0].id)
                ]
                storage.save(nodes: nodes, edges: edges)  // Save default graph
            } else {
                // Update nextLabel based on loaded nodes
                nextNodeLabel = (nodes.map { $0.label }.max() ?? 0) + 1
            }
        }
    
    // Creates a snapshot of the current state for undo/redo and saves.
    func snapshot() {
        let state = GraphState(nodes: nodes, edges: edges)
        undoStack.append(state)
        if undoStack.count > maxUndo {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        storage.save(nodes: nodes, edges: edges)
    }
    
    // Undoes the last action if possible, with haptic feedback.
    func undo() {
            guard !undoStack.isEmpty else {
                WKInterfaceDevice.current().play(.failure)
                return
            }
            let current = GraphState(nodes: nodes, edges: edges)
            redoStack.append(current)
            let previous = undoStack.removeLast()
            nodes = previous.nodes
            edges = previous.edges
            self.physicsEngine.resetSimulation()  // Ready for new simulation
            WKInterfaceDevice.current().play(.success)
            storage.save(nodes: nodes, edges: edges)
        }
        
        func redo() {
            guard !redoStack.isEmpty else {
                WKInterfaceDevice.current().play(.failure)
                return
            }
            let current = GraphState(nodes: nodes, edges: edges)
            undoStack.append(current)
            let next = redoStack.removeLast()
            nodes = next.nodes
            edges = next.edges
            self.physicsEngine.resetSimulation()  // Ready for new simulation
            WKInterfaceDevice.current().play(.success)
            storage.save(nodes: nodes, edges: edges)
        }
        
        func deleteNode(withID id: NodeID) {
            snapshot()
            nodes.removeAll { $0.id == id }
            edges.removeAll { $0.from == id || $0.to == id }
            self.physicsEngine.resetSimulation()
        }
        
        func deleteEdge(withID id: NodeID) {
            snapshot()
            edges.removeAll { $0.id == id }
            self.physicsEngine.resetSimulation()
        }
        
        func addNode(at position: CGPoint) {
            nodes.append(Node(label: nextNodeLabel, position: position))
            nextNodeLabel += 1
            self.physicsEngine.resetSimulation()
        }

        func startSimulation() {
            timer?.invalidate()
            self.physicsEngine.resetSimulation()
            timer = Timer.scheduledTimer(withTimeInterval: Constants.timeStep, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.objectWillChange.send()
                if !self.physicsEngine.simulationStep(nodes: &self.nodes, edges: self.edges) {
                    self.stopSimulation()
                }
            }
        }

        func stopSimulation() {
            timer?.invalidate()
            timer = nil
        }

        func boundingBox() -> CGRect {
            self.physicsEngine.boundingBox(nodes: nodes)
        }
    }



// File: GraphEditorWatch/Utilities/Utilities.swift
import Foundation

public extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        max(range.lowerBound, min(self, range.upperBound))
    }
}

public extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    
    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }
    
    static func += (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs + rhs
    }
    
    static func -= (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs - rhs
    }
    
    static func *= (lhs: inout CGPoint, rhs: CGFloat) {
        lhs = lhs * rhs
    }
    
    static func + (lhs: CGPoint, rhs: CGSize) -> CGPoint {
        CGPoint(x: lhs.x + rhs.width, y: lhs.y + rhs.height)
    }
    
    static func += (lhs: inout CGPoint, rhs: CGSize) {
        lhs = lhs + rhs
    }
    
    var magnitude: CGFloat {
        hypot(x, y)
    }
}

extension CGSize {
    static func / (lhs: CGSize, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width / rhs, height: lhs.height / rhs)
    }
    
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
    
    static func += (lhs: inout CGSize, rhs: CGSize) {
        lhs = lhs + rhs
    }
}

// Shared utility functions
func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    hypot(a.x - b.x, a.y - b.y)
}



// File: GraphEditorWatch/Views/GraphCanvasView.swift
//
//  GraphCanvasView.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//


// Views/GraphCanvasView.swift
import SwiftUI
import WatchKit
import GraphEditorShared

struct GraphCanvasView: View {
    let viewModel: GraphViewModel
    @Binding var zoomScale: CGFloat
    @Binding var offset: CGSize
    @Binding var draggedNode: Node?
    @Binding var dragOffset: CGPoint
    @Binding var potentialEdgeTarget: Node?
    @Binding var selectedNodeID: NodeID?
    let viewSize: CGSize
    @Binding var panStartOffset: CGSize?
    @Binding var showMenu: Bool
    let hitScreenRadius: CGFloat
    let tapThreshold: CGFloat
    let maxZoom: CGFloat
    let numZoomLevels: Int
    @Binding var crownPosition: Double
    let onUpdateZoomRanges: () -> Void
    let nodeModelRadius: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let transform = CGAffineTransform(translationX: offset.width, y: offset.height)
                .scaledBy(x: zoomScale, y: zoomScale)
            
            // Draw edges and their labels
            for edge in viewModel.model.edges {
                if let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                   let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                    let fromPos = (draggedNode?.id == fromNode.id ? CGPoint(x: fromNode.position.x + dragOffset.x, y: fromNode.position.y + dragOffset.y) : fromNode.position).applying(transform)
                    let toPos = (draggedNode?.id == toNode.id ? CGPoint(x: toNode.position.x + dragOffset.x, y: toNode.position.y + dragOffset.y) : toNode.position).applying(transform)
                    context.stroke(Path { path in
                        path.move(to: fromPos)
                        path.addLine(to: toPos)
                    }, with: .color(.blue), lineWidth: 2 * zoomScale)
                    
                    let midpoint = CGPoint(x: (fromPos.x + toPos.x) / 2, y: (fromPos.y + toPos.y) / 2)
                    let fromLabel = fromNode.label
                    let toLabel = toNode.label
                    let edgeLabel = "\(min(fromLabel, toLabel))-\(max(fromLabel, toLabel))"
                    let fontSize = UIFontMetrics.default.scaledValue(for: 12) * zoomScale
                    let text = Text(edgeLabel).foregroundColor(.white).font(.system(size: fontSize))
                    let resolvedText = context.resolve(text)
                    context.draw(resolvedText, at: midpoint, anchor: .center)
                }
            }
            
            // Draw potential new edge during drag
            if let dragged = draggedNode, let target = potentialEdgeTarget {
                let fromPos = CGPoint(x: dragged.position.x + dragOffset.x, y: dragged.position.y + dragOffset.y).applying(transform)
                let toPos = target.position.applying(transform)
                context.stroke(Path { path in
                    path.move(to: fromPos)
                    path.addLine(to: toPos)
                }, with: .color(.green), style: StrokeStyle(lineWidth: 2 * zoomScale, dash: [5 * zoomScale]))
            }
            
            // Draw nodes
            for node in viewModel.model.nodes {
                let pos = (draggedNode?.id == node.id ? CGPoint(x: node.position.x + dragOffset.x, y: node.position.y + dragOffset.y) : node.position).applying(transform)
                let scaledRadius = nodeModelRadius * zoomScale
                context.fill(Path(ellipseIn: CGRect(x: pos.x - scaledRadius, y: pos.y - scaledRadius, width: 2 * scaledRadius, height: 2 * scaledRadius)), with: .color(.red))
                if node.id == selectedNodeID {
                    let borderWidth = 4 * zoomScale
                    let borderRadius = scaledRadius + borderWidth / 2
                    context.stroke(Path(ellipseIn: CGRect(x: pos.x - borderRadius, y: pos.y - borderRadius, width: 2 * borderRadius, height: 2 * borderRadius)), with: .color(.white), lineWidth: borderWidth)
                }
                let fontSize = UIFontMetrics.default.scaledValue(for: 12) * zoomScale
                let text = Text("\(node.label)").foregroundColor(.white).font(.system(size: fontSize))
                let resolvedText = context.resolve(text)
                context.draw(resolvedText, at: pos, anchor: .center)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(graphDescription())
        .accessibilityHint("Double-tap for menu. Long press to delete selected.")
        .accessibilityChildren {
            ForEach(viewModel.model.nodes) { node in
                Text("Node \(node.label) at (\(Int(node.position.x)), \(Int(node.position.y)))")
                    .accessibilityAction(named: "Select") {
                        selectedNodeID = node.id
                        WKInterfaceDevice.current().play(.click)
                    }
            }
        }
        .modifier(GraphGesturesModifier(
            viewModel: viewModel,
            zoomScale: $zoomScale,
            offset: $offset,
            draggedNode: $draggedNode,
            dragOffset: $dragOffset,
            potentialEdgeTarget: $potentialEdgeTarget,
            selectedNodeID: $selectedNodeID,
            viewSize: viewSize,
            panStartOffset: $panStartOffset,
            showMenu: $showMenu,
            hitScreenRadius: hitScreenRadius,
            tapThreshold: tapThreshold,
            maxZoom: maxZoom,
            numZoomLevels: numZoomLevels,
            crownPosition: $crownPosition,
            onUpdateZoomRanges: onUpdateZoomRanges
        ))
    }
    
    private func graphDescription() -> String {
        var desc = "Graph with \(viewModel.model.nodes.count) nodes and \(viewModel.model.edges.count) edges."
        if let selectedID = selectedNodeID,
           let selectedNode = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
            let connections = viewModel.model.edges.filter { $0.from == selectedID || $0.to == selectedID }.count
            desc += " Node \(selectedNode.label) selected with \(connections) connections."
        } else {
            desc += " No node selected."
        }
        return desc
    }
}



// File: GraphEditorWatch/Views/ContentView.swift
//
//  ContentView.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//


// Views/ContentView.swift
import SwiftUI
import WatchKit
import GraphEditorShared

struct ContentView: View {
    @StateObject var viewModel = GraphViewModel(model: GraphModel())
    @State private var zoomScale: CGFloat = 1.0
    @State private var minZoom: CGFloat = 0.2
    @State private var maxZoom: CGFloat = 5.0
    @State private var crownPosition: Double = 2.5
    @State private var viewSize: CGSize = .zero
    @State private var offset: CGSize = .zero
    @State private var panStartOffset: CGSize?
    @State private var draggedNode: Node? = nil
    @State private var dragOffset: CGPoint = .zero
    @State private var potentialEdgeTarget: Node? = nil
    @State private var ignoreNextCrownChange: Bool = false
    @State private var selectedNodeID: NodeID? = nil
    @State private var showMenu = false
    @Environment(\.scenePhase) private var scenePhase
    
    let numZoomLevels = 6
    let nodeModelRadius: CGFloat = 10.0
    let hitScreenRadius: CGFloat = 30.0
    let tapThreshold: CGFloat = 10.0
    
    var body: some View {
        GeometryReader { geo in
            graphCanvasView(geo: geo)
        }
        .sheet(isPresented: $showMenu) {
            menuView
        }
        .focusable()
        .digitalCrownRotation($crownPosition, from: 0.0, through: Double(numZoomLevels - 1), sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: false)
        .onChange(of: crownPosition) { newValue in
            let oldValue = crownPosition  // Capture current before change
            if ignoreNextCrownChange {
                ignoreNextCrownChange = false
                updateZoomScale(oldCrown: oldValue, adjustOffset: false)
                return
            }
            
            let maxCrown = Double(numZoomLevels - 1)
            let clampedValue = max(0, min(newValue, maxCrown))
            if clampedValue != newValue {
                ignoreNextCrownChange = true
                crownPosition = clampedValue
                return
            }
            
            if floor(newValue) != floor(oldValue) {
                WKInterfaceDevice.current().play(.click)
            }
            updateZoomScale(oldCrown: oldValue, adjustOffset: true)
        }
        .ignoresSafeArea()
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                viewModel.model.startSimulation()
            } else {
                viewModel.model.stopSimulation()
            }
        }
        .onDisappear {
            viewModel.model.stopSimulation()
        }
    }
    
    private func graphCanvasView(geo: GeometryProxy) -> some View {
        GraphCanvasView(
            viewModel: viewModel,
            zoomScale: $zoomScale,
            offset: $offset,
            draggedNode: $draggedNode,
            dragOffset: $dragOffset,
            potentialEdgeTarget: $potentialEdgeTarget,
            selectedNodeID: $selectedNodeID,
            viewSize: geo.size,
            panStartOffset: $panStartOffset,
            showMenu: $showMenu,
            hitScreenRadius: hitScreenRadius,
            tapThreshold: tapThreshold,
            maxZoom: maxZoom,
            numZoomLevels: numZoomLevels,
            crownPosition: $crownPosition,
            onUpdateZoomRanges: updateZoomRanges,
            nodeModelRadius: nodeModelRadius
        )
        .onAppear {
            viewSize = geo.size
            updateZoomRanges()
            viewModel.model.startSimulation()
        }
    }
    
    private var menuView: some View {
        VStack {
            Button("New Graph") {
                viewModel.snapshot()
                viewModel.model.nodes = []
                viewModel.model.edges = []
                showMenu = false
                viewModel.model.startSimulation()
            }
            if let selected = selectedNodeID {
                Button("Delete Selected") {
                    viewModel.deleteNode(withID: selected)
                    selectedNodeID = nil
                    showMenu = false
                    viewModel.model.startSimulation()
                }
            }
            Button("Undo") {
                viewModel.undo()
                showMenu = false
                viewModel.model.startSimulation()
            }
            .disabled(!viewModel.canUndo)
            Button("Redo") {
                viewModel.redo()
                showMenu = false
                viewModel.model.startSimulation()
            }
            .disabled(!viewModel.canRedo)
        }
    }
    
    // Provides a textual description of the graph for accessibility.
    private func graphDescription() -> String {
        var desc = "Graph with \(viewModel.model.nodes.count) nodes and \(viewModel.model.edges.count) edges."
        if let selectedID = selectedNodeID,
           let selectedNode = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
            let connections = viewModel.model.edges.filter { $0.from == selectedID || $0.to == selectedID }.count
            desc += " Node \(selectedNode.label) selected with \(connections) connections."
        } else {
            desc += " No node selected."
        }
        return desc
    }
    
    // Updates the zoom range based on current graph and view size.
    private func updateZoomRanges() {
        guard viewSize != .zero else { return }
        
        if viewModel.model.nodes.isEmpty {
            minZoom = 0.5
            maxZoom = 2.0
            let midCrown = Double(numZoomLevels - 1) / 2.0
            if midCrown != crownPosition {
                ignoreNextCrownChange = true
                crownPosition = midCrown
            }
            return
        }
        
        let bbox = viewModel.model.boundingBox()
        let graphWidth = max(bbox.width, CGFloat(20)) + CGFloat(20)
        let graphHeight = max(bbox.height, CGFloat(20)) + CGFloat(20)
        let graphDia = max(graphWidth, graphHeight)
        let targetDia = min(viewSize.width, viewSize.height) / CGFloat(3)
        let newMinZoom = targetDia / graphDia
        
        let nodeDia = 2 * nodeModelRadius
        let targetNodeDia = min(viewSize.width, viewSize.height) * (CGFloat(2) / CGFloat(3))
        let newMaxZoom = targetNodeDia / nodeDia
        
        minZoom = newMinZoom
        maxZoom = max(newMaxZoom, newMinZoom * CGFloat(2))
        
        let currentScale = zoomScale
        var progress: CGFloat = 0.5
        if minZoom < currentScale && currentScale < maxZoom && minZoom > 0 && maxZoom > minZoom {
            progress = CGFloat(log(Double(currentScale / minZoom)) / log(Double(maxZoom / minZoom)))
        } else if currentScale <= minZoom {
            progress = 0.0
        } else {
            progress = 1.0
        }
        progress = progress.clamped(to: 0...1)  // Explicit clamp to [0,1]
        let newCrown = Double(progress * CGFloat(numZoomLevels - 1))
        if abs(newCrown - crownPosition) > 1e-6 {
            ignoreNextCrownChange = true
            crownPosition = newCrown
        }
    }
    
    // Updates the zoom scale and adjusts offset if needed.
    private func updateZoomScale(oldCrown: Double, adjustOffset: Bool) {
        let oldProgress = oldCrown / Double(numZoomLevels - 1)
        let oldScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), oldProgress))
        
        let newProgress = crownPosition / Double(numZoomLevels - 1)
        let newScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), newProgress))
        
        if adjustOffset && oldScale != newScale && viewSize != .zero {
            let focus = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
            let worldFocus = CGPoint(x: (focus.x - offset.width) / oldScale, y: (focus.y - offset.height) / oldScale)
            offset = CGSize(width: focus.x - worldFocus.x * newScale, height: focus.y - worldFocus.y * newScale)
        }
        
        withAnimation(.easeInOut) {
            zoomScale = newScale
        }
    }
}

#Preview {
    ContentView()
}



// File: GraphEditorWatch/Views/GraphGesturesModifier.swift
//
//  GraphGesturesModifier.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//


// Views/GraphGesturesModifier.swift
import SwiftUI
import WatchKit
import GraphEditorShared

struct GraphGesturesModifier: ViewModifier {
    let viewModel: GraphViewModel
    @Binding var zoomScale: CGFloat
    @Binding var offset: CGSize
    @Binding var draggedNode: Node?
    @Binding var dragOffset: CGPoint
    @Binding var potentialEdgeTarget: Node?
    @Binding var selectedNodeID: NodeID?
    let viewSize: CGSize
    @Binding var panStartOffset: CGSize?
    @Binding var showMenu: Bool
    let hitScreenRadius: CGFloat
    let tapThreshold: CGFloat
    let maxZoom: CGFloat
    let numZoomLevels: Int
    @Binding var crownPosition: Double
    let onUpdateZoomRanges: () -> Void
    
    func body(content: Content) -> some View {
        content
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let inverseTransform = CGAffineTransform(translationX: offset.width, y: offset.height)
                        .scaledBy(x: zoomScale, y: zoomScale)
                        .inverted()
                    if draggedNode == nil {
                        let touchPos = value.startLocation.applying(inverseTransform)
                        if let hitNode = viewModel.model.nodes.first(where: { hypot($0.position.x - touchPos.x, $0.position.y - touchPos.y) < hitScreenRadius / zoomScale }) {
                            draggedNode = hitNode
                        }
                    }
                    if let dragged = draggedNode {
                        dragOffset = CGPoint(x: value.translation.width / zoomScale, y: value.translation.height / zoomScale)
                        let currentPos = value.location.applying(inverseTransform)
                        potentialEdgeTarget = viewModel.model.nodes.first {
                            $0.id != dragged.id && hypot($0.position.x - currentPos.x, $0.position.y - currentPos.y) < hitScreenRadius / zoomScale
                        }
                    }
                }
                .onEnded { value in
                    let dragDistance = hypot(value.translation.width, value.translation.height)
                    if let node = draggedNode,
                       let index = viewModel.model.nodes.firstIndex(where: { $0.id == node.id }) {
                        viewModel.snapshot()
                        if dragDistance < tapThreshold {
                            if selectedNodeID == node.id {
                                selectedNodeID = nil
                            } else {
                                selectedNodeID = node.id
                                WKInterfaceDevice.current().play(.click)
                                if zoomScale < maxZoom * 0.8 {
                                    crownPosition = Double(numZoomLevels - 1)
                                }
                                let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
                                let worldPoint = node.position
                                offset = CGSize(width: viewCenter.x - worldPoint.x * zoomScale, height: viewCenter.y - worldPoint.y * zoomScale)
                            }
                        } else {
                            if let target = potentialEdgeTarget, target.id != node.id,
                               !viewModel.model.edges.contains(where: { ($0.from == node.id && $0.to == target.id) || ($0.from == target.id && $0.to == node.id) }) {
                                viewModel.model.edges.append(GraphEdge(from: node.id, to: target.id))
                                viewModel.model.startSimulation()
                            } else {
                                var updatedNode = viewModel.model.nodes[index]
                                updatedNode.position = CGPoint(x: updatedNode.position.x + dragOffset.x, y: updatedNode.position.y + dragOffset.y)
                                viewModel.model.nodes[index] = updatedNode
                                viewModel.model.startSimulation()
                            }
                        }
                    } else {
                        if dragDistance < tapThreshold {
                            selectedNodeID = nil
                            viewModel.snapshot()
                            let inverseTransform = CGAffineTransform(translationX: offset.width, y: offset.height)
                                .scaledBy(x: zoomScale, y: zoomScale)
                                .inverted()
                            let touchPos = value.location.applying(inverseTransform)
                            viewModel.model.addNode(at: touchPos)
                            viewModel.model.startSimulation()
                        }
                    }
                    onUpdateZoomRanges()
                    draggedNode = nil
                    dragOffset = .zero
                    potentialEdgeTarget = nil
                }
            )
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if draggedNode == nil {
                        if panStartOffset == nil {
                            panStartOffset = offset
                        }
                        offset = CGSize(width: panStartOffset!.width + value.translation.width, height: panStartOffset!.height + value.translation.height)
                    }
                }
                .onEnded { _ in
                    panStartOffset = nil
                }
            )
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5)
                        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                        .onEnded { value in
                            switch value {
                            case .second(true, let drag?):
                                let location = drag.location
                                let inverseTransform = CGAffineTransform(translationX: offset.width, y: offset.height)
                                    .scaledBy(x: zoomScale, y: zoomScale)
                                    .inverted()
                                let worldPos = location.applying(inverseTransform)
                                
                                // Check for node hit (unchanged)
                                if let hitNode = viewModel.model.nodes.first(where: { hypot($0.position.x - worldPos.x, $0.position.y - worldPos.y) < hitScreenRadius / zoomScale }) {
                                    viewModel.deleteNode(withID: hitNode.id)
                                    WKInterfaceDevice.current().play(.success)
                                    viewModel.model.startSimulation()
                                    return
                                }
                                
                                // Check for edge hit (now using point-to-line distance)
                                for edge in viewModel.model.edges {
                                    if let from = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                                       let to = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                                        if pointToLineDistance(point: worldPos, from: from.position, to: to.position) < hitScreenRadius / zoomScale {
                                            viewModel.deleteEdge(withID: edge.id)
                                            WKInterfaceDevice.current().play(.success)
                                            viewModel.model.startSimulation()
                                            return
                                        }
                                    }
                                }
                            default:
                                break
                            }
                        }
                    )
            .simultaneousGesture(TapGesture(count: 2)
                .onEnded {
                    showMenu = true
                }
            )
    }
    
    // New helper function for point-to-line distance
    private func pointToLineDistance(point: CGPoint, from: CGPoint, to: CGPoint) -> CGFloat {
        let lineVec = to - from
        let pointVec = point - from
        let lineLen = lineVec.magnitude
        if lineLen == 0 { return distance(point, from) }
        let t = max(0, min(1, (pointVec.x * lineVec.x + pointVec.y * lineVec.y) / (lineLen * lineLen)))
        let projection = from + lineVec * t
        return distance(point, projection)
    }
}



// File: GraphEditorWatch/GraphEditorWatch.swift
//
//  GraphEditorWatch.swift
//  GraphEditorWatch Watch App
//
//  Created by handcart on 8/1/25.
//

import SwiftUI

@main
struct GraphEditorWatch: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}



// File: GraphEditorWatchTests/GraphEditorWatchTests.swift
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
    
    @Test func testSimulationStep() {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage)
        var nodes = model.nodes
        let edges = model.edges
        // Assuming PhysicsEngine is accessible; if private, expose or mock
        let engine = PhysicsEngine()
        let isRunning = engine.simulationStep(nodes: &nodes, edges: edges)
        #expect(isRunning, "Simulation should run if not stable")
    }
}



