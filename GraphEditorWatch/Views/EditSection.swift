//
//  EditSection.swift
//  GraphEditor
//
//  Created by handcart on 10/5/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared

struct EditSection: View {
    let viewModel: GraphViewModel
    let selectedNodeID: NodeID?
    let selectedEdgeID: UUID?
    let onDismiss: () -> Void
    let onEditNode: () -> Void
    
    @State private var isProcessing = false
    
    private func findSelectedEdge() -> GraphEdge? {
        viewModel.model.edges.first { $0.id == selectedEdgeID }
    }
    
    private func clearSelections() {
        viewModel.setSelectedNode(nil)
        viewModel.setSelectedEdge(nil)
    }
    
    var body: some View {
        Group {
            if let selectedID = selectedNodeID {
                editContentsLink
                if viewModel.isSelectedToggleNode {
                    toggleExpandButton
                }
                deleteNodeButton
            }
            if let selectedEdgeID = selectedEdgeID,
               let selectedEdge = findSelectedEdge() {
                edgeInfoText(selectedEdge: selectedEdge)
                deleteEdgeButton(selectedEdge: selectedEdge)
                if selectedEdge.type == .hierarchy {
                    reverseEdgeButton(selectedEdge: selectedEdge)
                }
            }
        }
        .foregroundColor(isProcessing ? .gray : .primary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Edit section")
    }
    
    private func edgeInfoText(selectedEdge: GraphEdge) -> some View {
        let fromID = selectedEdge.from
        let targetID = selectedEdge.target
        let fromLabel = viewModel.model.nodes.first(where: { $0.id == fromID })?.label ?? 0
        let toLabel = viewModel.model.nodes.first(where: { $0.id == targetID })?.label ?? 0
        return Text("\(fromLabel) → \(toLabel) (\(selectedEdge.type.rawValue))")
            .font(.caption2)
            .foregroundColor(.secondary)
            .gridCellColumns(2)
            .accessibilityLabel("Edge info")
    }
    
    private var editContentsLink: some View {
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
                    isProcessing = true
                    await viewModel.model.deleteNode(withID: id)
                    clearSelections()
                    isProcessing = false
                }
            }
            onDismiss()
        } label: {
            Label("Del Node", systemImage: "trash")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .disabled(isProcessing)
        .accessibilityIdentifier("deleteNodeButton")
    }
    
    private func deleteEdgeButton(selectedEdge: GraphEdge) -> some View {
        let fromID = selectedEdge.from
        let targetID = selectedEdge.target
        let isBi = viewModel.model.isBidirectionalBetween(fromID, targetID)
        return Button(role: .destructive) {
            WKInterfaceDevice.current().play(.click)
            Task {
                isProcessing = true
                await viewModel.model.snapshot()
                if isBi {
                    let pair = viewModel.model.edgesBetween(fromID, targetID)
                    viewModel.model.edges.removeAll { pair.contains($0) }
                } else {
                    viewModel.model.edges.removeAll { $0.id == selectedEdgeID }
                }
                await viewModel.model.startSimulation()
                clearSelections()
                isProcessing = false
            }
            onDismiss()
        } label: {
            Label(isBi ? "Del Both" : "Del Edge", systemImage: "trash.slash")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .disabled(isProcessing)
        .accessibilityIdentifier("deleteEdgeButton")
    }
    
    private func reverseEdgeButton(selectedEdge: GraphEdge) -> some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            Task {
                isProcessing = true
                await viewModel.model.snapshot()
                viewModel.model.edges.removeAll { $0.id == selectedEdgeID }
                viewModel.model.edges.append(GraphEdge(from: selectedEdge.target, target: selectedEdge.from, type: .hierarchy))
                await viewModel.model.startSimulation()
                clearSelections()
                isProcessing = false
            }
            onDismiss()
        } label: {
            Label("Reverse", systemImage: "arrow.left.arrow.right")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .disabled(isProcessing)
        .accessibilityIdentifier("reverseNodeButton")
    }
}
