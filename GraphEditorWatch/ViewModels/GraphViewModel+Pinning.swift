//
//  GraphViewModel+Pinning.swift
//  GraphEditorWatch
//
//  Extension for pinning nodes to the user graph

import Foundation
import GraphEditorShared
import os

// MARK: - Pinning Support
extension GraphViewModel {
    
    /// Pins a node to the user graph canvas
    @MainActor
    public func pinNodeToUserGraph(nodeID: NodeID) async {
        guard isInSubGraph else {
            Logger(subsystem: "io.handcart.GraphEditor", category: "pinning")
                .warning("Cannot pin: not in sub-graph context")
            return
        }
        
        guard let node = model.nodes.first(where: { $0.id == nodeID }) else {
            Logger(subsystem: "io.handcart.GraphEditor", category: "pinning")
                .error("Cannot pin: node not found")
            return
        }
        
        // Extract node info for caching
        let label = "\(node.label)"
        let nodeType = String(describing: type(of: node.unwrapped))
        
        // Calculate a default position on the user graph
        // Place pinned nodes in a vertical list on the right side
        let position = CGPoint(x: 400, y: 100)  // Default position, can be improved
        
        // Load current user graph state
        do {
            var userGraphState = try await model.storage.loadUserGraphState() ?? UserGraphState()
            
            // Create pin reference
            let pin = PinnedNodeReference(
                sourceGraphName: currentGraphName,
                sourceNodeID: nodeID,
                position: position,
                cachedLabel: label,
                cachedNodeType: nodeType
            )
            
            // Check if already pinned
            if userGraphState.pinnedNodes.contains(where: { $0.sourceNodeID == nodeID && $0.sourceGraphName == currentGraphName }) {
                Logger(subsystem: "io.handcart.GraphEditor", category: "pinning")
                    .info("Node already pinned")
                return
            }
            
            // Add pin
            userGraphState.pinnedNodes.append(pin)
            
            // Save updated state
            try await model.storage.saveUserGraphState(userGraphState)
            
            Logger(subsystem: "io.handcart.GraphEditor", category: "pinning")
                .info("Pinned node '\(label)' from '\(self.currentGraphName)' to user graph")
            
        } catch {
            Logger(subsystem: "io.handcart.GraphEditor", category: "pinning")
                .error("Failed to pin node: \(error.localizedDescription)")
        }
    }
    
    /// Unpins a node from the user graph canvas
    @MainActor
    public func unpinNodeFromUserGraph(pinID: UUID) async {
        do {
            var userGraphState = try await model.storage.loadUserGraphState() ?? UserGraphState()
            
            // Remove pin
            userGraphState.pinnedNodes.removeAll { $0.id == pinID }
            
            // Save updated state
            try await model.storage.saveUserGraphState(userGraphState)
            
            Logger(subsystem: "io.handcart.GraphEditor", category: "pinning")
                .info("Unpinned node with ID \(pinID.uuidString.prefix(8))")
            
        } catch {
            Logger(subsystem: "io.handcart.GraphEditor", category: "pinning")
                .error("Failed to unpin node: \(error.localizedDescription)")
        }
    }
}
