//
//  EdgeMenuView.swift
//  GraphEditor
//
//  Created by handcart on 10/21/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared
import os

struct EdgeMenuView: View {
    let viewModel: GraphViewModel
    let isSimulatingBinding: Binding<Bool>
    let onCenterGraph: () -> Void  // Retained but unused; can remove if not needed
    @Binding var showMenu: Bool
    @Binding var showOverlays: Bool  // Retained but unused
    @Binding var selectedEdgeID: UUID?
    let onDismiss: () -> Void
    
    @FocusState private var isMenuFocused: Bool
    
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "edgemenuview")
    
    // Fetch edge details for header and title (adapted from EditSection)
    private var edgeDescription: String {
        if let id = selectedEdgeID, let edge = viewModel.model.edges.first(where: { $0.id == id }),
           let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
           let toNode = viewModel.model.nodes.first(where: { $0.id == edge.target }) {
            return "\(fromNode.label) → \(toNode.label) (\(edge.type.rawValue))"
        }
        return "Unknown"
    }
    
    // Fetch the selected edge for button logic
    private var selectedEdge: GraphEdge? {
        if let id = selectedEdgeID {
            return viewModel.model.edges.first { $0.id == id }
        }
        return nil
    }
    
    // Check if bidirectional for delete label
    private var isBidirectional: Bool {
        if let edge = selectedEdge {
            return viewModel.model.isBidirectionalBetween(edge.from, edge.target)
        }
        return false
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    // Delete button (icon only, with accessibility)
                    deleteEdgeButton
                    
                    // Reverse button (icon only, with accessibility, only if hierarchy)
                    if let edge = selectedEdge, edge.type == .hierarchy {
                        reverseEdgeButton
                    }
                }
                .padding(.horizontal, 8)  // Ensure buttons don't touch edges
            }
            .padding(4)
        }
        .accessibilityIdentifier("edgeMenuGrid")
        .navigationTitle("Edge: \(edgeDescription)")  // Dynamic name in top-right
        .focused($isMenuFocused)
        .onAppear {
            isMenuFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMenuFocused = true
            }
            Self.logger.debug("Edge Menu appeared: selectedEdgeID=\(selectedEdgeID?.uuidString.prefix(8) ?? "nil")")
        }
        .onChange(of: isMenuFocused) { _, newValue in
            Self.logger.debug("Edge Menu focus: \(newValue)")
            if !newValue {
                isMenuFocused = true
            }
        }
        .ignoresSafeArea(.keyboard)
    }
    
    private var deleteEdgeButton: some View {
        Button(role: .destructive) {
            WKInterfaceDevice.current().play(.click)
            if let edge = selectedEdge {
                Task {
                    _ = true  // Use local or @State if needed for disabling
                    await viewModel.model.snapshot()
                    if isBidirectional {
                        let pair = viewModel.model.edgesBetween(edge.from, edge.target)
                        viewModel.model.edges.removeAll { pair.contains($0) }
                    } else {
                        viewModel.model.edges.removeAll { $0.id == selectedEdgeID }
                    }
                    await viewModel.model.startSimulation()
                    viewModel.setSelectedEdge(nil)
                    // Clear node selection if mixed
                    viewModel.setSelectedNode(nil)
                }
            }
            onDismiss()
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 20))  // Adjust size for watchOS
        }
        .buttonStyle(.borderedProminent)  // Makes it round/compact
        .tint(.red)  // Destructive color
        .accessibilityLabel(isBidirectional ? "Delete Both Edges" : "Delete Edge")
        .accessibilityIdentifier("deleteEdgeButton")
    }
    
    private var reverseEdgeButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            if let edge = selectedEdge {
                Task {
                    _ = true
                    await viewModel.model.snapshot()
                    viewModel.model.edges.removeAll { $0.id == selectedEdgeID }
                    viewModel.model.edges.append(GraphEdge(from: edge.target, target: edge.from, type: .hierarchy))
                    await viewModel.model.startSimulation()
                    viewModel.setSelectedEdge(nil)
                    viewModel.setSelectedNode(nil)
                }
            }
            onDismiss()
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 20))
        }
        .buttonStyle(.bordered)
        .tint(.gray)  // Neutral color
        .accessibilityLabel("Reverse Edge")
        .accessibilityIdentifier("reverseEdgeButton")
    }
}
