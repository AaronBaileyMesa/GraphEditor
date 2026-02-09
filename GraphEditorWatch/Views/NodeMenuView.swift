//
//  NodeMenuView.swift
//  GraphEditorWatch
//
//  Created by handcart on 2025-08-16
//

import SwiftUI
import WatchKit
import GraphEditorShared
import os  // For logging

struct NodeMenuView: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void
    @Binding var selectedNodeID: NodeID?
    @Binding var isAddingEdge: Bool
    @State private var selectedEdgeType: GraphEditorShared.EdgeType = .association  // Use shared EdgeType
    @FocusState private var isMenuFocused: Bool
    
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "nodemenuview")
    
    private var nodeLabel: String {
        if let id = selectedNodeID, let node = viewModel.model.nodes.first(where: { $0.id == id }) {
            return "\(node.label)"
        }
        return ""
    }
    
    var isToggleNode: Bool {
        viewModel.isSelectedToggleNode
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Add Section: Only show for collapsible nodes
                if isToggleNode {
                    Text("Add").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                    
                    HStack(spacing: 8) {
                        addChildButton
                        addEdgeButton
                    }
                    .padding(.horizontal, 8)
                    
                    reorderChildrenButton
                        .padding(.horizontal, 8)
                    
                    // Replaced Picker with buttons for edge type selection
                    HStack(spacing: 8) {
                        edgeTypeButton(type: .association)
                        edgeTypeButton(type: .hierarchy)
                    }
                    .padding(.horizontal, 8)
                }
                
                // Edit Section: Split into multiple rows to prevent wrapping
                Text("Edit").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                HStack(spacing: 8) {
                    editContentsButton
                    deleteNodeButton
                }
                .padding(.horizontal, 8)
                
                // Second row: Collapse and collapsibility toggle
                if isToggleNode {
                    HStack(spacing: 8) {
                        toggleExpandButton
                        toggleCollapsibilityButton
                    }
                    .padding(.horizontal, 8)
                } else {
                    toggleCollapsibilityButton
                        .padding(.horizontal, 8)
                }
            }
            .padding(4)
        }
        .accessibilityIdentifier("nodeMenuGrid")
        .navigationTitle("Node \(nodeLabel)")  // Dynamic name in top-right
        .focused($isMenuFocused)
        .onAppear {
            isMenuFocused = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                isMenuFocused = true
            }
            Self.logger.debug("Node Menu appeared: selectedNodeID=\(selectedNodeID?.uuidString.prefix(8) ?? "nil")")
        }
        .onChange(of: isMenuFocused) { _, newValue in
            Self.logger.debug("Node Menu focus: \(newValue)")
            if !newValue {
                isMenuFocused = true
            }
        }
        .ignoresSafeArea(.keyboard)
    }
    
    // Edge type button (same as NodeMenuView)
    private func edgeTypeButton(type: GraphEditorShared.EdgeType) -> some View {
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
    
    private var addChildButton: some View {
        MenuButton(
            action: {
                if let id = selectedNodeID {
                    Task { await viewModel.model.addToggleChild(to: id) }
                }
                onDismiss()
            },
            label: {
                Label("Child", systemImage: "plus.square.fill")
            },
            accessibilityIdentifier: "addChildButton"
        )
    }
    
    private var reorderChildrenButton: some View {
        MenuButton(
            action: {
                // FUTURE: Implement reordering (e.g., present a draggable list of child IDs)
                Self.logger.debug("Reorder children triggered for node \(nodeLabel)")
                onDismiss()
            },
            label: {
                Label("Reorder", systemImage: "arrow.up.and.down")
            },
            accessibilityIdentifier: "reorderChildrenButton"
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
    
    private var editContentsButton: some View {
        NavigationLink(destination: EditContentSheet(
            selectedID: selectedNodeID ?? NodeID(),
            viewModel: viewModel,
            onSave: { newContents in
                if let id = selectedNodeID {
                    Task { await viewModel.model.updateNodeContents(withID: id, newContents: newContents) }
                }
            }
        )
            .environment(\.disableCanvasFocus, true)  // NEW: Set flag on destination
        ) {
            Label("Contents", systemImage: "pencil")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("editContentsButton")
    }
    
    private var toggleExpandButton: some View {
        Group {
            if let toggleNode = viewModel.model.collapsibleNode(with: selectedNodeID) {
                MenuButton(
                    action: {
                        Task { await viewModel.toggleSelectedNode() }
                        onDismiss()
                    },
                    label: {
                        Label(toggleNode.isExpanded ? "Collapse" : "Expand",
                              systemImage: toggleNode.isExpanded ? "chevron.up" : "chevron.down")
                    },
                    accessibilityIdentifier: "toggleExpandCollapseButton"
                )
            }
            // else branch is implicitly EmptyView() → Group handles the type mismatch perfectly
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
    
    private var toggleCollapsibilityButton: some View {
        MenuButton(
            action: {
                if let id = selectedNodeID {
                    Task {
                        await viewModel.model.toggleNodeCollapsibility(nodeID: id)
                    }
                }
                onDismiss()
            },
            label: {
                Label(isToggleNode ? "Make Simple" : "Make Collapsible",
                      systemImage: isToggleNode ? "circle" : "circle.fill")
            },
            accessibilityIdentifier: "toggleCollapsibilityButton"
        )
    }
}
