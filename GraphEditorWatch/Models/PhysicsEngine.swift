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
    static let stiffness: CGFloat = 0.5  // Reduced from 1.0 to prevent overshoot
    static let repulsion: CGFloat = 5000  // Same as your change
    static let damping: CGFloat = 0.85  // Same
    static let idealLength: CGFloat = 100  // Same (fine for watch screen)
    static let centeringForce: CGFloat = 0.005  // Slightly increased for better centering on small bounds
    static let distanceEpsilon: CGFloat = 1e-3  // Same
    static let timeStep: CGFloat = 0.05  // Reduced from 1.0 for stable integration
    static let velocityThreshold: CGFloat = 0.2  // Increased slightly; we'll scale it by node count below
    static let maxSimulationSteps = 500  // Increased from 200 to allow more steps (with sub-stepping, still fast)
    static let minQuadSize: CGFloat = 1e-6  // Same
    static let maxQuadtreeDepth = 64  // Same
}

class Quadtree {
    let bounds: CGRect
    var centerOfMass: CGPoint = .zero
    var totalMass: CGFloat = 0
    var children: [Quadtree]? = nil
    var nodes: [Node] = []  // Replaces old single 'node'; allows multiple in leaves
    
    init(bounds: CGRect) {
        self.bounds = bounds
    }
    
    func insert(_ node: Node, depth: Int = 0) {
        if depth > Constants.maxQuadtreeDepth {
            nodes.append(node)
            updateCenterOfMass(with: node)
            return
        }
        
        if let children = children {
            let quadrant = getQuadrant(for: node.position)
            children[quadrant].insert(node, depth: depth + 1)
            aggregateFromChildren()  // Already there, good
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
                    aggregateFromChildren()  // ADD THIS HERE to propagate after subdivision inserts
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
        if halfWidth < Constants.distanceEpsilon || halfHeight < Constants.distanceEpsilon {
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
    
    func computeForce(on queryNode: Node, theta: CGFloat = 0.5) -> CGPoint {
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
        let dist = max(delta.magnitude, Constants.distanceEpsilon)
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
        let dist = max(hypot(deltaX, deltaY), Constants.distanceEpsilon)
        let forceMagnitude = Constants.repulsion * mass / (dist * dist)
        return CGPoint(x: deltaX / dist * forceMagnitude, y: deltaY / dist * forceMagnitude)
    }
}

public class PhysicsEngine {
    let simulationBounds: CGSize  // Remove hardcoded value
    
    public init(simulationBounds: CGSize) {  // Allow injection
        self.simulationBounds = simulationBounds
    }
    
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
        let quadtree = Quadtree(bounds: CGRect(origin: .zero, size: simulationBounds))
        for node in nodes {
            quadtree.insert(node, depth: 0)
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
            
            // Clamp position and reset velocity on bounds hit
            let oldPosition = node.position  // For checking if clamped
            node.position.x = max(0, min(simulationBounds.width, node.position.x))
            node.position.y = max(0, min(simulationBounds.height, node.position.y))
            if node.position.x != oldPosition.x {
                node.velocity.x = 0
            }
            if node.position.y != oldPosition.y {
                node.velocity.y = 0
            }
            
            nodes[i] = node
        }
        
        // Check if stable
        let totalVelocity = nodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }
        return totalVelocity >= Constants.velocityThreshold * CGFloat(nodes.count)
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
