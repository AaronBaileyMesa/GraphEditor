//
//  NodeMenuView.swift
//  GraphEditor
//
//  Created by handcart on 10/21/25.
//


//
//  NodeMenuView.swift
//  GraphEditor
//
//  Created by handcart on 10/21/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared
import os

struct NodeMenuView: View {
    let viewModel: GraphViewModel
    let isSimulatingBinding: Binding<Bool>
    let onCenterGraph: () -> Void
    @Binding var showMenu: Bool
    @Binding var showOverlays: Bool
    @Binding var selectedNodeID: NodeID?
    let onDismiss: () -> Void
    
    @FocusState private var isMenuFocused: Bool
    @State private var isAddingEdge: Bool = false
    
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "nodemenuview")
    
    // Fetch node label for header
    private var nodeLabel: String {
        if let id = selectedNodeID, let node = viewModel.model.nodes.first(where: { $0.id == id }) {
            return "\(node.label)"
        }
        return "Unknown"
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                Text("Node \(nodeLabel)").font(.subheadline.bold()).gridCellColumns(2)  // Name as first item
                
                Text("Add").font(.subheadline.bold()).gridCellColumns(2)
                AddSection(
                    viewModel: viewModel,
                    selectedNodeID: selectedNodeID,
                    onDismiss: onDismiss,
                    onAddEdge: { type in
                        viewModel.pendingEdgeType = type
                        isAddingEdge = true
                    }
                )
                
                Text("Edit").font(.subheadline.bold()).gridCellColumns(2)
                EditSection(
                    viewModel: viewModel,
                    selectedNodeID: selectedNodeID,
                    selectedEdgeID: nil,  // No edge selected
                    onDismiss: onDismiss,
                    onEditNode: {}
                )
                
                Text("View").font(.subheadline.bold()).gridCellColumns(2)
                ViewSection(
                    showOverlays: $showOverlays,
                    isSimulating: isSimulatingBinding,
                    onCenterGraph: onCenterGraph,
                    onDismiss: onDismiss,
                    onSimulationChange: { newValue in
                        viewModel.model.isSimulating = newValue
                        if newValue {
                            Task { await viewModel.model.startSimulation() }
                        } else {
                            Task { await viewModel.model.stopSimulation() }
                        }
                    }
                )
                
                Text("Graph").font(.subheadline.bold()).gridCellColumns(2)
                GraphSection(viewModel: viewModel, onDismiss: onDismiss)
            }
            .padding(4)
        }
        .accessibilityIdentifier("nodeMenuGrid")
        .navigationTitle("Node Menu")  // Differentiate for testing
        .focused($isMenuFocused)
        .onAppear {
            isMenuFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMenuFocused = true
            }
            Self.logger.debug("Node Menu appeared: selectedNodeID=\(selectedNodeID?.uuidString.prefix(8) ?? "nil")")
        }
        .onChange(of: isMenuFocused) { _, newValue in
            Self.logger.debug("Node Menu focus: \(newValue)")
            if !newValue {
                isMenuFocused = true
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: isAddingEdge) { _, newValue in
            if newValue {
                // Handle add-edge mode (same as original)
            }
        }
    }
}