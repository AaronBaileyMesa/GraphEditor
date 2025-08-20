//
//  MenuView.swift
//  GraphEditor
//
//  Created by handcart on 8/20/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared

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
