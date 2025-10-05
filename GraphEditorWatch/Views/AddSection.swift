//
//  AddSection.swift
//  GraphEditor
//
//  Created by handcart on 10/5/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared

struct AddSection: View {
    let viewModel: GraphViewModel
    let selectedNodeID: NodeID?
    let onDismiss: () -> Void
    let onAddEdge: (EdgeType) -> Void  // UPDATED: Pass type to callback
    
    @State private var selectedEdgeType: EdgeType = .association  // NEW: Local state for Picker
    
    var body: some View {
        Section(header: Text("Add")) {
            Button("Add Node") {
                Task { await viewModel.addNode(at: .zero) }
                onDismiss()
            }
            .onSubmit { onDismiss() }  // NEW: WatchOS focus improvement
            
            Button("Add Toggle Node") {
                Task { await viewModel.addToggleNode(at: .zero) }
                onDismiss()
            }
            .onSubmit { onDismiss() }
            
            if let selectedID = selectedNodeID {
                Button("Add Child") {
                    Task { await viewModel.addChild(to: selectedID) }
                    onDismiss()
                }
                .onSubmit { onDismiss() }
                
                // NEW: Picker for edge type
                Picker("Edge Type", selection: $selectedEdgeType) {
                    Text("Association").tag(EdgeType.association)
                    Text("Hierarchy").tag(EdgeType.hierarchy)
                }
                .accessibilityLabel("Select edge type: \(selectedEdgeType.rawValue)")
                
                Button("Add Edge") {  // UPDATED: Pass selected type
                    onAddEdge(selectedEdgeType)
                    onDismiss()
                }
                .onSubmit { onAddEdge(selectedEdgeType); onDismiss() }
                .disabled(selectedNodeID == nil)  // Improvement: Explicit disable
            }
        }
        .accessibilityLabel("Add section")  // NEW: Accessibility
    }
}
