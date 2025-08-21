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

    var body: some View {
        Section(header: Text("Add")) {
            Button("Add Node") {
                viewModel.addNode(at: .zero)
                onDismiss()
            }
            Button("Add Toggle Node") {
                viewModel.addToggleNode(at: .zero)
                onDismiss()
            }
            if let selectedID = selectedNodeID {
                Button("Add Child") {
                    viewModel.addChild(to: selectedID)
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

    var body: some View {
        Section(header: Text("Edit")) {
            if let selectedID = selectedNodeID {
                Button("Delete Node", role: .destructive) {
                    viewModel.deleteNode(withID: selectedID)
                    onDismiss()
                }
            }
            if let selectedEdgeID = selectedEdgeID,
               let selectedEdge = viewModel.model.edges.first(where: { $0.id == selectedEdgeID }) {
                let fromID = selectedEdge.from
                let toID = selectedEdge.to
                let isBi = viewModel.model.isBidirectionalBetween(fromID, toID)
                Button(isBi ? "Delete Both Edges" : "Delete Edge", role: .destructive) {
                    viewModel.snapshot()
                    if isBi {
                        let pair = viewModel.model.edgesBetween(fromID, toID)
                        viewModel.model.edges.removeAll { pair.contains($0) }
                    } else {
                        viewModel.model.edges.removeAll { $0.id == selectedEdgeID }
                    }
                    viewModel.model.startSimulation()
                    onDismiss()
                }
            }
            if viewModel.canUndo {
                Button("Undo") {
                    viewModel.undo()
                    onDismiss()
                }
            }
            if viewModel.canRedo {
                Button("Redo") {
                    viewModel.redo()
                    onDismiss()
                }
            }
        }
    }
}

struct ViewSection: View {
    @Binding var showOverlays: Bool
    @Binding var isSimulating: Bool  // Now a Binding for direct Toggle control
    let onDismiss: () -> Void
    let onSimulationChange: (Bool) -> Void  // New: Handles pause/resume logic

    var body: some View {
        Section(header: Text("View & Simulation")) {
            Toggle("Show Overlays", isOn: $showOverlays)
                .onChange(of: showOverlays) {
                    onDismiss()
                }

            Toggle("Run Simulation", isOn: $isSimulating)
                .onChange(of: isSimulating) { newValue in
                    onSimulationChange(newValue)
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
            Button("Clear Graph", role: .destructive) {
                viewModel.clearGraph()
                onDismiss()
            }
        }
    }
}

struct MenuView: View {
    @ObservedObject var viewModel: GraphViewModel
    @Binding var showOverlays: Bool
    @Binding var showMenu: Bool
    
    private var isSimulatingBinding: Binding<Bool> {
        Binding(
            get: { viewModel.model.isSimulating },
            set: { viewModel.model.isSimulating = $0 }
        )
    }
    
    var body: some View {
        List {
            if viewModel.selectedEdgeID == nil {
                AddSection(viewModel: viewModel, selectedNodeID: viewModel.selectedNodeID, onDismiss: { showMenu = false })
            }
            
            if viewModel.selectedNodeID != nil || viewModel.selectedEdgeID != nil || viewModel.canUndo || viewModel.canRedo {
                EditSection(viewModel: viewModel, selectedNodeID: viewModel.selectedNodeID, selectedEdgeID: viewModel.selectedEdgeID, onDismiss: { showMenu = false })
            }
            
            ViewSection(
                
                showOverlays: $showOverlays,
                isSimulating: isSimulatingBinding,
                onDismiss: { showMenu = false },
                onSimulationChange: { newValue in
                    viewModel.model.isSimulating = newValue
                    if newValue {
                        viewModel.model.startSimulation()
                    } else {
                        viewModel.model.stopSimulation()
                    }
                }
            )
            
            GraphSection(viewModel: viewModel, onDismiss: { showMenu = false })
        }
        .navigationTitle("Graph Menu")  // Optional
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    ContentView()
}
