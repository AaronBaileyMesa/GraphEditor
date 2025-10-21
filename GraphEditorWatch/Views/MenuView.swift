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
    @State private var showEditSheet: Bool = false
    @State private var isAddingEdge: Bool = false
    
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "menuview")
    
    var body: some View {
        List {
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
                    onEditNode: { showEditSheet = true }
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
        .accessibilityIdentifier("menuList")
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
        .sheet(isPresented: $showEditSheet) {  // New: Local sheet for edit
            if let selectedID = viewModel.selectedNodeID {
                EditContentSheet(selectedID: selectedID, viewModel: viewModel, onSave: { newContents in
                    Task { await viewModel.model.updateNodeContents(withID: selectedID, newContents: newContents) }
                    showEditSheet = false
                })
            }
        }
        .onChange(of: isAddingEdge) { _, newValue in  // New: Handle add edge mode (if needed; or pass to parent)
            if newValue {
                // Optionally notify viewModel or handle here
            }
        }
    }
}

#Preview {
    @Previewable @State var mockSelectedNodeID: NodeID?
    @Previewable @State var mockSelectedEdgeID: UUID? = UUID()  // Simulate
    let mockViewModel = GraphViewModel(model: GraphModel(storage: PersistenceManager(), physicsEngine: PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))))
    mockViewModel.setSelectedEdge(UUID())  // Simulate edge selection for preview
    return MenuView(
        viewModel: mockViewModel,
        isSimulatingBinding: .constant(false),
        onCenterGraph: {},
        showMenu: .constant(true),
        showOverlays: .constant(false),
        selectedNodeID: $mockSelectedNodeID,  // NEW
        selectedEdgeID: $mockSelectedEdgeID   // NEW
    )
}
