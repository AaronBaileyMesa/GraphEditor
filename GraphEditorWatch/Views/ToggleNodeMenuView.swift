//
//  ToggleNodeMenuView.swift
//  GraphEditor
//
//  Created by handcart on 10/25/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared
import os  // For logging

struct ToggleNodeMenuView: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void
    @Binding var selectedNodeID: NodeID?
    @Binding var isAddingEdge: Bool
    @State private var selectedEdgeType: EdgeType = .association  // From GraphTypes.swift
    @FocusState private var isMenuFocused: Bool
    @State private var showEditSheet = false  // NEW: Moved here to struct level
    
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "togglenodemenuview")
    
    private var nodeLabel: String {
        if let id = selectedNodeID, let node = viewModel.model.nodes.first(where: { $0.id == id }) {
            return "\(node.label)"
        }
        return ""
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Add Section (inherited from NodeMenuView, with extras)
                Text("Add").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                HStack(spacing: 8) {
                    addNodeButton
                    addToggleNodeButton
                }
                .padding(.horizontal, 8)
                
                if selectedNodeID != nil {
                    // Hierarchy-specific adds
                    HStack(spacing: 8) {
                        addPlainChildButton
                        addToggleChildButton
                    }
                    .padding(.horizontal, 8)
                    
                    HStack(spacing: 8) {
                        addEdgeButton
                        reorderChildrenButton  // Future: Reorder childOrder
                    }
                    .padding(.horizontal, 8)
                    
                    // Edge type buttons
                    HStack(spacing: 8) {
                        edgeTypeButton(type: .association)
                        edgeTypeButton(type: .hierarchy)
                    }
                    .padding(.horizontal, 8)
                }
                
                // Edit Section
                Text("Edit").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                HStack(spacing: 8) {
                    editContentsButton
                    toggleExpandButton
                    deleteNodeButton  // Assuming this exists; from your truncated code
                }
                .padding(.horizontal, 8)
            }
        }
        .navigationTitle("Toggle Node \(nodeLabel)")  // Added "Toggle" for distinction
        .focused($isMenuFocused)
        .onAppear {
            isMenuFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isMenuFocused = true }
        }
        .onChange(of: isMenuFocused) { _, newValue in
            if !newValue { isMenuFocused = true }
        }
    }
    
    // Edge type button (same as NodeMenuView)
    private func edgeTypeButton(type: EdgeType) -> some View {
        Button {
            selectedEdgeType = type
            Self.logger.debug("Selected \(type == .association ? "Association" : "Hierarchy") edge type")
        } label: {
            Text(type == .association ? "Assoc" : "Hier")
                .font(.caption)
                .padding(4)
                .background(selectedEdgeType == type ? Color.blue : Color.gray)
                .cornerRadius(4)
        }
        .accessibilityLabel("Select \(type == .association ? "Association" : "Hierarchy") edge type")
    }
    
    private var addNodeButton: some View {
        MenuButton(
            action: {
                Task { await viewModel.model.addNode(at: CGPoint.zero) }
                onDismiss()
            },
            label: {
                Label("Node", systemImage: "plus.circle")
            },
            accessibilityIdentifier: "addNodeButton"
        )
    }
    
    private var addToggleNodeButton: some View {
        MenuButton(
            action: {
                Task { await viewModel.model.addToggleNode(at: CGPoint.zero) }
                onDismiss()
            },
            label: {
                Label("Toggle", systemImage: "plus.circle.fill")
            },
            accessibilityIdentifier: "addToggleNodeButton"
        )
    }
    
    private var addPlainChildButton: some View {
        MenuButton(
            action: {
                if let id = selectedNodeID {
                    Task { await viewModel.model.addPlainChild(to: id) }
                }
                onDismiss()
            },
            label: {
                Label("Plain Child", systemImage: "plus.square")
            },
            accessibilityIdentifier: "addPlainChildButton"
        )
    }
    
    private var addToggleChildButton: some View {
        MenuButton(
            action: {
                if let id = selectedNodeID {
                    Task { await viewModel.model.addToggleChild(to: id) }
                }
                onDismiss()
            },
            label: {
                Label("Toggle Child", systemImage: "plus.square.fill")
            },
            accessibilityIdentifier: "addToggleChildButton"
        )
    }
    
    private var addEdgeButton: some View {
        MenuButton(
            action: {
                viewModel.pendingEdgeType = selectedEdgeType
                isAddingEdge = true
                onDismiss()
            },
            label: {
                Label("Edge", systemImage: "arrow.right.circle")
            },
            accessibilityIdentifier: "addEdgeButton"
        )
        .disabled(selectedNodeID == nil)
    }
    
    // Placeholder for reordering (future: navigate to a list view)
    private var reorderChildrenButton: some View {
        MenuButton(
            action: {
                // TODO: Implement reordering (e.g., present a draggable list of child IDs)
                Self.logger.debug("Reorder children triggered for node \(nodeLabel)")
                onDismiss()
            },
            label: {
                Label("Reorder", systemImage: "arrow.up.and.down")
            },
            accessibilityIdentifier: "reorderChildrenButton"
        )
    }
    
    private var editContentsButton: some View {
        NavigationLink(destination: EditContentSheet(
            selectedID: selectedNodeID ?? NodeID(),
            viewModel: viewModel,
            onSave: { newContents in
                if let id = selectedNodeID {
                    Task { await viewModel.model.updateNodeContents(withID: id, newContents: newContents) }
                }
                // No need for manual dismissal here—navigation pop handles it
            }
        )
        .environment(\.disableCanvasFocus, true)) {  // Keep for safety
            Label("Contents", systemImage: "pencil")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("editContentsButton")
    }
    
    private var toggleExpandButton: some View {
        if let id = selectedNodeID, let node = viewModel.model.nodes.first(where: { $0.id == id }) as? ToggleNode {
            let isExpanded = node.isExpanded  // Get current state
            return AnyView(  // Fixed: Wrap in AnyView to resolve opaque return type
                MenuButton(
                    action: {
                        Task { await viewModel.toggleSelectedNode() }  // Existing toggle logic
                        onDismiss()
                    },
                    label: {
                        Label(isExpanded ? "Collapse" : "Expand",
                              systemImage: isExpanded ? "chevron.up" : "chevron.down")  // Matching chevrons
                    },
                    accessibilityIdentifier: "toggleExpandCollapseButton"
                )
            )
        } else {
            return AnyView(EmptyView())  // Fixed: Consistent return type
        }
    }
    
    private var deleteNodeButton: some View {
        MenuButton(
            action: {
                if let id = selectedNodeID {
                    Task {
                        await viewModel.model.deleteNode(withID: id)
                        viewModel.setSelectedNode(nil)
                    }
                }
                onDismiss()
            },
            label: {
                Label("Delete", systemImage: "trash")
            },
            accessibilityIdentifier: "deleteNodeButton",
            role: .destructive
        )
    }
}
