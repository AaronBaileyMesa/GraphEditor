//
//  ViewSection.swift
//  GraphEditor
//
//  Created by handcart on 10/5/25.
//

import SwiftUI

struct ViewSection: View {
    @Binding var showOverlays: Bool
    let isSimulating: Binding<Bool>
    let onCenterGraph: () -> Void
    let onDismiss: () -> Void
    let onSimulationChange: (Bool) -> Void
    
    var body: some View {
        Section(header: Text("View")) {
            Toggle("Show Overlays", isOn: $showOverlays)
                .onSubmit { /* No-op for toggle */ }
            
            Toggle("Run Simulation", isOn: isSimulating)
                .onChange(of: isSimulating.wrappedValue) { _, newValue in
                    onSimulationChange(newValue)
                }
                .onSubmit { /* No-op for toggle */ }
            
            Button("Center Graph") {
                onCenterGraph()
                onDismiss()
            }
            .onSubmit { onCenterGraph(); onDismiss() }
        }
        .accessibilityLabel("View section")  // NEW: Accessibility
    }
}
