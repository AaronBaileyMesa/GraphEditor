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
                    // Add other actions if in original (e.g., save/load)
                    manageGraphsButton
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
    
    // Private var for the button
    private var manageGraphsButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            showGraphsMenu = true
        } label: {
            Label("Manage", systemImage: "folder.badge.gear")  // Icon for "manage graphs"
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("manageGraphsButton")
        .sheet(isPresented: $showGraphsMenu) {  // Present as sheet for easy dismissal
            GraphsMenuView(
                viewModel: viewModel,
                onDismiss: {
                    showGraphsMenu = false
                    onDismiss()  // Optional: Dismiss parent menu if needed
                }
            )
        }
    }
    
    // Add buttons
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
    
    // View toggles (adapted from ViewSection)
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
    
    // Graph actions (from GraphSection; example reset button – adjust to match original)
    private var resetGraphButton: some View {
        Button(role: .destructive) {
            WKInterfaceDevice.current().play(.click)
            Task {
                await viewModel.model.resetGraph()  // Assume this exists; adjust method name
            }
            onDismiss()
        } label: {
            Label("Reset", systemImage: "arrow.counterclockwise")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("resetGraphButton")
    }
}
