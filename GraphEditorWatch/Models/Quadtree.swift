//
//  Quadtree.swift
//  GraphEditor
//
//  Created by handcart on 8/4/25.
//


import Foundation
import CoreGraphics
import GraphEditorShared  // For Node

public class Quadtree {  // Made public for consistency/test access
    let bounds: CGRect
    var centerOfMass: CGPoint = .zero
    var totalMass: CGFloat = 0
    var children: [Quadtree]? = nil
    var nodes: [Node] = []  // Replaces old single 'node'; allows multiple in leaves
    
    init(bounds: CGRect) {
        self.bounds = bounds
    }
    
    func insert(_ node: Node, depth: Int = 0) {
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
