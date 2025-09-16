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
                
                Button("Delete Node", role: .destructive) {
                    Task {
                        isProcessing = true
                        do {
                            await viewModel.deleteNode(withID: selectedID)
                        }
                        clearSelections()  // NEW: Clear after delete
                        isProcessing = false
                    }
                    onDismiss()
                }
                .onSubmit { /* Same as above, but for focus */ }
                .disabled(isProcessing)
            }
            
            if let selectedEdgeID = selectedEdgeID,
               let selectedEdge = findSelectedEdge() {
                let fromID = selectedEdge.from
                let toID = selectedEdge.target
                let isBi = viewModel.model.isBidirectionalBetween(fromID, toID)
                let fromLabel = viewModel.model.nodes.first(where: { $0.id == fromID })?.label ?? 0
                let toLabel = viewModel.model.nodes.first(where: { $0.id == toID })?.label ?? 0
                
                // Display edge info
                Text("Edge: \(fromLabel) → \(toLabel) (\(selectedEdge.type.rawValue))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(isBi ? "Delete Both Edges" : "Delete Edge", role: .destructive) {
                    Task {
                        isProcessing = true
                        await viewModel.snapshot()
                        if isBi {
                            let pair = viewModel.model.edgesBetween(fromID, toID)
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
                
                if selectedEdge.type == .hierarchy {  // NEW: Only for directed edges
                    Button("Reverse Edge") {
                        Task {
                            isProcessing = true
                            await viewModel.snapshot()
                            viewModel.model.edges.removeAll { $0.id == selectedEdgeID }
                            viewModel.model.edges.append(GraphEdge(from: toID, target: fromID, type: .hierarchy))
                            await viewModel.model.startSimulation()
                            clearSelections()  // NEW: Clear after reverse
                            isProcessing = false
                        }
                        onDismiss()
                    }
                    .onSubmit { /* Same as above */ }
                    .disabled(isProcessing)
                }
            }
        }
        .accessibilityLabel("Edit section")  // NEW: Accessibility
        .foregroundColor(isProcessing ? .gray : .primary)  // NEW: Visual feedback for processing
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
                .onSubmit { /* No-op for toggle */ }
            
            Toggle("Run Simulation", isOn: isSimulating)
                .onChange(of: isSimulating.wrappedValue) { oldValue, newValue in
                    onSimulationChange(newValue)
                }
                .onSubmit { /* No-op for toggle */ }
            
            Button("Center Graph") {
                onCenterGraph()
                onDismiss()
            }
            .onSubmit { onCenterGraph(); onDismiss() }
        }
        .accessibilityLabel("View section")  // NEW: Accessibility
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
            .onSubmit { /* Same as above */ }
            
            Button("Save Graph") {
                Task { await viewModel.model.save() }
                onDismiss()
            }
            .onSubmit { /* Same as above */ }
            
            Button("Load Graph") {
                Task { await viewModel.loadGraph() }
                onDismiss()
            }
            .onSubmit { /* Same as above */ }
        }
        .accessibilityLabel("Graph section")  // NEW: Accessibility
    }
}

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
        }
        .navigationTitle("Menu")
        .focused($isMenuFocused)  // New: Bind focus to list
        .onAppear {
            isMenuFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMenuFocused = true
            }
            // NEW: Debug log for selections
            print("Menu appeared: selectedNodeID=\(selectedNodeID?.uuidString.prefix(8) ?? "nil"), selectedEdgeID=\(selectedEdgeID?.uuidString.prefix(8) ?? "nil")")
        }
        .onChange(of: isMenuFocused) { oldValue, newValue in
            print("Menu focus: \(newValue)") // Debug (fixed typo)
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
    @Previewable @State var mockSelectedNodeID: NodeID? = nil
    @Previewable @State var mockSelectedEdgeID: UUID? = UUID()  // Simulate
    let mockViewModel = GraphViewModel(model: GraphModel(storage: PersistenceManager(), physicsEngine: PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))))
    // UPDATED: Pass new bindings for preview (use placeholders); simulate selection for testing
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
