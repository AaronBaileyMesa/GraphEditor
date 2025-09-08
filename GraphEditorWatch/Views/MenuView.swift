//
//  MenuView.swift
//  GraphEditor
//
//  Created by handcart on 8/20/25.
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
            Button("Add Toggle Node") {
                Task { await viewModel.addToggleNode(at: .zero) }
                onDismiss()
            }
            if let selectedID = selectedNodeID {
                Button("Add Child") {
                    Task { await viewModel.addChild(to: selectedID) }
                    onDismiss()
                }
                // NEW: Picker for edge type
                Picker("Edge Type", selection: $selectedEdgeType) {
                    Text("Association").tag(EdgeType.association)
                    Text("Hierarchy").tag(EdgeType.hierarchy)
                }
                Button("Add Edge") {  // UPDATED: Pass selected type
                    onAddEdge(selectedEdgeType)
                    onDismiss()
                }
            }
        }
    }
}

struct EditSection: View {
    let viewModel: GraphViewModel
    let selectedNodeID: NodeID?
    let selectedEdgeID: UUID?
    let onDismiss: () -> Void
    let onEditNode: () -> Void  // New: Callback for showing edit sheet
    
    var body: some View {
        Section(header: Text("Edit")) {
            if let selectedID = selectedNodeID {
                Button("Edit Node") {  // New
                    onEditNode()
                    onDismiss()
                }
                Button("Delete Node", role: .destructive) {  // Line ~67?
                    Task { await viewModel.deleteNode(withID: selectedID) }
                    onDismiss()
                }
            }
            if let selectedEdgeID = selectedEdgeID,
               let selectedEdge = viewModel.model.edges.first(where: { $0.id == selectedEdgeID }) {
                let fromID = selectedEdge.from
                let toID = selectedEdge.to
                let isBi = viewModel.model.isBidirectionalBetween(fromID, toID)
                Button(isBi ? "Delete Both Edges" : "Delete Edge", role: .destructive) {
                    Task { await viewModel.snapshot() }
                    if isBi {
                        let pair = viewModel.model.edgesBetween(fromID, toID)
                        viewModel.model.edges.removeAll { pair.contains($0) }
                    } else {
                        viewModel.model.edges.removeAll { $0.id == selectedEdgeID }
                    }
                    Task { await viewModel.model.startSimulation() }
                    onDismiss()
                }
                Button("Reverse Edge") {  // New
                    Task { await viewModel.snapshot() }
                    viewModel.model.edges.removeAll { $0.id == selectedEdgeID }
                    viewModel.model.edges.append(GraphEdge(from: toID, to: fromID))  // Reversed
                    Task { await viewModel.model.startSimulation() }
                    onDismiss()
                }
            }
        }
    }
}

struct ViewSection: View {
    @Binding var showOverlays: Bool
    let isSimulating: Binding<Bool>
    let onCenterGraph: () -> Void
    let onDismiss: () -> Void
    let onSimulationChange: (Bool) -> Void
    
    var body: some View {
        Section(header: Text("View")) {
            Toggle("Show Overlays", isOn: $showOverlays)
            Toggle("Run Simulation", isOn: isSimulating)
                .onChange(of: isSimulating.wrappedValue) { oldValue, newValue in
                    onSimulationChange(newValue)
                }
            
            Button("Center Graph") {
                onCenterGraph()
                onDismiss()
            }
        }
    }
}

struct GraphSection: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        Section(header: Text("Graph")) {
            Button("Reset Graph", role: .destructive) {
                Task { await viewModel.resetGraph() }
                onDismiss()
            }
            Button("Save Graph") {
                Task { await viewModel.model.save() }
                onDismiss()
            }
            Button("Load Graph") {
                Task { await viewModel.loadGraph() }
                onDismiss()
            }
        }
    }
}

struct MenuView: View {
    let viewModel: GraphViewModel
    let isSimulatingBinding: Binding<Bool>
    let onCenterGraph: () -> Void
    @Binding var showMenu: Bool  // NEW: Add as parameter to fix "Cannot find 'showMenu' in scope"
    @Binding var showOverlays: Bool  // NEW: Add as parameter to fix "Cannot find '$showOverlays' in scope"
    
    @FocusState private var isMenuFocused: Bool
    @State private var showEditSheet: Bool = false  // New: Local state for sheet
    @State private var isAddingEdge: Bool = false  // New: Local state for add edge mode
    
    var body: some View {
        List {
            AddSection(
                viewModel: viewModel,
                selectedNodeID: viewModel.selectedNodeID,
                onDismiss: { showMenu = false },  // Now in scope
                onAddEdge: { type in  // UPDATED: Receive type
                    viewModel.pendingEdgeType = type  // NEW: Set in ViewModel for gestures
                    isAddingEdge = true
                }
            )
            
            EditSection(
                viewModel: viewModel,
                selectedNodeID: viewModel.selectedNodeID,
                selectedEdgeID: viewModel.selectedEdgeID,
                onDismiss: { showMenu = false },  // Now in scope
                onEditNode: { showEditSheet = true }  // Wires up "Edit Node" to show sheet
            )
            
            // Keep your existing ViewSection and GraphSection here
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
        }        .navigationTitle("Menu")
        .focused($isMenuFocused)  // New: Bind focus to list
        .onAppear {
            isMenuFocused = true  // Force focus on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMenuFocused = true  // Double-focus for reliability
            }
        }
        .onChange(of: isMenuFocused) { oldValue, newValue in
            print("Menu focus: (newValue)") // Debug
            if !newValue {
                isMenuFocused = true // Auto-recover
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showEditSheet) {  // New: Local sheet for edit
            if let selectedID = viewModel.selectedNodeID {
                EditContentSheet(selectedID: selectedID, viewModel: viewModel, onSave: { newContent in
                    Task { await viewModel.updateNodeContent(withID: selectedID, newContent: newContent) }
                    showEditSheet = false
                })
            }
        }
        .onChange(of: isAddingEdge) { oldValue, newValue in  // New: Handle add edge mode (if needed; or pass to parent)
            if newValue {
                // Optionally notify viewModel or handle here
            }
        }
    }
}

#Preview {
    let mockViewModel = GraphViewModel(model: GraphModel(storage: PersistenceManager(), physicsEngine: PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))))
    // UPDATED: Pass new bindings for preview (use placeholders)
    MenuView(
        viewModel: mockViewModel,
        isSimulatingBinding: .constant(false),
        onCenterGraph: {},
        showMenu: .constant(true),
        showOverlays: .constant(false)
    )
}
