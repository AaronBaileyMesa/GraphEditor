//
//  GraphMenuView.swift
//  GraphEditor
//
//  Created by handcart on 10/21/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared
import os

struct GraphMenuView: View {
    let viewModel: GraphViewModel
    let isSimulatingBinding: Binding<Bool>
    let onCenterGraph: () -> Void
    @Binding var showMenu: Bool
    @Binding var showOverlays: Bool
    let onDismiss: () -> Void  // Added for consistency with other menus
    
    @FocusState private var isMenuFocused: Bool
    @State private var isAddingEdge: Bool = false
    
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "graphmenuview")
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                Text("Graph").font(.subheadline.bold()).gridCellColumns(2)  // Name as first item; enhance with actual graph name if available
                
                Text("Add").font(.subheadline.bold()).gridCellColumns(2)
                AddSection(
                    viewModel: viewModel,
                    selectedNodeID: nil,  // No selection
                    onDismiss: onDismiss,
                    onAddEdge: { type in
                        viewModel.pendingEdgeType = type
                        isAddingEdge = true
                    }
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
        .accessibilityIdentifier("graphMenuGrid")
        .navigationTitle("Graph Menu")  // Differentiate for testing
        .focused($isMenuFocused)
        .onAppear {
            isMenuFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMenuFocused = true
            }
            Self.logger.debug("Graph Menu appeared")
        }
        .onChange(of: isMenuFocused) { _, newValue in
            Self.logger.debug("Graph Menu focus: \(newValue)")
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
