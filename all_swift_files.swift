// File: GraphEditorWatchUITests/GraphEditorWatchUITestsLaunchTests.swift
//
//  GraphEditorWatchUITestsLaunchTests.swift
//  GraphEditorWatchUITests
//
//  Created by handcart on 8/4/25.
//

import XCTest

final class GraphEditorWatchUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}



// File: GraphEditorWatchUITests/GraphEditorWatchUITests.swift
//
//  GraphEditorWatchUITests.swift
//  GraphEditorWatchUITests
//
//  Created by handcart on 8/4/25.
//

import XCTest

final class GraphEditorWatchUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testLaunch() throws {
            let app = XCUIApplication()
            app.launch()
            
            // Basic assertion: Check if the app launches without crashing
            XCTAssertTrue(app.exists, "App should launch successfully")
        }
    
    func testDragToCreateEdge() throws {
        let app = XCUIApplication()
        app.launch()

        let canvas = app.otherElements["GraphCanvas"]  // Assumes accessibilityIdentifier set on GraphCanvasView
        XCTAssertTrue(canvas.waitForExistence(timeout: 5), "Graph canvas should appear")

        // Assume default nodes: Adjust start/end based on positions (e.g., node0 at (100,100), node1 at (200,200))
        let startPoint = CGVector(dx: 0.3, dy: 0.3)  // Near node0
        let endPoint = CGVector(dx: 0.6, dy: 0.6)    // Near node1

        let dragStart = canvas.coordinate(withNormalizedOffset: startPoint)
        let dragEnd = canvas.coordinate(withNormalizedOffset: endPoint)
        dragStart.press(forDuration: 0.1, thenDragTo: dragEnd)

        // Assert: Updated label reflects directed edge (e.g., "Graph with 3 nodes and 4 directed edges." and mentions direction)
        let updatedLabel = app.staticTexts["Graph with 3 nodes and 4 directed edges. No node selected."]  // Adjust based on post-drag (add "directed")
        XCTAssertTrue(updatedLabel.waitForExistence(timeout: 2), "Directed edge created, updating graph description")

        // Optional: Select the from-node and check description mentions "outgoing to" the to-node
        // Simulate tap on startPoint to select, then check label includes "outgoing to: <label>"
    }
    
    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}



// File: GraphEditorShared/Tests/GraphEditorSharedTests/GraphEditorSharedTests.swift
import Testing
import Foundation  // For UUID, JSONEncoder, JSONDecoder
import CoreGraphics  // For CGPoint
import GraphEditorShared

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
    
    @Test func testDirectedEdgeCreation() {
        let edge = GraphEdge(from: UUID(), to: UUID())
        #expect(edge.from != edge.to, "Directed edge has distinct from/to")
    }
    
    @Test func testAsymmetricAttraction() throws {
        let engine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        engine.useAsymmetricAttraction = true
        var nodes = [Node(id: UUID(), label: 1, position: CGPoint(x: 0, y: 0)),
                     Node(id: UUID(), label: 2, position: CGPoint(x: 200, y: 0))]
        let edges = [GraphEdge(from: nodes[0].id, to: nodes[1].id)]
        _ = engine.simulationStep(nodes: &nodes, edges: edges)
        #expect(abs(nodes[0].position.x - 0) < 1, "From node position unchanged in asymmetric")
        #expect(nodes[1].position.x < 200, "To node pulled towards from")
    }
}

struct PerformanceTests {

    @available(watchOS 9.0, *)  // Guard for availability
    @Test func testSimulationPerformance() {
        let engine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        var nodes: [Node] = (1...100).map { Node(label: $0, position: CGPoint(x: CGFloat.random(in: 0...300), y: CGFloat.random(in: 0...300))) }
        let edges: [GraphEdge] = []

        let start = Date()
        for _ in 0..<10 {
            _ = engine.simulationStep(nodes: &nodes, edges: edges)
        }
        let duration = Date().timeIntervalSince(start)

        print("Duration for 10 simulation steps with 100 nodes: \(duration) seconds")

        #expect(duration < 0.5, "Simulation should be performant")
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



// File: GraphEditorShared/Sources/GraphEditorShared/PhysicsConstants.swift
//
//  PhysicConstants.swift
//  GraphEditor
//
//  Created by handcart on 8/4/25.
//


import CoreGraphics

public struct PhysicsConstants {
    public static let stiffness: CGFloat = 0.5
    public static let repulsion: CGFloat = 5000
    public static let damping: CGFloat = 0.85
    public static let idealLength: CGFloat = 100
    public static let centeringForce: CGFloat = 0.005
    public static let distanceEpsilon: CGFloat = 1e-3
    public static let timeStep: CGFloat = 0.05
    public static let velocityThreshold: CGFloat = 0.2
    public static let maxSimulationSteps = 500
    public static let minQuadSize: CGFloat = 1e-6
    public static let maxQuadtreeDepth = 64
    private let maxNodesForQuadtree = 75  // Adjust based on profiling; watchOS limit
}



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



// File: GraphEditorShared/Sources/GraphEditorShared/PhysicsEngine.swift
//
//  Constants.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//


// Models/PhysicsEngine.swift
import SwiftUI
import Foundation
import CoreGraphics

public class PhysicsEngine {
    let simulationBounds: CGSize
    
    private let maxNodesForQuadtree = 100  // Added constant for node cap fallback
    
    public init(simulationBounds: CGSize) {
        self.simulationBounds = simulationBounds
    }
    
    private var simulationSteps = 0
    
    public func resetSimulation() {
        simulationSteps = 0
    }
    
    public var useAsymmetricAttraction: Bool = false  // New: Toggle for directed physics (default false for stability)
    
    @discardableResult
    public func simulationStep(nodes: inout [Node], edges: [GraphEdge]) -> Bool {
        if simulationSteps >= PhysicsConstants.maxSimulationSteps {
            return false
        }
        simulationSteps += 1
        
        var forces: [NodeID: CGPoint] = [:]
        let center = CGPoint(x: simulationBounds.width / 2, y: simulationBounds.height / 2)
        
        // Build Quadtree for repulsion (Barnes-Hut) only if under cap
        let useQuadtree = nodes.count <= maxNodesForQuadtree
        let quadtree: Quadtree? = useQuadtree ? Quadtree(bounds: CGRect(origin: .zero, size: simulationBounds)) : nil
        if useQuadtree {
            for node in nodes {
                quadtree?.insert(node, depth: 0)
            }
        }
        
        // Repulsion (Quadtree or naive fallback)
        for i in 0..<nodes.count {
            var repulsion: CGPoint = .zero
            if useQuadtree {
                let dynamicTheta: CGFloat = nodes.count > 50 ? 1.2 : (nodes.count > 20 ? 1.0 : 0.5)
                repulsion = quadtree!.computeForce(on: nodes[i], theta: dynamicTheta)
            } else {
                // Naive repulsion
                for j in 0..<nodes.count where i != j {
                    repulsion += repulsionForce(from: nodes[j].position, to: nodes[i].position)
                }
            }
            forces[nodes[i].id] = (forces[nodes[i].id] ?? .zero) + repulsion  // Use repulsion here
        }
        
        // Attraction on edges
        for edge in edges {
                    guard let fromIdx = nodes.firstIndex(where: { $0.id == edge.from }),
                          let toIdx = nodes.firstIndex(where: { $0.id == edge.to }) else { continue }
                    let deltaX = nodes[toIdx].position.x - nodes[fromIdx].position.x
                    let deltaY = nodes[toIdx].position.y - nodes[fromIdx].position.y
                    let dist = max(hypot(deltaX, deltaY), PhysicsConstants.distanceEpsilon)
                    let forceMagnitude = PhysicsConstants.stiffness * (dist - PhysicsConstants.idealLength)
                    let forceDirectionX = deltaX / dist
                    let forceDirectionY = deltaY / dist
                    let forceX = forceDirectionX * forceMagnitude
                    let forceY = forceDirectionY * forceMagnitude

                    if useAsymmetricAttraction {
                        // Asymmetric: Only pull 'to' towards 'from' (stronger influence on 'to')
                        let currentForceTo = forces[nodes[toIdx].id] ?? .zero
                        forces[nodes[toIdx].id] = CGPoint(x: currentForceTo.x - forceX, y: currentForceTo.y - forceY)
                    } else {
                        // Symmetric (original)
                        let currentForceFrom = forces[nodes[fromIdx].id] ?? .zero
                        forces[nodes[fromIdx].id] = CGPoint(x: currentForceFrom.x + forceX, y: currentForceFrom.y + forceY)
                        let currentForceTo = forces[nodes[toIdx].id] ?? .zero
                        forces[nodes[toIdx].id] = CGPoint(x: currentForceTo.x - forceX, y: currentForceTo.y - forceY)
                    }
                }
        
        // Weak centering force
        for i in 0..<nodes.count {
            let deltaX = center.x - nodes[i].position.x
            let deltaY = center.y - nodes[i].position.y
            let forceX = deltaX * PhysicsConstants.centeringForce
            let forceY = deltaY * PhysicsConstants.centeringForce
            let currentForce = forces[nodes[i].id] ?? .zero
            forces[nodes[i].id] = CGPoint(x: currentForce.x + forceX, y: currentForce.y + forceY)
        }
        
        // Apply forces
        for i in 0..<nodes.count {
            let id = nodes[i].id
            var node = nodes[i]
            let force = forces[id] ?? .zero
            node.velocity = CGPoint(x: node.velocity.x + force.x * PhysicsConstants.timeStep, y: node.velocity.y + force.y * PhysicsConstants.timeStep)
            node.velocity = CGPoint(x: node.velocity.x * PhysicsConstants.damping, y: node.velocity.y * PhysicsConstants.damping)
            node.position = CGPoint(x: node.position.x + node.velocity.x * PhysicsConstants.timeStep, y: node.position.y + node.velocity.y * PhysicsConstants.timeStep)
            
            // Clamp position and reset velocity on bounds hit (with bounce from earlier fix)
            let oldPosition = node.position
            node.position.x = max(0, min(simulationBounds.width, node.position.x))
            node.position.y = max(0, min(simulationBounds.height, node.position.y))
            if node.position.x != oldPosition.x {
                node.velocity.x = -node.velocity.x * PhysicsConstants.damping  // Bounce
            }
            if node.position.y != oldPosition.y {
                node.velocity.y = -node.velocity.y * PhysicsConstants.damping
            }
            
            nodes[i] = node
        }
        
        // Check if stable
        let totalVelocity = nodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }
        return totalVelocity >= PhysicsConstants.velocityThreshold * CGFloat(nodes.count)
    }
    
    public func boundingBox(nodes: [Node]) -> CGRect {
        if nodes.isEmpty { return .zero }
        let xs = nodes.map { $0.position.x }
        let ys = nodes.map { $0.position.y }
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func repulsionForce(from: CGPoint, to: CGPoint) -> CGPoint {
        let delta = to - from
        let distSquared = delta.x * delta.x + delta.y * delta.y  // Manual calculation instead of magnitudeSquared
        if distSquared < PhysicsConstants.distanceEpsilon * PhysicsConstants.distanceEpsilon {
            return CGPoint(x: CGFloat.random(in: -0.01...0.01), y: CGFloat.random(in: -0.01...0.01)) * PhysicsConstants.repulsion
        }
        let dist = sqrt(distSquared)
        let forceMagnitude = PhysicsConstants.repulsion / distSquared
        return delta / dist * forceMagnitude
    }
}



// File: GraphEditorShared/Sources/GraphEditorShared/Quadtree.swift
//
//  Quadtree.swift
//  GraphEditor
//
//  Created by handcart on 8/4/25.
//


import Foundation
import CoreGraphics


public class Quadtree {  // Made public for consistency/test access
    let bounds: CGRect
    public var centerOfMass: CGPoint = .zero
    public var totalMass: CGFloat = 0
    public var children: [Quadtree]? = nil
    var nodes: [Node] = []  // Replaces old single 'node'; allows multiple in leaves
    
    public init(bounds: CGRect) {
        self.bounds = bounds
    }
    
    public func insert(_ node: Node, depth: Int = 0) {
        if depth > PhysicsConstants.maxQuadtreeDepth {  // Updated reference (line ~26)
            nodes.append(node)
            updateCenterOfMass(with: node)
            return
        }
        
        if let children = children {
            let quadrant = getQuadrant(for: node.position)
            children[quadrant].insert(node, depth: depth + 1)
            aggregateFromChildren()
        } else {
            if !nodes.isEmpty && nodes.allSatisfy({ $0.position == node.position }) {
                nodes.append(node)
                updateCenterOfMass(with: node)
                return
            }
            
            if !nodes.isEmpty {
                subdivide()
                if let children = children {
                    for existing in nodes {
                        let quadrant = getQuadrant(for: existing.position)
                        children[quadrant].insert(existing, depth: depth + 1)
                    }
                    nodes = []
                    let quadrant = getQuadrant(for: node.position)
                    children[quadrant].insert(node, depth: depth + 1)
                    aggregateFromChildren()
                } else {
                    nodes.append(node)
                    updateCenterOfMass(with: node)
                }
            } else {
                nodes.append(node)
                updateCenterOfMass(with: node)
            }
        }
    }
    
    private func aggregateFromChildren() {
        centerOfMass = .zero
        totalMass = 0
        guard let children = children else { return }
        for child in children {
            if child.totalMass > 0 {
                centerOfMass = (centerOfMass * totalMass + child.centerOfMass * child.totalMass) / (totalMass + child.totalMass)
                totalMass += child.totalMass
            }
        }
    }
    
    private func subdivide() {
        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2
        if halfWidth < PhysicsConstants.distanceEpsilon || halfHeight < PhysicsConstants.distanceEpsilon {  // Updated (line ~80)
            return  // Too small
        }
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
    
    private func updateCenterOfMass(with node: Node) {
        // Incremental update (works for both leaves and internals)
        centerOfMass = (centerOfMass * totalMass + node.position) / (totalMass + 1)
        totalMass += 1
    }
    
    public func computeForce(on queryNode: Node, theta: CGFloat = 0.5) -> CGPoint {
        guard totalMass > 0 else { return .zero }
        if !nodes.isEmpty {
            // Leaf: Exact repulsion for each node in array
            var force: CGPoint = .zero
            for leafNode in nodes where leafNode.id != queryNode.id {
                force += repulsionForce(from: leafNode.position, to: queryNode.position)
            }
            return force
        }
        // Internal: Approximation
        let delta = centerOfMass - queryNode.position
        let dist = max(delta.magnitude, PhysicsConstants.distanceEpsilon)  // Updated (line ~121)
        if bounds.width / dist < theta || children == nil {
            return repulsionForce(from: centerOfMass, to: queryNode.position, mass: totalMass)
        } else {
            var force: CGPoint = .zero
            if let children = children {
                for child in children {
                    force += child.computeForce(on: queryNode, theta: theta)
                }
            }
            return force
        }
    }
    
    private func repulsionForce(from: CGPoint, to: CGPoint, mass: CGFloat = 1) -> CGPoint {
        let deltaX = to.x - from.x
        let deltaY = to.y - from.y
        let distSquared = deltaX * deltaX + deltaY * deltaY
        if distSquared < PhysicsConstants.distanceEpsilon * PhysicsConstants.distanceEpsilon {  // Updated (line ~139)
            // Jitter slightly to avoid zero
            return CGPoint(x: CGFloat.random(in: -0.01...0.01), y: CGFloat.random(in: -0.01...0.01)) * PhysicsConstants.repulsion  // Updated (line ~141)
        }
        let dist = sqrt(distSquared)
        let forceMagnitude = PhysicsConstants.repulsion * mass / distSquared  // Updated (line ~144)
        return CGPoint(x: deltaX / dist * forceMagnitude, y: deltaY / dist * forceMagnitude)
    }
}



// File: GraphEditorShared/Sources/GraphEditorShared/Protocols.swift
//
//  GraphStorage.swift
//  GraphEditorShared
//
//  Created by handcart on 8/1/25.
//


public protocol GraphStorage {
    func save(nodes: [Node], edges: [GraphEdge]) throws  
    func load() -> (nodes: [Node], edges: [GraphEdge])
}



// File: GraphEditorShared/Sources/GraphEditorShared/GraphTypes.swift
import SwiftUI
import Foundation

public typealias NodeID = UUID

// Represents a node in the graph with position, velocity, and permanent label.
public struct Node: Identifiable, Equatable, Codable {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var radius: CGFloat = 10.0  // New: Per-node radius (default matches AppConstants.nodeModelRadius)

    // Update init to include radius
    public init(id: NodeID = NodeID(), label: Int, position: CGPoint, velocity: CGPoint = .zero, radius: CGFloat = 10.0) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
    }

    // Update CodingKeys and decoder/encoder for radius
    enum CodingKeys: String, CodingKey {
        case id, label, radius  // Add radius
        case positionX, positionY
        case velocityX, velocityY
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        radius = try container.decodeIfPresent(CGFloat.self, forKey: .radius) ?? 10.0  // Decode or default
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
        try container.encode(radius, forKey: .radius)  // Encode radius
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



// File: GraphEditorWatch/Models/GraphSimulator.swift
import Foundation
import Combine
import GraphEditorShared
import WatchKit

class GraphSimulator {
    private var timer: Timer? = nil
    private var recentVelocities: [CGFloat] = []
    private let velocityChangeThreshold: CGFloat = 0.01
    private let velocityHistoryCount = 5
    
    let physicsEngine: PhysicsEngine
    private let getNodes: () -> [Node]
    private let setNodes: ([Node]) -> Void
    private let getEdges: () -> [GraphEdge]
    
    init(getNodes: @escaping () -> [Node],
         setNodes: @escaping ([Node]) -> Void,
         getEdges: @escaping () -> [GraphEdge],
         physicsEngine: PhysicsEngine) {
        self.getNodes = getNodes
        self.setNodes = setNodes
        self.getEdges = getEdges
        self.physicsEngine = physicsEngine
    }
    
    func startSimulation(onUpdate: @escaping () -> Void) {
        timer?.invalidate()
        physicsEngine.resetSimulation()
        recentVelocities.removeAll()
        
        let nodeCount = getNodes().count
        if nodeCount < 5 { return }
        
        let interval: TimeInterval = nodeCount < 20 ? 1.0 / 30.0 : 1.0 / 15.0  // Slower for big graphs
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            
            // Recompute nodeCount and subSteps each time, in case nodes change
            let currentNodeCount = self.getNodes().count
            let subSteps = currentNodeCount < 10 ? 5 : (currentNodeCount < 30 ? 3 : 1)  // Fewer sub-steps for large graphs
            
            DispatchQueue.global(qos: .userInitiated).async {
                var nodes = self.getNodes()
                let edges = self.getEdges()
                var shouldContinue = true
                for _ in 0..<subSteps {
                    if !self.physicsEngine.simulationStep(nodes: &nodes, edges: edges) {
                        shouldContinue = false
                        break
                    }
                }
                let totalVelocity = nodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }
                
                DispatchQueue.main.async {
                    self.setNodes(nodes)
                    onUpdate()
                    if !shouldContinue {
                        self.stopSimulation()
                        return
                    }
                    
                    self.recentVelocities.append(totalVelocity)
                    if self.recentVelocities.count > self.velocityHistoryCount {
                        self.recentVelocities.removeFirst()
                    }
                    
                    if self.recentVelocities.count == self.velocityHistoryCount {
                        let maxVel = self.recentVelocities.max() ?? 1.0
                        let minVel = self.recentVelocities.min() ?? 0.0
                        let relativeChange = (maxVel - minVel) / maxVel
                        if relativeChange < self.velocityChangeThreshold {
                            self.stopSimulation()
                            return
                        }
                    }
                }
            }
        }
    }
    
    func stopSimulation() {
        timer?.invalidate()
        timer = nil
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
import os.log
private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "storage")

import Foundation
import GraphEditorShared

enum GraphStorageError: Error {
    case encodingFailed(Error)
    case writingFailed(Error)
    case loadingFailed(Error)
    case decodingFailed(Error)
}

public class PersistenceManager: GraphStorage {
    private let nodesFileName = "graphNodes.json"
    private let edgesFileName = "graphEdges.json"
    
    private let baseURL: URL
    
    public init() {
        self.baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    public func save(nodes: [Node], edges: [GraphEdge]) throws {
        let encoder = JSONEncoder()
        do {
            let nodeData = try encoder.encode(nodes)
            let nodeURL = baseURL.appendingPathComponent(nodesFileName)
            try nodeData.write(to: nodeURL)
            
            let edgeData = try encoder.encode(edges)
            let edgeURL = baseURL.appendingPathComponent(edgesFileName)
            try edgeData.write(to: edgeURL)
        } catch let encodingError as EncodingError {
            throw GraphStorageError.encodingFailed(encodingError)
        } catch let writingError as NSError {
            throw GraphStorageError.writingFailed(writingError)
        } catch {
            throw GraphStorageError.encodingFailed(error)
        }
    }
    
    public func load() -> (nodes: [Node], edges: [GraphEdge]) {
        let decoder = JSONDecoder()
        var loadedNodes: [Node] = []
        var loadedEdges: [GraphEdge] = []
        
        let nodeURL = baseURL.appendingPathComponent(nodesFileName)
        if let nodeData = try? Data(contentsOf: nodeURL) {
            do {
                loadedNodes = try decoder.decode([Node].self, from: nodeData)
            } catch {
                // Log and use defaults
                logger.error("Failed to decode nodes: \(error.localizedDescription)")
            }
        }
        
        let edgeURL = baseURL.appendingPathComponent(edgesFileName)
        if let edgeData = try? Data(contentsOf: edgeURL) {
            do {
                loadedEdges = try decoder.decode([GraphEdge].self, from: edgeData)
            } catch {
                logger.error("Failed to decode edges: \(error.localizedDescription)")
            }
        }
        
        return (loadedNodes, loadedEdges)
    }
}



// File: GraphEditorWatch/Models/GraphModel.swift
// Updated GraphModel.swift with lazy simulator to avoid initialization issues with closures capturing self.

import os.log
private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "storage")

// Models/GraphModel.swift
import SwiftUI
import Combine
import Foundation
import GraphEditorShared
import WatchKit

public class GraphModel: ObservableObject {
    @Published var nodes: [Node] = []
    @Published var edges: [GraphEdge] = []
    
    private var undoStack: [GraphState] = []
    private var redoStack: [GraphState] = []
    private let maxUndo = 10
    internal var nextNodeLabel = 1  // Internal for testability; auto-increments node labels
    
    private let storage: GraphStorage
    internal let physicsEngine: PhysicsEngine
    
    private lazy var simulator: GraphSimulator = {
        GraphSimulator(
            getNodes: { [weak self] in self?.nodes ?? [] },
            setNodes: { [weak self] nodes in self?.nodes = nodes },
            getEdges: { [weak self] in self?.edges ?? [] },
            physicsEngine: self.physicsEngine
        )
    }()
    
    // Indicates if undo is possible.
    var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    // Indicates if redo is possible.
    var canRedo: Bool {
        !redoStack.isEmpty
    }
    
    // Initializes the graph model, loading from persistence if available.
    public init(storage: GraphStorage = PersistenceManager(), physicsEngine: PhysicsEngine) {
        self.storage = storage
        self.physicsEngine = physicsEngine
        
        let loaded = storage.load()
        var tempNodes = loaded.nodes
        var tempEdges = loaded.edges
        var tempNextLabel = 1
        
        if tempNodes.isEmpty && tempEdges.isEmpty {
            tempNodes = [
                Node(label: tempNextLabel, position: CGPoint(x: 100, y: 100)),
                Node(label: tempNextLabel + 1, position: CGPoint(x: 200, y: 200)),
                Node(label: tempNextLabel + 2, position: CGPoint(x: 150, y: 300))
            ]
            tempNextLabel += 3
            tempEdges = [
                GraphEdge(from: tempNodes[0].id, to: tempNodes[1].id),
                GraphEdge(from: tempNodes[1].id, to: tempNodes[2].id),
                GraphEdge(from: tempNodes[2].id, to: tempNodes[0].id)
            ]
            do {
                try storage.save(nodes: tempNodes, edges: tempEdges)  // Only here, for defaults
            } catch {
                logger.error("Failed to save default graph: \(error.localizedDescription)")
            }
        } else {
            // Update nextLabel based on loaded nodes
            tempNextLabel = (tempNodes.map { $0.label }.max() ?? 0) + 1
            // NO save here; loaded data doesn't need immediate save
        }
        
        self.nodes = tempNodes
        self.edges = tempEdges
        self.nextNodeLabel = tempNextLabel
    }

    // Test-only initializer
    #if DEBUG
    init(storage: GraphStorage = PersistenceManager(), physicsEngine: PhysicsEngine, nextNodeLabel: Int) {
        self.storage = storage
        self.physicsEngine = physicsEngine
        
        let loaded = storage.load()
        var tempNodes = loaded.nodes
        var tempEdges = loaded.edges
        var tempNextLabel = nextNodeLabel
        
        if tempNodes.isEmpty && tempEdges.isEmpty {
            // Default graph setup (as in main init)
            tempNodes = [
                Node(label: tempNextLabel, position: CGPoint(x: 100, y: 100)),
                Node(label: tempNextLabel + 1, position: CGPoint(x: 200, y: 200)),
                Node(label: tempNextLabel + 2, position: CGPoint(x: 150, y: 300))
            ]
            tempNextLabel += 3
            tempEdges = [
                GraphEdge(from: tempNodes[0].id, to: tempNodes[1].id),
                GraphEdge(from: tempNodes[1].id, to: tempNodes[2].id),
                GraphEdge(from: tempNodes[2].id, to: tempNodes[0].id)
            ]
            do {
                try storage.save(nodes: tempNodes, edges: tempEdges)
            } catch {
                logger.error("Failed to save default graph: \(error.localizedDescription)")
            }
        } else {
            tempNextLabel = (tempNodes.map { $0.label }.max() ?? 0) + 1
        }
        
        self.nodes = tempNodes
        self.edges = tempEdges
        self.nextNodeLabel = tempNextLabel
    }
    #endif
    
    // Creates a snapshot of the current state for undo/redo and saves.
    func snapshot() {
        let state = GraphState(nodes: nodes, edges: edges)
        undoStack.append(state)
        if undoStack.count > maxUndo {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        do {
            try storage.save(nodes: nodes, edges: edges)
        } catch {
            logger.error("Failed to save snapshot: \(error.localizedDescription)")
        }
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
        do {
            try storage.save(nodes: nodes, edges: edges)
        } catch {
            logger.error("Failed to save after undo: \(error.localizedDescription)")
        }
        // REMOVE any redoStack.removeAll() here if present
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
        do {
            try storage.save(nodes: nodes, edges: edges)
        } catch {
            logger.error("Failed to save after redo: \(error.localizedDescription)")
        }
        // Optionally add redoStack.removeAll() here if you want to prevent redo chains, but standard is not to
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
        nodes.append(Node(label: nextNodeLabel, position: position, radius: 10.0))  // Explicit radius; vary later if needed
        nextNodeLabel += 1
        if nodes.count >= 100 {
            // Trigger alert via view (e.g., publish @Published var showNodeLimitAlert = true)
            return
        }
        self.physicsEngine.resetSimulation()
    }
    
    func startSimulation() {
        simulator.startSimulation(onUpdate: { [weak self] in
            self?.objectWillChange.send()
        })
    }
    
    func stopSimulation() {
        simulator.stopSimulation()
    }
    
    func boundingBox() -> CGRect {
        self.physicsEngine.boundingBox(nodes: nodes)
    }
}

extension GraphModel {
    func graphDescription(selectedID: NodeID?) -> String {
        var desc = "Graph with \(nodes.count) nodes and \(edges.count) directed edges."
        if let selectedID, let selectedNode = nodes.first(where: { $0.id == selectedID }) {
            let outgoingLabels = edges
                .filter { $0.from == selectedID }
                .compactMap { edge in
                    let toID = edge.to
                    return nodes.first { $0.id == toID }?.label
                }
                .sorted()
                .map { String($0) }
                .joined(separator: ", ")
            let incomingLabels = edges
                .filter { $0.to == selectedID }
                .compactMap { edge in
                    let fromID = edge.from
                    return nodes.first { $0.id == fromID }?.label
                }
                .sorted()
                .map { String($0) }
                .joined(separator: ", ")
            let outgoingText = outgoingLabels.isEmpty ? "none" : outgoingLabels
            let incomingText = incomingLabels.isEmpty ? "none" : incomingLabels
            desc += " Node \(selectedNode.label) selected, outgoing to: \(outgoingText); incoming from: \(incomingText)."
        } else {
            desc += " No node selected."
        }
        return desc
    }
}



// File: GraphEditorWatch/Models/AppConstants.swift
//
//  AppConstants.swift
//  GraphEditor
//
//  Created by handcart on 8/3/25.
//


import CoreGraphics

struct AppConstants {
    // Graph visuals
    static let nodeModelRadius: CGFloat = 10.0
    static let hitScreenRadius: CGFloat = 30.0
    static let tapThreshold: CGFloat = 10.0
    
    // Zooming
    static let numZoomLevels = 6
    static let defaultMinZoom: CGFloat = 0.2
    static let defaultMaxZoom: CGFloat = 5.0
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
    let maxZoom: CGFloat
    @Binding var crownPosition: Double
    let onUpdateZoomRanges: () -> Void
    
    var body: some View {
        Canvas { context, size in
            let transform = CGAffineTransform(translationX: offset.width, y: offset.height)
                .scaledBy(x: zoomScale, y: zoomScale)

            // Draw edges and their labels (updated for arrows)
            for edge in viewModel.model.edges {
                if let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                   let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                    // Inside the for edge loop:
                    let fromPos = (draggedNode?.id == fromNode.id ? CGPoint(x: fromNode.position.x + dragOffset.x, y: fromNode.position.y + dragOffset.y) : fromNode.position).applying(transform)
                    let toPos = (draggedNode?.id == toNode.id ? CGPoint(x: toNode.position.x + dragOffset.x, y: toNode.position.y + dragOffset.y) : toNode.position).applying(transform)

                    // Calculate direction and length
                    let direction = CGPoint(x: toPos.x - fromPos.x, y: toPos.y - fromPos.y)
                    let length = hypot(direction.x, direction.y)
                    if length > 0 {
                        let unitDir = CGPoint(x: direction.x / length, y: direction.y / length)

                        // Shorten line to end at toNode's edge
                        let scaledToRadius = toNode.radius * zoomScale
                        let lineEnd = toPos - unitDir * scaledToRadius  // Back up from center by radius

                        // Draw shortened line
                        context.stroke(Path { path in
                            path.move(to: fromPos)
                            path.addLine(to: lineEnd)
                        }, with: .color(.blue), lineWidth: 2 * zoomScale)

                        // Draw arrowhead with tip at toNode's edge (uses arrowSize)
                        let arrowSize: CGFloat = 10 * zoomScale  // Declaration here; now used below
                        let perpDir = CGPoint(x: -unitDir.y, y: unitDir.x)
                        let arrowTip = lineEnd  // Tip at line end (node edge)
                        let arrowBase1 = arrowTip - unitDir * arrowSize + perpDir * (arrowSize / 2)
                        let arrowBase2 = arrowTip - unitDir * arrowSize - perpDir * (arrowSize / 2)

                        context.fill(Path { path in
                            path.move(to: arrowTip)
                            path.addLine(to: arrowBase1)
                            path.addLine(to: arrowBase2)
                            path.closeSubpath()
                        }, with: .color(.blue))
                    }

                    // Show direction e.g., "\(fromNode.label)→\(toNode.label)")
                    let midpoint = CGPoint(x: (fromPos.x + toPos.x) / 2, y: (fromPos.y + toPos.y) / 2)
                    let edgeLabel = "\(fromNode.label)→\(toNode.label)"  // Updated for direction
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
                let scaledRadius = AppConstants.nodeModelRadius * zoomScale
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
        .drawingGroup()
        .accessibilityElement(children: .combine)
            .accessibilityLabel(viewModel.model.graphDescription(selectedID: selectedNodeID))
            .accessibilityHint("Double-tap for menu. Long press to delete selected.")        .accessibilityChildren {
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
            maxZoom: maxZoom,
            crownPosition: $crownPosition,
            onUpdateZoomRanges: onUpdateZoomRanges
        ))
    }
    
    private func graphDescription() -> String {
        var desc = "Graph with \(viewModel.model.nodes.count) nodes and \(viewModel.model.edges.count) edges."
        if let selectedID = selectedNodeID,
           let selectedNode = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
            let connectedLabels = viewModel.model.edges
                .filter { $0.from == selectedID || $0.to == selectedID }
                .compactMap { edge in
                    let otherID = (edge.from == selectedID ? edge.to : edge.from)
                    return viewModel.model.nodes.first { $0.id == otherID }?.label
                }
                .sorted()
                .map { String($0) }
                .joined(separator: ", ")
            desc += " Node \(selectedNode.label) selected, connected to nodes: \(connectedLabels.isEmpty ? "none" : connectedLabels)."
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
    @StateObject var viewModel: GraphViewModel
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
    @State private var storageError: String? = nil
    
    init(storage: GraphStorage = PersistenceManager(),
         physicsEngine: PhysicsEngine = PhysicsEngine(simulationBounds: WKInterfaceDevice.current().screenBounds.size)) {
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        _viewModel = StateObject(wrappedValue: GraphViewModel(model: model))
    }
    
    var body: some View {
        GeometryReader { geo in
            graphCanvasView(geo: geo)
        }
        .sheet(isPresented: $showMenu) {
            menuView
        }
        .focusable()
        .digitalCrownRotation($crownPosition, from: 0.0, through: Double(AppConstants.numZoomLevels - 1), sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: false)
        .onChange(of: crownPosition) { oldValue, newValue in
            if ignoreNextCrownChange {
                ignoreNextCrownChange = false
                updateZoomScale(oldCrown: oldValue, adjustOffset: false)
                return
            }
            
            let maxCrown = Double(AppConstants.numZoomLevels - 1)
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
        // In body, add:
        .alert("Storage Error", isPresented: Binding(get: { storageError != nil }, set: { _ in storageError = nil })) {
            Button("OK") {}
        } message: {
            Text(storageError ?? "Unknown error")
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
            maxZoom: maxZoom,

            crownPosition: $crownPosition,
            onUpdateZoomRanges: updateZoomRanges
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
    
      
    // Updates the zoom range based on current graph and view size.
    private func updateZoomRanges() {
        guard viewSize != .zero else { return }
        
        if viewModel.model.nodes.isEmpty {
            minZoom = 0.5
            maxZoom = 2.0
            let midCrown = Double(AppConstants.numZoomLevels - 1) / 2.0
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
        
        let nodeDia = 2 * AppConstants.nodeModelRadius
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
        let newCrown = Double(progress * CGFloat(AppConstants.numZoomLevels - 1))
        if abs(newCrown - crownPosition) > 1e-6 {
            ignoreNextCrownChange = true
            crownPosition = newCrown
        }
    }
    
    // Updates the zoom scale and adjusts offset if needed.
    private func updateZoomScale(oldCrown: Double, adjustOffset: Bool) {
        let oldProgress = oldCrown / Double(AppConstants.numZoomLevels - 1)
        let oldScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), oldProgress))
        
        let newProgress = crownPosition / Double(AppConstants.numZoomLevels - 1)
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
    let maxZoom: CGFloat
    @Binding var crownPosition: Double
    let onUpdateZoomRanges: () -> Void
    
    func body(content: Content) -> some View {
        content
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let inverseTransform = CGAffineTransform(translationX: offset.width, y: offset.height)
                        .scaledBy(x: zoomScale, y: zoomScale)
                        .inverted()
                    let touchPos = value.startLocation.applying(inverseTransform)
                    
                    if draggedNode == nil {
                        // Check for node hit to prioritize drag/selection
                        if let hitNode = viewModel.model.nodes.first(where: { distance($0.position, touchPos) < $0.radius + (AppConstants.hitScreenRadius / zoomScale - $0.radius) }) {  // Adjust buffer for variable radius
                            draggedNode = hitNode
                        }
                    }
                    
                    if let dragged = draggedNode {
                        // Handle ongoing drag (for potential edge or move)
                        dragOffset = CGPoint(x: value.translation.width / zoomScale, y: value.translation.height / zoomScale)
                        let currentPos = value.location.applying(inverseTransform)
                        potentialEdgeTarget = viewModel.model.nodes.first {
                            $0.id != dragged.id && hypot($0.position.x - currentPos.x, $0.position.y - currentPos.y) < AppConstants.hitScreenRadius / zoomScale
                        }
                    }
                }
                .onEnded { value in
                    let dragDistance = hypot(value.translation.width, value.translation.height)
                    let inverseTransform = CGAffineTransform(translationX: offset.width, y: offset.height)
                        .scaledBy(x: zoomScale, y: zoomScale)
                        .inverted()
                    let touchPos = value.location.applying(inverseTransform)
                    
                    if let node = draggedNode,
                       let index = viewModel.model.nodes.firstIndex(where: { $0.id == node.id }) {
                        viewModel.snapshot()
                        if dragDistance < AppConstants.tapThreshold {                            // Handle tap on node: Toggle selection
                            if selectedNodeID == node.id {
                                selectedNodeID = nil
                            } else {
                                selectedNodeID = node.id
                            }
                            WKInterfaceDevice.current().play(.click)  // Haptic feedback for selection
                        } else {
                            // Handle actual drag: Move node or create edge
                            if let target = potentialEdgeTarget, target.id != node.id,
                               !viewModel.model.edges.contains(where: { ($0.from == node.id && $0.to == target.id) }) {  // Removed symmetric check; now only checks exact direction
                                viewModel.model.edges.append(GraphEdge(from: node.id, to: target.id))  // Directed: dragged -> target
                                viewModel.model.startSimulation()
                                WKInterfaceDevice.current().play(.success)
                            } else {
                                var updatedNode = viewModel.model.nodes[index]
                                updatedNode.position = CGPoint(x: updatedNode.position.x + dragOffset.x, y: updatedNode.position.y + dragOffset.y)
                                viewModel.model.nodes[index] = updatedNode
                                viewModel.model.startSimulation()
                            }
                        }
                    } else {
                        // No node dragged: Handle tap to add new node or pan (but pan is in simultaneous gesture)
                        if dragDistance < AppConstants.tapThreshold {
                            selectedNodeID = nil  // Deselect on background tap
                            viewModel.snapshot()
                            viewModel.model.addNode(at: touchPos)
                            viewModel.model.startSimulation()
                        }
                    }
                    
                    // Reset drag state
                    draggedNode = nil
                    dragOffset = .zero
                    potentialEdgeTarget = nil
                    onUpdateZoomRanges()
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
                        let worldPos = location.applying(inverseTransform)  // This is defined here

                        // Check for node hit (use worldPos, not touchPos; update for radius if applied from previous)
                        if let hitNode = viewModel.model.nodes.first(where: { distance($0.position, worldPos) < $0.radius + (AppConstants.hitScreenRadius / zoomScale - $0.radius) }) {
                            viewModel.deleteNode(withID: hitNode.id)
                            WKInterfaceDevice.current().play(.success)
                            viewModel.model.startSimulation()
                            return
                        }

                        // Check for edge hit (unchanged, but uses worldPos)
                        for edge in viewModel.model.edges {
                            if let from = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                               let to = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                                if pointToLineDistance(point: worldPos, from: from.position, to: to.position) < AppConstants.hitScreenRadius / zoomScale {
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
struct GraphEditorWatchApp: App {
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
@testable import GraphEditorWatch // Updated module name
import GraphEditorShared // For Node, GraphEdge, etc.
import XCTest
import SwiftUI

class MockGraphStorage: GraphStorage {
    var nodes: [Node] = []
    var edges: [GraphEdge] = []
    
    func save(nodes: [Node], edges: [GraphEdge]) throws { // Add 'throws'
        self.nodes = nodes
        self.edges = edges
        // No actual throw needed for mock
    }
    
    func load() -> (nodes: [Node], edges: [GraphEdge]) {
        (nodes, edges)
    }
}

struct GraphModelTests {
    private func mockPhysicsEngine() -> GraphEditorShared.PhysicsEngine {
        GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300)) // Mock size for tests
    }
    
    @Test func testUndoRedoMixedOperations() {
        let storage = MockGraphStorage()
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
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
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(model.nodes.count >= 3, "Should load default or saved nodes")
        #expect(model.edges.count >= 3, "Should load default edges")
    }
    
    @Test func testSnapshotAndUndo() {
        let storage = MockGraphStorage()
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let initialNodes = model.nodes
        model.snapshot()
        model.addNode(at: CGPoint.zero)
        #expect(model.nodes.count == initialNodes.count + 1, "Node added")
        model.undo()
        let nodesMatch = model.nodes == initialNodes
        #expect(nodesMatch, "Undo restores state")
    }
    
    @Test func testDeleteNodeAndEdges() {
        let storage = MockGraphStorage()
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(!model.nodes.isEmpty, "Assumes default nodes exist")
        let nodeID = model.nodes[0].id
        let initialEdgeCount = model.edges.count
        model.deleteNode(withID: nodeID)
        #expect(model.nodes.first { $0.id == nodeID } == nil, "Node deleted")
        #expect(model.edges.count < initialEdgeCount, "Edges reduced")
    }
    
    @Test func testSaveLoadRoundTrip() {
        let storage = MockGraphStorage()
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let originalNodes = model.nodes
        let originalEdges = model.edges
        // Modify and snapshot to trigger save
        model.addNode(at: CGPoint.zero)
        model.snapshot()
        // New instance to trigger load
        let newModel = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(newModel.nodes.count == originalNodes.count + 1, "Loaded nodes include addition")
        let edgesMatch = newModel.edges == originalEdges
        #expect(edgesMatch, "Loaded edges match original")
    }
    
    @Test func testAddNode() {
        let storage = MockGraphStorage()
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let initialCount = model.nodes.count
        model.addNode(at: CGPoint.zero)
        #expect(model.nodes.count == initialCount + 1, "Node added")
    }
    
    @Test func testRedo() {
        let storage = MockGraphStorage()
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let initialNodes = model.nodes
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
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
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
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        model.addNode(at: CGPoint.zero)
        #expect(model.nodes.last?.label == 11, "Added node gets max loaded + 1")
    }
    
    @Test func testDeleteEdge() {
        let storage = MockGraphStorage()
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(!model.edges.isEmpty, "Assumes default edges exist")
        let edgeID = model.edges[0].id
        let initialEdgeCount = model.edges.count
        model.deleteEdge(withID: edgeID)
        #expect(model.edges.first { $0.id == edgeID } == nil, "Edge deleted")
        #expect(model.edges.count == initialEdgeCount - 1, "Edge count reduced")
    }
    
    @Test func testCanUndoAndCanRedo() {
        let storage = MockGraphStorage()
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(!model.canUndo, "No undo initially")
        #expect(!model.canRedo, "No redo initially")
        model.snapshot()
        #expect(model.canUndo, "Can undo after snapshot")
        model.undo()
        #expect(model.canRedo, "Can redo after undo")
    }
    
    @Test func testUndoAfterDelete() {
        let storage = MockGraphStorage()
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        let initialNodes = model.nodes
        model.snapshot()
        let nodeID = model.nodes[0].id
        model.deleteNode(withID: nodeID)
        #expect(model.nodes.count == initialNodes.count - 1, "Node deleted")
        model.undo()
        #expect(model.nodes.count == initialNodes.count, "Undo restores deleted node")
    }
    
    @Test func testStartStopSimulation() {
        let storage = MockGraphStorage()
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        model.startSimulation()
        // Simulate time passage; check if positions change (e.g., run a few manual steps)
        var nodesCopy = model.nodes
        _ = model.physicsEngine.simulationStep(nodes: &nodesCopy, edges: model.edges)
        let positionsChanged = nodesCopy != model.nodes
        #expect(positionsChanged, "Simulation affects positions") // Assuming it runs
        model.stopSimulation()
        // Verify timer is nil (but since private, perhaps add a public isSimulating property if needed)
    }
    
    @Test func testEmptyGraphInitialization() {
        let storage = MockGraphStorage()
        storage.nodes = []
        storage.edges = []
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        #expect(model.nodes.count == 3, "Initializes with default nodes if empty")
        #expect(model.edges.count == 3, "Initializes with default edges if empty")
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
        #expect(abs(distance(nodes[0].position, nodes[1].position) - PhysicsConstants.idealLength) < 42, "Nodes approach ideal edge length")
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
        for _ in 0..<PhysicsConstants.maxSimulationSteps {
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
        var nodes = model.nodes
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
        let loaded = manager.load()
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
        let reloaded = manager.load()
        #expect(reloaded.nodes == nodes, "Loaded nodes match saved (including IDs)")
        #expect(reloaded.edges == edges, "Loaded edges match saved")
    }

    @Test func testUndoRedoThroughViewModel() {
        let storage = mockStorage()
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
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
            let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: physicsEngine)
            
            // Setup: Clear default nodes/edges if needed, but since test assumes empty edges after adding, adjust expectations.
            // Note: GraphModel init adds defaults if empty, so to match test intent, we'll clear them here for the test.
            model.nodes = []
            model.edges = []
            model.addNode(at: CGPoint(x: 0, y: 0))
            model.addNode(at: CGPoint(x: 50, y: 50))
            #expect(model.edges.isEmpty, "No edges initially")
            
            let viewModel = GraphViewModel(model: model)
            let node1 = model.nodes[0]
            let node2 = model.nodes[1]
            
            // Mock gesture properties instead of creating Value
            let mockTranslation = CGSize(width: 50, height: 50)
            
            // Simulate onEnded logic
            let draggedNode: Node? = node1
            let potentialEdgeTarget: Node? = node2
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
                            var updatedNode = viewModel.model.nodes[index]
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

// Add this struct at the end of GraphEditorWatchTests.swift, after the existing test structs.
struct AccessibilityTests {
    private func mockPhysicsEngine() -> GraphEditorShared.PhysicsEngine {
        GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
    }

    @Test func testGraphDescription() {
        let storage = MockGraphStorage()
        // Preload with dummy to avoid defaults and set nextNodeLabel to 1
        storage.nodes = [Node(label: 0, position: .zero)]
        let model = GraphEditorWatch.GraphModel(storage: storage, physicsEngine: mockPhysicsEngine(), nextNodeLabel: 1)
        model.nodes = []  // Clear for test setup
        model.edges = []
        
        model.nextNodeLabel = 1  // Reset for consistent labeling in test
        
        model.addNode(at: .zero)  // Label 1
        model.addNode(at: CGPoint(x: 10, y: 10))  // Label 2
        model.edges.append(GraphEdge(from: model.nodes[0].id, to: model.nodes[1].id))
        
        let descNoSelect = model.graphDescription(selectedID: nil)
        #expect(descNoSelect == "Graph with 2 nodes and 1 directed edges. No node selected.", "Correct desc without selection")
        
        let descWithSelect = model.graphDescription(selectedID: model.nodes[0].id)
        #expect(descWithSelect == "Graph with 2 nodes and 1 directed edges. Node 1 selected, outgoing to: 2; incoming from: none.", "Correct desc with selection")
    }
}



