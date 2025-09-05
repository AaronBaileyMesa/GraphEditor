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
    let onAddEdge: () -> Void  // New: Callback for starting add edge mode
    
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
                Button("Add Edge") {  // New
                    onAddEdge()
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
                    viewModel.model.edges.append(GraphEdge(from: toID, to: fromID))
                    Task { await viewModel.model.startSimulation() }
                    onDismiss()
                }
            }
            if viewModel.canUndo {
                Button("Undo") {
                    Task { await viewModel.undo() }
                    onDismiss()
                }
            }
            if viewModel.canRedo {
                Button("Redo") {
                    Task { await viewModel.redo() }
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
    @Binding var showOverlays: Bool
    @Binding var showMenu: Bool
    let onCenterGraph: () -> Void
    @State private var showEditSheet: Bool = false  // New: Local state for edit sheet
    @State private var isAddingEdge: Bool = false  // New: Local state for add edge mode
    @FocusState private var isMenuFocused: Bool  // New
    
    private var isSimulatingBinding: Binding<Bool> {
        Binding(
            get: { viewModel.model.isSimulating },
            set: { viewModel.model.isSimulating = $0 }
        )
    }
    
    var body: some View {
        // In MenuView.swift, replace the entire List contents with this (remove the old if let selected... blocks)
        List {
            AddSection(
                viewModel: viewModel,
                selectedNodeID: viewModel.selectedNodeID,
                onDismiss: { showMenu = false },
                onAddEdge: { isAddingEdge = true }  // Wires up "Add Edge" button
            )
            
            EditSection(
                viewModel: viewModel,
                selectedNodeID: viewModel.selectedNodeID,
                selectedEdgeID: viewModel.selectedEdgeID,
                onDismiss: { showMenu = false },
                onEditNode: { showEditSheet = true }  // Wires up "Edit Node" to show sheet
            )
            
            // Keep your existing ViewSection and GraphSection here
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
            
            GraphSection(viewModel: viewModel, onDismiss: { showMenu = false })
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
    ContentView(viewModel: mockViewModel)  // <-- If ContentView now takes viewModel, add it here too (see next fix)
}
