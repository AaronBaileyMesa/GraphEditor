//
//  GraphSimulator.swift
//  GraphEditor
//
//  Created by handcart on 8/4/25.
//

// New GraphSimulator.swift with fixes for capturing inout in escaping closure (using closures instead of inout).

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
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            onUpdate()
            
            let subSteps = nodeCount < 10 ? 5 : 10
            var shouldContinue = true
            var nodes = self.getNodes()
            let edges = self.getEdges()
            for _ in 0..<subSteps {
                if !self.physicsEngine.simulationStep(nodes: &nodes, edges: edges) {
                    shouldContinue = false
                    break
                }
            }
            self.setNodes(nodes)
            
            if !shouldContinue {
                self.stopSimulation()
                return
            }
            
            let totalVelocity = nodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }
            recentVelocities.append(totalVelocity)
            if recentVelocities.count > velocityHistoryCount {
                recentVelocities.removeFirst()
            }
            
            if recentVelocities.count == velocityHistoryCount {
                let maxVel = recentVelocities.max() ?? 1.0
                let minVel = recentVelocities.min() ?? 0.0
                let relativeChange = (maxVel - minVel) / maxVel
                if relativeChange < velocityChangeThreshold {
                    self.stopSimulation()
                    return
                }
            }
        }
    }
    
    func stopSimulation() {
        timer?.invalidate()
        timer = nil
    }
}
