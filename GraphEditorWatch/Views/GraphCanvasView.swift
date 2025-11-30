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
    @Binding var crownPosition: Double
    @Binding var currentDragLocation: CGPoint?  // NEW
    @Binding var dragStartNode: (any NodeProtocol)?  // NEW

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
                currentDragLocation: currentDragLocation,  // No $ since it's already a Binding
                    isAddingEdge: isAddingEdge,  // Already exists, but ensure it's passed
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
                    dragStartNode: $dragStartNode  // Will become @Binding in GraphGesturesModifier
            ))
        }
        .background(GeometryReader { geo in
                    Color.clear.onAppear { viewSize = geo.size }
                        .onChange(of: geo.size) { _, newValue in viewSize = newValue }
                })
        .focusable()
        
        // Inside GraphCanvasView.body
        .onChange(of: crownPosition) { _, newValue in
            let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize) // ← REAL size
            let normalized = (newValue / Double(AppConstants.crownZoomSteps)).clamped(to: 0...1)
            let targetZoom = minZoom + (maxZoom - minZoom) * CGFloat(normalized)
            
            withAnimation(.easeOut(duration: 0.08)) {
                viewModel.zoomScale = targetZoom
            }
        }

        .onChange(of: viewModel.zoomScale) { _, userZoom in
            guard viewSize.width > 50 else { return }
            let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
            let normalized = ((userZoom - minZoom) / (maxZoom - minZoom)).clamped(to: 0...1)
            let targetCrown = Double(AppConstants.crownZoomSteps) * normalized
            if abs(targetCrown - crownPosition) > 0.5 {
                crownPosition = targetCrown
            }
        }
    }
}
