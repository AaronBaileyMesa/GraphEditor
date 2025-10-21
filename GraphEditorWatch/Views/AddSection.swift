//
//  AddSection.swift
//  GraphEditor
//
//  Created by handcart on 10/5/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared

struct AddSection: View {
    let viewModel: GraphViewModel
    let selectedNodeID: NodeID?
    let onDismiss: () -> Void
    let onAddEdge: (EdgeType) -> Void
    
    @State private var selectedEdgeType: EdgeType = .association
    
    var body: some View {
        Group {
            addNodeButton
            addToggleNodeButton
            if selectedNodeID != nil {
                addChildButton
                edgeTypePicker
                addEdgeButton
            }
        }
    }
    
    private var addNodeButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            Task { await viewModel.addNode(at: .zero) }
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
            Task { await viewModel.addToggleNode(at: .zero) }
            onDismiss()
        } label: {
            Label("Toggle Node", systemImage: "plus.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("addToggleNodeButton")
    }
    
    private var addChildButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            if let id = selectedNodeID {
                Task { await viewModel.addChild(to: id) }
            }
            onDismiss()
        } label: {
            Label("Child", systemImage: "plus.square")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("addChildButton")
    }
    
    private var edgeTypePicker: some View {
        Picker("Type", selection: $selectedEdgeType) {
            Text("Assoc").tag(EdgeType.association)
            Text("Hier").tag(EdgeType.hierarchy)
        }
        .font(.caption)
        .accessibilityLabel("Select edge type: \(selectedEdgeType.rawValue)")
        .gridCellColumns(2)  // Span for better layout
    }
    
    private var addEdgeButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            onAddEdge(selectedEdgeType)
            onDismiss()
        } label: {
            Label("Edge", systemImage: "arrow.right.circle")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .disabled(selectedNodeID == nil)
        .accessibilityIdentifier("addEdgeButton")
    }
}
