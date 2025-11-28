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
    
    let viewSize: CGSize
    @Binding var panStartOffset: CGSize?
    @Binding var showMenu: Bool
    let onUpdateZoomRanges: () -> Void
    @Binding var isAddingEdge: Bool
    @Binding var isSimulating: Bool
    @Binding var saturation: Double
    @Binding var crownPosition: Double
    private var logicalViewSize: CGSize {
        AppConstants.logicalCanvasSize
    }
    
    private var logicalViewOffset: CGSize {
        let physical = viewSize
        let logical = logicalViewSize
        let extraX = (physical.width - logical.width) * 0.5
        let extraY = (physical.height - logical.height) * 0.5
        return CGSize(width: extraX, height: extraY)
    }
    
    private var effectiveOffset: CGSize {
        CGSize(
            width: viewModel.offset.x + logicalViewOffset.width,
            height: viewModel.offset.y + logicalViewOffset.height
        )
    }
    
    private var minZoom: CGFloat { AppConstants.defaultMinZoom }
    private var maxZoom: CGFloat { AppConstants.defaultMaxZoom }
    
    init(
        viewModel: GraphViewModel,
        draggedNode: Binding<(any NodeProtocol)?>,
        dragOffset: Binding<CGPoint>,
        potentialEdgeTarget: Binding<(any NodeProtocol)?>,
        selectedNodeID: Binding<NodeID?>,
        selectedEdgeID: Binding<UUID?>,
        viewSize: CGSize,
        panStartOffset: Binding<CGSize?>,
        showMenu: Binding<Bool>,
        onUpdateZoomRanges: @escaping () -> Void,
        isAddingEdge: Binding<Bool>,
        isSimulating: Binding<Bool>,
        saturation: Binding<Double>,
        crownPosition: Binding<Double>     // ← renamed here
    ) {
        self.viewModel = viewModel
        self._draggedNode = draggedNode
        self._dragOffset = dragOffset
        self._potentialEdgeTarget = potentialEdgeTarget
        self._selectedNodeID = selectedNodeID
        self._selectedEdgeID = selectedEdgeID
        self.viewSize = viewSize
        self._panStartOffset = panStartOffset
        self._showMenu = showMenu
        self.onUpdateZoomRanges = onUpdateZoomRanges
        self._isAddingEdge = isAddingEdge
        self._isSimulating = isSimulating
        self._saturation = saturation
        self._crownPosition = crownPosition   // ← use new name
    }
    
    var body: some View {
        FocusableView {
            AccessibleCanvas(
                viewModel: viewModel,
                zoomScale: viewModel.zoomScale,
                offset: effectiveOffset,
                draggedNode: draggedNode,
                dragOffset: dragOffset,
                potentialEdgeTarget: potentialEdgeTarget,
                selectedNodeID: selectedNodeID,
                viewSize: viewSize,
                logicalViewSize: logicalViewSize,
                selectedEdgeID: selectedEdgeID,
                showOverlays: false,
                saturation: saturation
            )
            .modifier(GraphGesturesModifier(
                viewModel: viewModel,
                zoomScale: $viewModel.zoomScale,
                offset: Binding(
                    get: { CGSize(width: viewModel.offset.x, height: viewModel.offset.y) },
                    set: { viewModel.offset = CGPoint(x: $0.width, y: $0.height) }
                ),
                draggedNode: $draggedNode,
                dragOffset: $dragOffset,
                potentialEdgeTarget: $potentialEdgeTarget,
                selectedNodeID: $selectedNodeID,
                selectedEdgeID: $selectedEdgeID,
                viewSize: viewSize,
                panStartOffset: $panStartOffset,
                showMenu: $showMenu,
                maxZoom: maxZoom,
                crownPosition: $crownPosition,
                onUpdateZoomRanges: onUpdateZoomRanges,
                isAddingEdge: $isAddingEdge,
                isSimulating: $isSimulating,
                saturation: $saturation
            ))
        }
        .focusable()
        
        // MARK: Crown → Zoom (now lives in the only place that has the real binding)
        .onChange(of: $crownPosition.wrappedValue) { newValue in
            let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
            let normalized = (newValue / Double(AppConstants.crownZoomSteps)).clamped(to: 0...1)
            let targetZoom = minZoom + (maxZoom - minZoom) * CGFloat(normalized)
            
            withAnimation(.easeOut(duration: 0.08)) {
                viewModel.zoomScale = targetZoom
            }
        }
        
        // MARK: Zoom → Crown (feedback so crown "sticks" when you pinch/zoom)
        .onChange(of: viewModel.zoomScale) { newZoom in
            let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
            let normalized = ((newZoom - minZoom) / (maxZoom - minZoom)).clamped(to: 0...1)
            let targetCrown = Double(AppConstants.crownZoomSteps) * normalized
            
            if abs(targetCrown - $crownPosition.wrappedValue) > 0.5 {
                $crownPosition.wrappedValue = targetCrown
            }
        }
    }
}

