//
//  MenuView.swift
//  GraphEditor
//
//  Created by handcart on 8/20/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared
import os

struct MenuView: View {
    let viewModel: GraphViewModel
    let isSimulatingBinding: Binding<Bool>
    let onCenterGraph: () -> Void
    @Binding var showMenu: Bool
    @Binding var showOverlays: Bool
    @Binding var selectedNodeID: NodeID?
    @Binding var selectedEdgeID: UUID?
    
    @FocusState private var isMenuFocused: Bool
    @State private var isAddingEdge: Bool = false
    
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "menuview")
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                Text("Add").font(.subheadline.bold()).gridCellColumns(2)
                AddSection(
                    viewModel: viewModel,
                    selectedNodeID: selectedNodeID,
                    onDismiss: { showMenu = false },
                    onAddEdge: { type in
                        viewModel.pendingEdgeType = type
                        isAddingEdge = true
                    }
                )
                
                if selectedNodeID != nil || selectedEdgeID != nil {
                    Text("Edit").font(.subheadline.bold()).gridCellColumns(2)
                    EditSection(
                        viewModel: viewModel,
                        selectedNodeID: selectedNodeID,
                        selectedEdgeID: selectedEdgeID,
                        onDismiss: { showMenu = false },
                        onEditNode: {}
                    )
                }
                
                Text("View").font(.subheadline.bold()).gridCellColumns(2)
                ViewSection(
                    showOverlays: $showOverlays,
                    isSimulating: isSimulatingBinding,
                    onCenterGraph: onCenterGraph,
                    onDismiss: { showMenu = false },
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
                GraphSection(viewModel: viewModel, onDismiss: { showMenu = false })
            }
            .padding(4)
        }
        .accessibilityIdentifier("menuGrid")
        .navigationTitle("Menu")
        .focused($isMenuFocused)
        .onAppear {
            isMenuFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMenuFocused = true
            }
            MenuView.logger.debug("Menu appeared: selectedNodeID=\(selectedNodeID?.uuidString.prefix(8) ?? "nil"), selectedEdgeID=\(selectedEdgeID?.uuidString.prefix(8) ?? "nil")")
        }
        .onChange(of: isMenuFocused) { _, newValue in
            MenuView.logger.debug("Menu focus: \(newValue)")
            if !newValue {
                isMenuFocused = true
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: isAddingEdge) { _, newValue in
            if newValue {
                // Handle add-edge mode
            }
        }
    }
}
