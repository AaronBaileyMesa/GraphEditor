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
            customOverlaysToggle
            customSimulationToggle
            centerButton
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("View section")
    }
    
    private var customOverlaysToggle: some View {
        HStack(spacing: 4) {
            Image(systemName: "eye")
                .font(.caption)
            Text("Overlays")
                .font(.caption)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Spacer()
            Toggle("", isOn: $showOverlays)
                .labelsHidden()
        }
        .onChange(of: showOverlays) {
            WKInterfaceDevice.current().play(.click)
            onDismiss()
        }
        .gridCellColumns(2)
        .accessibilityLabel("Overlays toggle")
    }
    
    private var customSimulationToggle: some View {
        HStack(spacing: 4) {
            Image(systemName: "play")
                .font(.caption)
            Text("Simulate")
                .font(.caption)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Spacer()
            Toggle("", isOn: isSimulating)
                .labelsHidden()
        }
        .onChange(of: isSimulating.wrappedValue) {_, newValue in
            WKInterfaceDevice.current().play(.click)
            onSimulationChange(newValue)
            onDismiss()
        }
        .accessibilityIdentifier("toggleSimulation")
        .gridCellColumns(2)
        .accessibilityLabel("Simulate toggle")
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
        .gridCellColumns(2)
    }
}
