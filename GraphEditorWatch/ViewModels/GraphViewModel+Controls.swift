//
//  GraphViewModel+Controls.swift
//  GraphEditorWatch
//
//  Extension for control node management

import Foundation
import GraphEditorShared
import WatchKit
import SwiftUI
import os

// MARK: - Control Node Management
extension GraphViewModel {
    
    @MainActor
    public func generateControls(for nodeID: NodeID) async {
        await model.pauseSimulation()
        await model.updateEphemerals(selectedNodeID: nodeID)
        
        Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
            .debug("Generated controls for node \(nodeID.uuidString.prefix(8))")
        
        // Give SwiftUI a moment to render the overlay before resuming simulation
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
        
        await model.resetVelocityHistory()
        await model.resumeSimulation()
    }
    
    @MainActor
    public func clearControls() async {
        await model.pauseSimulation()
        await model.updateEphemerals(selectedNodeID: nil)
        
        Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
            .debug("Cleared controls")
        
        // Keep simulation paused when nothing is selected
    }
    
    public func updateEphemerals(selectedNodeID: NodeID?) async {
        // Delegate to model
        await model.updateEphemerals(selectedNodeID: selectedNodeID)
    }
    
    @MainActor
    public func repositionEphemerals(for nodeID: NodeID, to position: CGPoint) {
        model.repositionEphemerals(for: nodeID, to: position)
        Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
            .debug("Repositioned ephemerals for node \(nodeID.uuidString.prefix(8)) to (\(position.x), \(position.y))")
    }
    
    @MainActor
    func handleControlTap(control: ControlNode) async {
        let action = control.kind.defaultAction()
        
        guard let ownerID = control.ownerID else {
            Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
                .error("Control node \(control.kind.rawValue) has no ownerID")
            return
        }
        
        await action(self, ownerID)
        
        Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
            .debug("Handled tap on control \(control.kind.rawValue) for owner \(ownerID.uuidString.prefix(8))")
    }
    
    @MainActor
    func startAddingEdge(from nodeID: NodeID) {
        self.draggedNodeID = nodeID
        self.pendingEdgeType = .hierarchy
        self.isAddingEdge = true
        Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
            .debug("Entered add edge mode from node \(nodeID.uuidString.prefix(8))")
    }
}
