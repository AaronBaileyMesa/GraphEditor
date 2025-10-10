//
//  EditSection.swift
//  GraphEditor
//
//  Created by handcart on 10/5/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared

struct EditSection: View {
    let viewModel: GraphViewModel
    let selectedNodeID: NodeID?  // Keep let for now (uses wrappedValue)
    let selectedEdgeID: UUID?    // Keep let for now (uses wrappedValue)
    let onDismiss: () -> Void
    let onEditNode: () -> Void
    
    @State private var isProcessing = false  // NEW: Loading state
    
    private func findSelectedEdge() -> GraphEdge? {
        viewModel.model.edges.first { $0.id == selectedEdgeID }
    }
    
    private func clearSelections() {
        // NEW: Clear bindings (passed as let, so call ViewModel to sync)
        viewModel.setSelectedNode(nil)
        viewModel.setSelectedEdge(nil)
    }
    
    var body: some View {
        Section(header: Text("Edit")) {
            if let selectedID = selectedNodeID {
                Button("Edit Node") {  // New
                    onEditNode()
                    onDismiss()
                    
                }
                .onSubmit { onEditNode(); onDismiss() }
                .disabled(isProcessing)
                .accessibilityIdentifier("editNodeButton")
                
                if viewModel.isSelectedToggleNode {
                    Button("Toggle Expand/Collapse") {
                        Task { await viewModel.toggleSelectedNode() }
                        onDismiss()
                    }
                    .onSubmit { /* Same as above */ }
                    .accessibilityIdentifier("toggleExpandCollapseButton")

                }
                
                Button("Delete Node", role: .destructive) {
                    Task {
                        isProcessing = true
                        await viewModel.model.deleteNode(withID: selectedID)
                        clearSelections()  // NEW: Clear after delete
                        isProcessing = false
                    }
                    onDismiss()
                }
                .onSubmit { /* Same as above, but for focus */ }
                .disabled(isProcessing)
                .accessibilityIdentifier("deleteNodeButton")
            }
            
            if let selectedEdgeID = selectedEdgeID,
               let selectedEdge = findSelectedEdge() {
                let fromID = selectedEdge.from
                let targetID = selectedEdge.target
                let isBi = viewModel.model.isBidirectionalBetween(fromID, targetID)
                let fromLabel = viewModel.model.nodes.first(where: { $0.id == fromID })?.label ?? 0
                let toLabel = viewModel.model.nodes.first(where: { $0.id == targetID })?.label ?? 0
                
                // Display edge info
                Text("Edge: \(fromLabel) → \(toLabel) (\(selectedEdge.type.rawValue))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(isBi ? "Delete Both Edges" : "Delete Edge", role: .destructive) {
                    Task {
                        isProcessing = true
                        await viewModel.model.snapshot()
                        if isBi {
                            let pair = viewModel.model.edgesBetween(fromID, targetID)
                            viewModel.model.edges.removeAll { pair.contains($0) }
                        } else {
                            viewModel.model.edges.removeAll { $0.id == selectedEdgeID }
                        }
                        await viewModel.model.startSimulation()
                        clearSelections()  // NEW: Clear after delete
                        isProcessing = false
                    }
                    onDismiss()
                }
                .onSubmit { /* Same as above */ }
                .disabled(isProcessing)
                .accessibilityIdentifier("deleteEdgeButton")

                if selectedEdge.type == .hierarchy {  // NEW: Only for directed edges
                    Button("Reverse Edge") {
                        Task {
                            isProcessing = true
                            await viewModel.model.snapshot()
                            viewModel.model.edges.removeAll { $0.id == selectedEdgeID }
                            viewModel.model.edges.append(GraphEdge(from: targetID, target: fromID, type: .hierarchy))
                            await viewModel.model.startSimulation()
                            clearSelections()  // NEW: Clear after reverse
                            isProcessing = false
                        }
                        onDismiss()
                    }
                    .onSubmit { /* Same as above */ }
                    .disabled(isProcessing)
                    .accessibilityIdentifier("reverseNodeButton")

                }
            }
        }
        .accessibilityLabel("Edit section")  // NEW: Accessibility
        .foregroundColor(isProcessing ? .gray : .primary)  // NEW: Visual feedback for processing
    }
}
