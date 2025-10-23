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
    let onCenterGraph: () -> Void
    @Binding var showMenu: Bool
    @Binding var showOverlays: Bool
    let onDismiss: () -> Void
    
    @FocusState private var isMenuFocused: Bool
    
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "graphmenuview")
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Add").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                HStack(spacing: 8) {  // Standardize with NodeMenuView
                    addNodeButton
                    addToggleNodeButton
                }
                .padding(.horizontal, 8)
                
                Text("View").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                HStack(spacing: 8) {
                    overlaysToggle
                    simulationToggle
                }
                .padding(.horizontal, 8)
                
                Text("Graph").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                HStack(spacing: 8) {
                    centerButton
                    // Add other graph actions if needed (e.g., reset from GraphSection)
                }
                .padding(.horizontal, 8)
            }
            .padding(4)
        }
        .accessibilityIdentifier("graphMenuGrid")
        .navigationTitle("Graph")
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
    
    // Extracted buttons for clarity (adapt from AddSection/ViewSection)
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
    
    private var overlaysToggle: some View {
        Toggle(isOn: $showOverlays) {
            Label("Overlays", systemImage: "eye")
                .labelStyle(.titleAndIcon)
                .font(.caption)
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
    
    private var centerButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            onCenterGraph()
            onDismiss()
        } label: {
            Label("Center", systemImage: "scope")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("centerButton")
    }
}
