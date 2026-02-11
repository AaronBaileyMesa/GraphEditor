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
        if selectedNodeID != nil, selectedEdgeID == nil {
            // Check node type and route to appropriate menu
            if let node = viewModel.model.nodes.first(where: { $0.id == selectedNodeID }) {
                if node.unwrapped is TaskNode {
                    TaskNodeMenuView(
                        viewModel: viewModel,
                        onDismiss: { showMenu = false },
                        selectedNodeID: $selectedNodeID
                    )
                } else if node.unwrapped is MealNode {
                    MealNodeMenuView(
                        viewModel: viewModel,
                        onDismiss: { showMenu = false },
                        selectedNodeID: $selectedNodeID
                    )
                } else {
                    NodeMenuView(
                        viewModel: viewModel,
                        onDismiss: { showMenu = false },
                        selectedNodeID: $selectedNodeID,
                        isAddingEdge: $isAddingEdge
                    )
                }
            } else {
                NodeMenuView(
                    viewModel: viewModel,
                    onDismiss: { showMenu = false },
                    selectedNodeID: $selectedNodeID,
                    isAddingEdge: $isAddingEdge
                )
            }
        } else if selectedEdgeID != nil {
            EdgeMenuView(
                viewModel: viewModel,
                isSimulatingBinding: isSimulatingBinding,
                onCenterGraph: onCenterGraph,
                showMenu: $showMenu,
                showOverlays: $showOverlays,
                selectedEdgeID: $selectedEdgeID,
                onDismiss: { showMenu = false }
            )
        } else {
            GraphMenuView(
                viewModel: viewModel,
                isSimulatingBinding: isSimulatingBinding,
                showMenu: $showMenu,
                showOverlays: $showOverlays,
                onDismiss: { showMenu = false }
            )
        }
    }
}
