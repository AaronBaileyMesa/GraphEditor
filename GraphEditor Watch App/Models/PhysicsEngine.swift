//
//  Constants.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//


// Models/PhysicsEngine.swift
import SwiftUI
import Foundation

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

class PhysicsEngine {
    let simulationBounds: CGSize = CGSize(width: 300, height: 300)
    
    private var simulationSteps = 0
    
    func resetSimulation() {
        simulationSteps = 0
    }
    
    @discardableResult
    func simulationStep(nodes: inout [Node], edges: [Edge]) -> Bool {
        if simulationSteps >= Constants.maxSimulationSteps {
            return false
        }
        simulationSteps += 1
        
        var forces: [NodeID: CGPoint] = [:]
        let center = CGPoint(x: simulationBounds.width / 2, y: simulationBounds.height / 2)
        
        // Repulsion between all pairs
        for i in 0..<nodes.count {
            for j in i+1..<nodes.count {
                let deltaX = nodes[j].position.x - nodes[i].position.x
                let deltaY = nodes[j].position.y - nodes[i].position.y
                let dist = max(hypot(deltaX, deltaY), Constants.distanceEpsilon)
                let forceMagnitude = Constants.repulsion / (dist * dist)
                let forceDirectionX = deltaX / dist
                let forceDirectionY = deltaY / dist
                let forceX = forceDirectionX * forceMagnitude
                let forceY = forceDirectionY * forceMagnitude
                let currentForceI = forces[nodes[i].id] ?? .zero
                forces[nodes[i].id] = CGPoint(x: currentForceI.x - forceX, y: currentForceI.y - forceY)
                let currentForceJ = forces[nodes[j].id] ?? .zero
                forces[nodes[j].id] = CGPoint(x: currentForceJ.x + forceX, y: currentForceJ.y + forceY)
            }
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