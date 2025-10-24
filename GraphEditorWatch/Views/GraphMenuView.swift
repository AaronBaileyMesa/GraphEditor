//
//  GraphMenuView.swift
//  GraphEditor
//
//  Created by handcart on 10/21/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared
import os

struct GraphMenuView: View {
    let viewModel: GraphViewModel
    let isSimulatingBinding: Binding<Bool>
    @Binding var showMenu: Bool
    @Binding var showOverlays: Bool
    let onDismiss: () -> Void  // For consistency
    
    @FocusState private var isMenuFocused: Bool
    @State private var showGraphsMenu: Bool = false  // Added this @State as per comment
    
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "graphmenuview")
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Add Section (from AddSection, no edge/child since no selection)
                Text("Add").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                HStack(spacing: 8) {
                    addNodeButton
                    addToggleNodeButton
                }
                .padding(.horizontal, 8)
                
                // View Section
                Text("View").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                HStack(spacing: 8) {
                    overlaysToggle
                    simulationToggle
                }
                .padding(.horizontal, 8)
                
                // Graph Section (integrated: e.g., reset/clear actions; adjust based on original GraphSection code)
                Text("Graph").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                HStack(spacing: 8) {
                    resetGraphButton  // Example from GraphSection
                    manageGraphsButton
                }
                .padding(.horizontal, 8)
                
                // New: Undo/Redo row (conditional, like in GraphSection)
                if viewModel.canUndo || viewModel.canRedo {
                    HStack(spacing: 8) {
                        if viewModel.canUndo { undoButton }
                        if viewModel.canRedo { redoButton }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(4)
        }
        .accessibilityIdentifier("graphMenuGrid")
        .navigationTitle("Graph")  // Static name
        .focused($isMenuFocused)
        .onAppear {
            isMenuFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMenuFocused = true
            }
            Self.logger.debug("Graph Menu appeared")
        }
        .onChange(of: isMenuFocused) { _, newValue in
            Self.logger.debug("Graph Menu focus: \(newValue)")
            if !newValue {
                isMenuFocused = true
            }
        }
        .ignoresSafeArea(.keyboard)
    }
    
    private var manageGraphsButton: some View {
        MenuButton(
            action: {
                showGraphsMenu = true
            },
            label: {
                Label("Manage", systemImage: "folder.badge.gear")
            },
            accessibilityIdentifier: "manageGraphsButton"
        )
        .sheet(isPresented: $showGraphsMenu) {
            GraphsMenuView(
                viewModel: viewModel,
                onDismiss: {
                    showGraphsMenu = false
                    onDismiss()
                }
            )
        }
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
    
    private var overlaysToggle: some View {
        Toggle(isOn: $showOverlays) {
            Label("Overlays", systemImage: "eye")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .onChange(of: showOverlays) { newValue in
            // Any additional logic from ViewSection
        }
        .accessibilityIdentifier("overlaysToggle")
    }
    
    private var simulationToggle: some View {
        Toggle(isOn: isSimulatingBinding) {
            Label("Simulate", systemImage: "play.circle")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .onChange(of: isSimulatingBinding.wrappedValue) { newValue in
            viewModel.model.isSimulating = newValue
            if newValue {
                Task { await viewModel.model.startSimulation() }
            } else {
                Task { await viewModel.model.stopSimulation() }
            }
        }
        .accessibilityIdentifier("simulationToggle")
    }
    
    private var resetGraphButton: some View {
        MenuButton(
            action: {
                Task {
                    await viewModel.model.resetGraph()  // Assume this exists; adjust method name
                }
                onDismiss()
            },
            label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            },
            accessibilityIdentifier: "resetGraphButton",
            role: .destructive
        )
    }
    
    private var undoButton: some View {
        MenuButton(
            action: {
                Task { await viewModel.undo() }
                onDismiss()
            },
            label: {
                Label("Undo", systemImage: "arrow.uturn.left")
            },
            accessibilityIdentifier: "undoButton"
        )
    }
    
    private var redoButton: some View {
        MenuButton(
            action: {
                Task { await viewModel.redo() }
                onDismiss()
            },
            label: {
                Label("Redo", systemImage: "arrow.uturn.right")
            },
            accessibilityIdentifier: "redoButton"
        )
    }
}
