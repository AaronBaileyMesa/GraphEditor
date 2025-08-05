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
            
            // Optional: In-code logging for perf (uncomment for debugging)
            // let startTime = Date()
            
            onUpdate()
            
            let subSteps = nodeCount < 10 ? 5 : (nodeCount < 30 ? 3 : 1)  // Fewer sub-steps for large graphs
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
            
            // Optional: Log elapsed time if > threshold
            // let elapsed = Date().timeIntervalSince(startTime)
            // if elapsed > 0.05 {
            //     print("Simulation step took \(elapsed)s for \(nodeCount) nodes")
            // }
            
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
