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
    @State private var showGraphsMenu: Bool = false
    @State private var showTacoWizard: Bool = false
    
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "graphmenuview")
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Add Section - Icon-only buttons in HStack
                Text("Add").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                HStack(spacing: 8) {
                    addNodeButton
                    addPersonButton
                    addTableButton
                    addTacoButton
                }
                .padding(.horizontal, 8)
                
                // View Section
                Text("View").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                VStack(spacing: 8) {  // Changed to VStack for vertical stacking on small screen
                    overlaysToggle
                    simulationToggle
                    layoutModeToggle
                }
                .padding(.horizontal, 8)
                
                // Graph Section (integrated: e.g., reset/clear actions; adjust based on original GraphSection code)
                Text("Graph").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                
                // Moved undo/redo here (before Reset/Manage) for desired order
                if viewModel.canUndo || viewModel.canRedo {
                    HStack(spacing: 8) {
                        if viewModel.canUndo { undoButton }
                        if viewModel.canRedo { redoButton }
                    }
                    .padding(.horizontal, 8)
                }
                
                HStack(spacing: 8) {
                    resetGraphButton  // Example from GraphSection
                    manageGraphsButton
                }
                .padding(.horizontal, 8)
                
                HStack(spacing: 8) {
                    homeButton
                }
                .padding(.horizontal, 8)
            }
            .padding(4)
        }
        .accessibilityIdentifier("graphMenuGrid")
        .navigationTitle("Graph")  // Static name
        .focused($isMenuFocused)
        .onAppear {
            isMenuFocused = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
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
            NavigationStack {
                GraphsMenuView(
                    viewModel: viewModel,
                    onDismiss: {
                        showGraphsMenu = false
                        onDismiss()
                    }
                )
            }
        }
    }
    
    private var addNodeButton: some View {
        Button {
            let centroid = viewModel.effectiveCentroid
            let offset = CGPoint(
                x: CGFloat.random(in: -80...80),
                y: CGFloat.random(in: -80...80)
            )
            let position = CGPoint(x: centroid.x + offset.x, y: centroid.y + offset.y)
            Task { await viewModel.model.addNode(at: position) }
            onDismiss()
        } label: {
            Image(systemName: "plus.circle")
                .font(.title2)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Add Node")
        .accessibilityIdentifier("addNodeButton")
    }
    
    private var addPersonButton: some View {
        Button {
            let centroid = viewModel.effectiveCentroid
            let offset = CGPoint(
                x: CGFloat.random(in: -80...80),
                y: CGFloat.random(in: -80...80)
            )
            let position = CGPoint(x: centroid.x + offset.x, y: centroid.y + offset.y)
            Task {
                _ = await viewModel.model.addPerson(
                    name: "New Person",
                    defaultSpiceLevel: nil,
                    dietaryRestrictions: [],
                    at: position
                )
            }
            onDismiss()
        } label: {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Add Person")
        .accessibilityIdentifier("addPersonButton")
    }
    
    private var addTableButton: some View {
        Button {
            let centroid = viewModel.effectiveCentroid
            let offset = CGPoint(
                x: CGFloat.random(in: -80...80),
                y: CGFloat.random(in: -80...80)
            )
            let position = CGPoint(x: centroid.x + offset.x, y: centroid.y + offset.y)
            Task {
                _ = await viewModel.model.addTable(
                    name: "Table",
                    at: position
                )
            }
            onDismiss()
        } label: {
            Image(systemName: "rectangle.fill")
                .font(.title2)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Add Table")
        .accessibilityIdentifier("addTableButton")
    }

    private var addTacoButton: some View {
        Button {
            showTacoWizard = true
        } label: {
            Image(systemName: "takeoutbag.and.cup.and.straw")
                .font(.title2)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Add Taco Night")
        .accessibilityIdentifier("addTacoButton")
        .sheet(isPresented: $showTacoWizard) {
            NavigationStack {
                TacoNightWizard(
                    viewModel: viewModel,
                    onDismiss: {
                        showTacoWizard = false
                        onDismiss()
                    }
                )
            }
        }
    }
    
    private var overlaysToggle: some View {
        Toggle(isOn: $showOverlays) {
            Label("Overlays", systemImage: "eye")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .onChange(of: showOverlays) { _, _ in
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
        .onChange(of: isSimulatingBinding.wrappedValue) { _, newValue in
            viewModel.model.isSimulating = newValue
            if newValue {
                Task { await viewModel.model.startSimulation() }
            } else {
                Task { await viewModel.model.stopSimulation() }
            }
        }
        .accessibilityIdentifier("simulationToggle")
    }
    
    private var layoutModeToggle: some View {
        Toggle(isOn: Binding(
            get: { viewModel.model.layoutMode == .hierarchy },
            set: { newValue in
                let mode: LayoutMode = newValue ? .hierarchy : .network
                viewModel.model.setLayoutMode(mode)
            }
        )) {
            Label("Tree Layout", systemImage: "arrow.up.left")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("layoutModeToggle")
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
    
    private var homeButton: some View {
        MenuButton(
            action: {
                viewModel.resetViewToRootNode(viewSize: viewModel.viewSize)
                onDismiss()
            },
            label: {
                Label("Home", systemImage: "house.fill")
            },
            accessibilityIdentifier: "homeButton"
        )
    }
}
