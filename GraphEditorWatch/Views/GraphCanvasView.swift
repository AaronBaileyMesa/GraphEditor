//
//  GraphCanvasView.swift
//  GraphEditorWatch
//

import SwiftUI
import WatchKit
import GraphEditorShared

struct GraphCanvasView: View {
    @ObservedObject var viewModel: GraphViewModel
    
    @Binding var draggedNode: (any NodeProtocol)?
    @Binding var dragOffset: CGPoint
    @Binding var potentialEdgeTarget: (any NodeProtocol)?
    @Binding var selectedNodeID: NodeID?
    @Binding var selectedEdgeID: UUID?
    
    @Binding var viewSize: CGSize
    @Binding var panStartOffset: CGSize?
    @Binding var showMenu: Bool
    let onUpdateZoomRanges: () -> Void
    @Binding var isAddingEdge: Bool
    @Binding var isSimulating: Bool
    @Binding var saturation: Double
    @Binding var currentDragLocation: CGPoint?  // NEW
    @Binding var dragStartNode: (any NodeProtocol)?  // NEW
    @State private var crownPosition: Double = Double(AppConstants.crownZoomSteps) / 2.0
    
    // NEW: Flag to prevent recursive onChange calls (breaks feedback loop)
    @State private var isUpdatingZoom: Bool = false
    
    private var renderContext: RenderContext {
        RenderContext(
            effectiveCentroid: viewModel.effectiveCentroid,
            zoomScale: viewModel.zoomScale,
            offset: viewModel.offset,
            viewSize: viewSize
        )
    }

    var body: some View {
        FocusableView {
            AccessibleCanvas(
                viewModel: viewModel,
                zoomScale: viewModel.zoomScale,
                offset: viewModel.offset,
                draggedNode: draggedNode,
                dragOffset: dragOffset,
                potentialEdgeTarget: potentialEdgeTarget,
                selectedNodeID: selectedNodeID,
                viewSize: viewSize,
                selectedEdgeID: selectedEdgeID,
                showOverlays: false,
                saturation: saturation,
                currentDragLocation: currentDragLocation,
                isAddingEdge: isAddingEdge,
                dragStartNode: dragStartNode
            )
            .modifier(GraphGesturesModifier(
                viewModel: viewModel,
                renderContext: renderContext,
                zoomScale: $viewModel.zoomScale,
                offset: $viewModel.offset,
                draggedNode: $draggedNode,
                dragOffset: $dragOffset,
                potentialEdgeTarget: $potentialEdgeTarget,
                selectedNodeID: $selectedNodeID,
                selectedEdgeID: $selectedEdgeID,
                viewSize: viewSize,
                panStartOffset: $panStartOffset,
                showMenu: $showMenu,
                maxZoom: AppConstants.defaultMaxZoom,
                crownPosition: $crownPosition,
                onUpdateZoomRanges: onUpdateZoomRanges,
                isAddingEdge: $isAddingEdge,
                isSimulating: $isSimulating,
                saturation: $saturation,
                currentDragLocation: $currentDragLocation,
                dragStartNode: $dragStartNode
            ))
        }
        .digitalCrownRotation(
            $crownPosition,
            from: 0.0,
            through: Double(AppConstants.crownZoomSteps),
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: false
        )
        .onChange(of: crownPosition) { oldValue, newValue in
            guard !isUpdatingZoom else { return }  // NEW: Guard against re-entrancy
            isUpdatingZoom = true  // Set flag
            defer { isUpdatingZoom = false }  // Reset after execution
            
            let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
            let normalized = (newValue / Double(AppConstants.crownZoomSteps)).clamped(to: 0...1)
            let targetZoom = minZoom + (maxZoom - minZoom) * CGFloat(normalized)
            withAnimation(.easeOut(duration: 0.08)) { viewModel.zoomScale = targetZoom }
        }
        // In GraphCanvasView.swift's .onChange(of: viewModel.zoomScale)
        .onChange(of: viewModel.zoomScale) { _, userZoom in
            guard !isUpdatingZoom else { return }  // Existing guard
            isUpdatingZoom = true
            defer { isUpdatingZoom = false }
            
            guard viewSize.width > 50 else { return }
            let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
            let normalized = ((userZoom - minZoom) / (maxZoom - minZoom)).clamped(to: 0...1)
            let targetCrown = round(Double(AppConstants.crownZoomSteps) * normalized * 10) / 10  // NEW: Round to 1 decimal (adjust precision as needed; avoids float drift)
            if abs(targetCrown - crownPosition) > 1.5 {  // Increased from 1.0 to 1.5 for more damping
                crownPosition = targetCrown
            }
        }
        .background(GeometryReader { geo in
            Color.clear.onAppear { viewSize = geo.size }
                .onChange(of: geo.size) { _, newValue in viewSize = newValue }
        })
    }
}
