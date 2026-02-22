//
//  GraphViewModel+Simulation.swift
//  GraphEditorWatch
//
//  Extension for physics simulation coordination

import Foundation
import GraphEditorShared
import WatchKit

// MARK: - Simulation Coordination
extension GraphViewModel {
    
    public func pauseSimulation() async {
        await model.pauseSimulation()
    }
    
    public func resumeSimulation() async {
        await model.resumeSimulation()
    }
    
    public func resumeSimulationAfterDelay() async {
        resumeTimer?.invalidate()
        resumeTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if WKApplication.shared().applicationState == .active {
                    await self.model.resumeSimulation()
                }
            }
        }
    }
    
    /// Triggers a physics-based layout animation until stable
    public func startLayoutAnimation() async {
        model.pushUndo()
        isAnimating = true
        await model.runAnimatedSimulation()
        isAnimating = false
        
        await model.resetVelocityHistory()
    }
}
