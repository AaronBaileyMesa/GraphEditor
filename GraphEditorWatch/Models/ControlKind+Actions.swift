//
//  ControlKind+Actions.swift
//  GraphEditor
//
//  Created by handcart on 12/11/25.
//

import GraphEditorShared  // Import shared for ControlKind

extension ControlKind {
    /// Returns a default action closure for this kind (watch-specific).
    /// - Returns: A closure that performs the action using GraphViewModel and owner NodeID.
    public func defaultAction() -> (GraphViewModel, NodeID) async -> Void {
        switch self {
        case .configMode:
            return { viewModel, _ in viewModel.isConfigMode.toggle() }  // Assuming a toggle property; adjust if needed
        case .addChild:
            return { viewModel, nodeID in await viewModel.addChild(to: nodeID) }  // Placeholder; impl in later commits
        case .edit:
            return { viewModel, nodeID in viewModel.showEditSheet(for: nodeID) }  // Assuming a method like this exists
        case .addEdge:
            return { viewModel, nodeID in viewModel.startAddingEdge(from: nodeID) }  // New: Enters edge mode
        }
    }
}
