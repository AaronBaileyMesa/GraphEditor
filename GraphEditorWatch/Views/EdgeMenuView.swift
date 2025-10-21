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
    
    // Fetch edge details for header (adapted from EditSection)
    private var edgeDescription: String {
        if let id = selectedEdgeID, let edge = viewModel.model.edges.first(where: { $0.id == id }),
           let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
           let toNode = viewModel.model.nodes.first(where: { $0.id == edge.target }) {
            return "\(fromNode.label) → \(toNode.label) (\(edge.type.rawValue))"
        }
        return "Unknown"
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                Text("Edge: \(edgeDescription)").font(.subheadline.bold()).gridCellColumns(2)  // Name as first item
                
                Text("Edit").font(.subheadline.bold()).gridCellColumns(2)
                EditSection(
                    viewModel: viewModel,
                    selectedNodeID: nil,  // No node focus
                    selectedEdgeID: selectedEdgeID,
                    onDismiss: onDismiss,
                    onEditNode: {}
                )
            }
            .padding(4)
        }
        .accessibilityIdentifier("edgeMenuGrid")
        .navigationTitle("Edge Menu")  // Differentiate for testing
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
}
