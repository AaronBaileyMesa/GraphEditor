//
//  SegmentLayoutSheet.swift
//  GraphEditor
//
//  Sheet for changing the layout direction of a graph segment
//

import SwiftUI
import GraphEditorShared

@available(watchOS 10.0, *)
struct SegmentLayoutSheet: View {
    let viewModel: GraphViewModel
    let segmentRootID: UUID
    let onDismiss: () -> Void
    
    @State private var selectedDirection: LayoutDirection
    
    init(viewModel: GraphViewModel, segmentRootID: UUID, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.segmentRootID = segmentRootID
        self.onDismiss = onDismiss
        
        // Initialize with current direction from segment config
        let currentConfig = viewModel.model.segmentConfigs[segmentRootID]
        self._selectedDirection = State(initialValue: currentConfig?.direction ?? .horizontal)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Layout Direction")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Direction selection buttons
                VStack(spacing: 8) {
                    // Horizontal option
                    Button {
                        selectedDirection = .horizontal
                    } label: {
                        HStack {
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 20))
                                .foregroundColor(selectedDirection == .horizontal ? .blue : .gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Horizontal")
                                    .font(.caption)
                                    .fontWeight(selectedDirection == .horizontal ? .semibold : .regular)
                                Text("Left-to-right flow")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedDirection == .horizontal {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedDirection == .horizontal ? .blue : .gray)
                    
                    // Vertical option
                    Button {
                        selectedDirection = .vertical
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.and.down")
                                .font(.system(size: 20))
                                .foregroundColor(selectedDirection == .vertical ? .green : .gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Vertical")
                                    .font(.caption)
                                    .fontWeight(selectedDirection == .vertical ? .semibold : .regular)
                                Text("Top-to-bottom flow")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedDirection == .vertical {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedDirection == .vertical ? .green : .gray)
                }
                
                // Apply button
                Button {
                    applyLayoutDirection()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Apply")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("Segment Layout")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func applyLayoutDirection() {
        Task { @MainActor in
            // Get current segment config to preserve other settings
            if let currentConfig = viewModel.model.segmentConfigs[segmentRootID] {
                // Update the segment config with new direction
                viewModel.model.setSegmentConfig(
                    rootNodeID: segmentRootID,
                    direction: selectedDirection,
                    strength: currentConfig.strength,
                    nodeSpacing: currentConfig.nodeSpacing
                )
                
                // Restart simulation to apply the new layout
                await viewModel.model.startSimulation()
            }
            
            onDismiss()
        }
    }
}
