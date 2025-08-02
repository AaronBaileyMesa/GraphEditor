// File: Tests/GraphEditor Watch AppTests/GraphModelTests.swift
//
//  GraphModelTests.swift
//  GraphEditor
//
//  Created by handcart on 7/31/25.
//


import XCTest
@testable import GraphEditor_Watch_App 

class GraphModelTests: XCTestCase {
    func testSnapshotAndUndo() {
        let model = GraphModel()
        let initialNodes = model.nodes
        model.snapshot()
        model.nodes.append(Node(position: .zero))
        model.undo()
        XCTAssertEqual(model.nodes.count, initialNodes.count)
    }
    
    func testDeleteNode() {
        let model = GraphModel()
        let nodeID = model.nodes[0].id
        let initialEdgeCount = model.edges.count
        model.deleteNode(withID: nodeID)
        XCTAssertNil(model.nodes.first { $0.id == nodeID })
        XCTAssertLessThan(model.edges.count, initialEdgeCount)
    }
    
    func testSaveLoad() {
        let model = GraphModel()
        model.save()
        let newModel = GraphModel()
        newModel.load()
        XCTAssertEqual(model.nodes.count, newModel.nodes.count)
    }
}



// File: Tests/GraphEditor Watch AppTests/GraphEditor_Watch_AppTests.swift
//
//  GraphEditor_Watch_AppTests.swift
//  GraphEditor Watch AppTests
//
//  Created by handcart on 7/31/25.
//

import Testing

struct GraphEditor_Watch_AppTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}



// File: GraphEditorShared/Tests/GraphEditorSharedTests/GraphEditorSharedTests.swift
//
//  GraphEditorSharedTests.swift
//  GraphEditorSharedTests
//
//  Created by handcart on 8/1/25.
//

import Testing
@testable import GraphEditorShared

struct GraphEditorSharedTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
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
            name: "GraphEditorSharedTßests",
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



// File: GraphEditorWatch/GraphEditorWatchApp.swift
//
//  GraphEditorWatchAppApp.swift
//  GraphEditorWatchApp Watch App
//
//  Created by handcart on 8/1/25.
//

import SwiftUI

@main
struct GraphEditorWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
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

class PhysicsEngine {
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
//
//  PersistenceManager.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//


// Models/PersistenceManager.swift
//
//  PersistenceManager.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//

import Foundation
import GraphEditorShared

class PersistenceManager: GraphStorage {
    private let nodesFileName = "graphNodes.json"
    private let edgesFileName = "graphEdges.json"
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func save(nodes: [Node], edges: [GraphEdge]) {
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
    
    func load() -> (nodes: [Node], edges: [GraphEdge]) {
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

class GraphModel: ObservableObject {
    @Published var nodes: [Node] = []
    @Published var edges: [GraphEdge] = []
    
    private var undoStack: [GraphState] = []
    private var redoStack: [GraphState] = []
    private let maxUndo = 10
    private var nextNodeLabel = 1  // Auto-increment for node labels
    
    private let storage: GraphStorage = PersistenceManager()
    private let physicsEngine = PhysicsEngine()
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
    init() {
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
        physicsEngine.resetSimulation()  // Ready for new simulation
        WKInterfaceDevice.current().play(.success)
        storage.save(nodes: nodes, edges: edges)
    }
    
    // Redoes the last undone action if possible, with haptic feedback.
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
        physicsEngine.resetSimulation()  // Ready for new simulation
        WKInterfaceDevice.current().play(.success)
        storage.save(nodes: nodes, edges: edges)
    }
    
    // Deletes a node and its connected edges, snapshotting first.
    func deleteNode(withID id: NodeID) {
        snapshot()
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.to == id }
        physicsEngine.resetSimulation()
    }
    
    // Deletes an edge, snapshotting first.
    func deleteEdge(withID id: NodeID) {
        snapshot()
        edges.removeAll { $0.id == id }
        physicsEngine.resetSimulation()
    }
    
    // Adds a new node with auto-incremented label.
    func addNode(at position: CGPoint) {
        nodes.append(Node(label: nextNodeLabel, position: position))
        nextNodeLabel += 1
        physicsEngine.resetSimulation()
    }

    func startSimulation() {
        timer?.invalidate()
        physicsEngine.resetSimulation()
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
        physicsEngine.boundingBox(nodes: nodes)
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



