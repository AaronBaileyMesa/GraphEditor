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
                // Add Section: Side-by-side buttons with icons + text
                Text("Add").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                HStack(spacing: 8) {
                    addNodeButton
                    addToggleNodeButton
                }
                .padding(.horizontal, 8)
                
                if selectedNodeID != nil {
                    HStack(spacing: 8) {
                        addChildButton
                        addEdgeButton
                    }
                    .padding(.horizontal, 8)
                    
                    // Replaced Picker with buttons for edge type selection
                    HStack(spacing: 8) {
                        edgeTypeButton(type: .association)
                        edgeTypeButton(type: .hierarchy)
                    }
                    .padding(.horizontal, 8)
                }
                
                // Edit Section: Side-by-side buttons with icons + text (node-focused only)
                Text("Edit").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                HStack(spacing: 8) {
                    editContentsButton
                    deleteNodeButton
                }
                .padding(.horizontal, 8)
                
                if isToggleNode {
                    toggleExpandButton.padding(.horizontal, 8)  // Conditional for ToggleNode
                }
            }
            .padding(4)
        }
        .accessibilityIdentifier("nodeMenuGrid")
        .navigationTitle("Node \(nodeLabel)")  // Dynamic name in top-right
        .focused($isMenuFocused)
        .onAppear {
            isMenuFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
        .onChange(of: isAddingEdge) { _, newValue in
            if newValue {
                // Handle add-edge mode (same as original)
            }
        }
    }
    
    // NEW: Helper for edge type buttons
    private func edgeTypeButton(type: GraphEditorShared.EdgeType) -> some View {
        Button {
            selectedEdgeType = type
        } label: {
            Text(type == .association ? "Assoc" : "Hier")  // Use abbreviated labels
            .font(.caption2)
            .fontWeight(selectedEdgeType == type ? .bold : .regular)  // Use fontWeight for compatibility
            .foregroundColor(selectedEdgeType == type ? .blue : .gray)  // Highlight selected
        }
        .accessibilityLabel("Select \(type == .association ? "Association" : "Hierarchy") edge type")
    }
    
    // Extracted Add buttons (from AddSection)
    private var addNodeButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            Task { await viewModel.model.addNode(at: CGPoint.zero) }
            onDismiss()
        } label: {
            Label("Node", systemImage: "plus.circle")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("addNodeButton")
    }
    
    private var addToggleNodeButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            Task { await viewModel.model.addToggleNode(at: CGPoint.zero) }
            onDismiss()
        } label: {
            Label("Toggle", systemImage: "plus.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("addToggleNodeButton")
    }
    
    private var addChildButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            if let id = selectedNodeID {
                Task { await viewModel.model.addChild(to: id) }
            }
            onDismiss()
        } label: {
            Label("Child", systemImage: "plus.square")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("addChildButton")
    }
    
    private var addEdgeButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            viewModel.pendingEdgeType = selectedEdgeType
            isAddingEdge = true
            onDismiss()
        } label: {
            Label("Edge", systemImage: "arrow.right.circle")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .disabled(selectedNodeID == nil)
        .accessibilityIdentifier("addEdgeButton")
    }
    
    // Extracted Edit buttons (from EditSection, node-focused)
    private var editContentsButton: some View {
        NavigationLink(destination: EditContentSheet(
            selectedID: selectedNodeID ?? NodeID(),
            viewModel: viewModel,
            onSave: { newContents in
                if let id = selectedNodeID {
                    Task { await viewModel.model.updateNodeContents(withID: id, newContents: newContents) }
                }
            }
        )) {
            Label("Contents", systemImage: "pencil")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("editContentsButton")
    }
    
    private var toggleExpandButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            Task { await viewModel.toggleSelectedNode() }
            onDismiss()
        } label: {
            Label("Toggle", systemImage: "arrow.up.arrow.down")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("toggleExpandCollapseButton")
    }
    
    private var deleteNodeButton: some View {
        Button(role: .destructive) {
            WKInterfaceDevice.current().play(.click)
            if let id = selectedNodeID {
                Task {
                    await viewModel.model.deleteNode(withID: id)
                    viewModel.setSelectedNode(nil)
                }
            }
            onDismiss()
        } label: {
            Label("Delete", systemImage: "trash")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("deleteNodeButton")
    }
}
