//
//  ViewSection.swift
//  GraphEditor
//
//  Created by handcart on 10/5/25.
//

import SwiftUI
import WatchKit

struct ViewSection: View {
    @Binding var showOverlays: Bool
    let isSimulating: Binding<Bool>
    let onCenterGraph: () -> Void
    let onDismiss: () -> Void
    let onSimulationChange: (Bool) -> Void
    
    var body: some View {
        Group {
            overlaysToggle
            simulationToggle
            centerButton
        }
        .accessibilityLabel("View section")
    }
    
    private var overlaysToggle: some View {
        Toggle(isOn: $showOverlays) {
            Label("Overlays", systemImage: "eye")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .onChange(of: showOverlays) { _ in
            WKInterfaceDevice.current().play(.click)
            onDismiss()
        }
    }
    
    private var simulationToggle: some View {
        Toggle(isOn: isSimulating) {
            Label("Simulate", systemImage: "play")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .onChange(of: isSimulating.wrappedValue) { newValue in
            WKInterfaceDevice.current().play(.click)
            onSimulationChange(newValue)
            onDismiss()
        }
        .accessibilityIdentifier("toggleSimulation")
    }
    
    private var centerButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            onCenterGraph()
            onDismiss()
        } label: {
            Label("Center", systemImage: "dot.circle")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("centerGraphButton")
    }
}
