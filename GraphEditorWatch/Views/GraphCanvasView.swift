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
    let onUpdateZoomRanges: (CGFloat, CGFloat) -> Void  // Changed to match AccessibleCanvas and usage
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
        // FIXED: Don't wrap in FocusableView - it interferes with gesture recognition
        // Apply gestures and focus modifiers directly to the canvas
        AccessibleCanvas(
            viewModel: viewModel,
            zoomScale: viewModel.zoomScale,
            offset: viewModel.offset,
            draggedNode: draggedNode,
            dragOffset: dragOffset,
            potentialEdgeTarget: potentialEdgeTarget,
            selectedNodeID: selectedNodeID,
            selectedEdgeID: selectedEdgeID,
            viewSize: viewSize,
            showOverlays: false,
            saturation: saturation,
            currentDragLocation: currentDragLocation,
            isAddingEdge: isAddingEdge,
            dragStartNode: dragStartNode,
            onUpdateZoomRanges: onUpdateZoomRanges
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
            onUpdateZoomRanges: {
                let (min, max) = viewModel.calculateZoomRanges(for: viewSize)
                onUpdateZoomRanges(min, max)
            },
            isAddingEdge: $isAddingEdge,
            isSimulating: $isSimulating,
            saturation: $saturation,
            currentDragLocation: $currentDragLocation,
            dragStartNode: $dragStartNode
        ))
        .focusable(true)
        .digitalCrownRotation(
            $crownPosition,
            from: 0.0,
            through: Double(AppConstants.crownZoomSteps),
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: false
        )
        .onChange(of: crownPosition) { oldValue, newValue in
            guard !isUpdatingZoom else { return }
            isUpdatingZoom = true
            defer { isUpdatingZoom = false }
            
            let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
            let normalized = (newValue / Double(AppConstants.crownZoomSteps)).clamped(to: 0...1)
            let targetZoom = minZoom + (maxZoom - minZoom) * CGFloat(normalized)
            withAnimation(.easeOut(duration: 0.08)) { viewModel.zoomScale = targetZoom }
        }
        .onChange(of: viewModel.zoomScale) { _, userZoom in
            guard !isUpdatingZoom else { return }
            isUpdatingZoom = true
            defer { isUpdatingZoom = false }
            
            guard viewSize.width > 50 else { return }
            let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
            let normalized = ((userZoom - minZoom) / (maxZoom - minZoom)).clamped(to: 0...1)
            let targetCrown = round(Double(AppConstants.crownZoomSteps) * normalized * 10) / 10
            if abs(targetCrown - crownPosition) > 1.5 {
                crownPosition = targetCrown
            }
        }
        .onChange(of: selectedNodeID) { _, newID in
            if let id = newID, let dragged = draggedNode, dragged.id == id {
                viewModel.repositionEphemerals(for: id, to: dragged.position)
            }
        }
        /*
        .onChange(of: selectedNodeID) { oldID, newID in
            if let id = newID {
                Task {
                    await viewModel.generateControls(for: id)
                }
            } else {
                Task {
                    await viewModel.clearControls()
                }
            }
            // NEW: If dragging a newly selected node, reposition immediately
            if let dragged = draggedNode, dragged.id == newID {
                viewModel.repositionEphemerals(for: newID!, to: dragged.position)
            }
        }
        */
        
        .background(GeometryReader { geo in
            Color.clear.onAppear { viewSize = geo.size }
                .onChange(of: geo.size) { _, newValue in viewSize = newValue }
        })
    }
}
