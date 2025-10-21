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
    @Binding var selectedNodeID: NodeID?    // NEW: @Binding for reactivity
    @Binding var selectedEdgeID: UUID?      // NEW: @Binding for reactivity
    
    @FocusState private var isMenuFocused: Bool
    @State private var isAddingEdge: Bool = false  // RESTORE: Keep this state as it's used in onAddEdge
    
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "menuview")
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                AddSection(
                    viewModel: viewModel,
                    selectedNodeID: selectedNodeID,  // NEW: Use binding.wrappedValue
                    onDismiss: { showMenu = false },
                    onAddEdge: { type in
                        viewModel.pendingEdgeType = type
                        isAddingEdge = true
                    }
                )
                
                // NEW: Conditional EditSection to avoid empty header
                if selectedNodeID != nil || selectedEdgeID != nil {  // NEW: Use bindings
                    EditSection(
                        viewModel: viewModel,
                        selectedNodeID: selectedNodeID,      // NEW: Pass binding.wrappedValue
                        selectedEdgeID: selectedEdgeID,      // NEW: Pass binding.wrappedValue
                        onDismiss: { showMenu = false },
                        onEditNode: {}  // Set to empty closure if unused
                    )
                }
                
                ViewSection(
                    showOverlays: $showOverlays,  // Now in scope
                    isSimulating: isSimulatingBinding,
                    onCenterGraph: onCenterGraph,
                    onDismiss: { showMenu = false },  // Now in scope
                    onSimulationChange: { newValue in
                        viewModel.model.isSimulating = newValue
                        if newValue {
                            Task { await viewModel.model.startSimulation() }
                        } else {
                            Task { await viewModel.model.stopSimulation() }
                        }
                    }
                )
                
                GraphSection(viewModel: viewModel, onDismiss: { showMenu = false })  // Now in scope
            }
            .padding(8)
        }
        .accessibilityIdentifier("menuGrid")  // Updated from "menuList" for new layout
        .navigationTitle("Menu")
        .focused($isMenuFocused)  // New: Bind focus to list
        .onAppear {
            isMenuFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMenuFocused = true
            }
            // NEW: Debug log for selections
            MenuView.logger.debug("Menu appeared: selectedNodeID=\(selectedNodeID?.uuidString.prefix(8) ?? "nil"), selectedEdgeID=\(selectedEdgeID?.uuidString.prefix(8) ?? "nil")")
        }
        .onChange(of: isMenuFocused) { _, newValue in
            MenuView.logger.debug("Menu focus: \(newValue)")
            if !newValue {
                isMenuFocused = true // Auto-recover
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: isAddingEdge) { _, newValue in  // RESTORE: Add back if needed for handling add-edge mode
            if newValue {
                // Optionally notify viewModel or handle here (from original code)
            }
        }
    }
}
