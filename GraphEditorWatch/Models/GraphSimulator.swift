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
        
        // Dynamic interval: Slower for larger graphs to save battery
        let baseInterval: TimeInterval = nodeCount < 20 ? 1.0 / 30.0 : (nodeCount < 50 ? 1.0 / 15.0 : 1.0 / 10.0)
        timer = Timer.scheduledTimer(withTimeInterval: baseInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            
            DispatchQueue.global(qos: .userInitiated).async {
                var nodes = self.getNodes()
                let edges = self.getEdges()
                var shouldContinue = false
                let subSteps = nodes.count < 10 ? 5 : (nodes.count < 30 ? 3 : 1)
                
                for _ in 0..<subSteps {
                    if self.physicsEngine.simulationStep(nodes: &nodes, edges: edges) {
                        shouldContinue = true
                    }
                }
                
                let totalVelocity = nodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }
                
                DispatchQueue.main.async {
                    self.setNodes(nodes)
                    onUpdate()
                    
                    // Early stop if already stable
                    if !shouldContinue || totalVelocity < PhysicsConstants.velocityThreshold * CGFloat(nodes.count) {
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
