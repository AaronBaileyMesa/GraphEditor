import SwiftUI
import WatchKit
import GraphEditorShared
import os  // Added for logging

// Reverted: Custom wrapper for reliable crown focus (without crown—handled in ContentView now)
struct GraphCanvasView: View {
    private static var logger: Logger {
        Logger(subsystem: "io.handcart.GraphEditor", category: "graphcanvasview")  // Changed to computed static for consistency
    }
    
    let viewModel: GraphViewModel
    @Binding var zoomScale: CGFloat
    @Binding var offset: CGSize
    @Binding var draggedNode: (any NodeProtocol)?
    @Binding var dragOffset: CGPoint
    @Binding var potentialEdgeTarget: (any NodeProtocol)?
    @Binding var selectedNodeID: NodeID?
    let viewSize: CGSize
    @Binding var panStartOffset: CGSize?
    @Binding var showMenu: Bool
    let maxZoom: CGFloat
    @Binding var crownPosition: Double
    let onUpdateZoomRanges: () -> Void
    @State private var previousZoomScale: CGFloat = 1.0
    @State private var zoomTimer: Timer?
    @Binding var selectedEdgeID: UUID?
    @Binding var showOverlays: Bool
    @Binding var isAddingEdge: Bool
    @Binding var isSimulating: Bool
    @Binding var saturation: Double
    
    init(
        viewModel: GraphViewModel,
        zoomScale: Binding<CGFloat>,
        offset: Binding<CGSize>,
        draggedNode: Binding<(any NodeProtocol)?>,
        dragOffset: Binding<CGPoint>,
        potentialEdgeTarget: Binding<(any NodeProtocol)?>,
        selectedNodeID: Binding<NodeID?>,
        viewSize: CGSize,
        panStartOffset: Binding<CGSize?>,
        showMenu: Binding<Bool>,
        maxZoom: CGFloat,
        crownPosition: Binding<Double>,
        onUpdateZoomRanges: @escaping () -> Void,
        selectedEdgeID: Binding<UUID?>,
        showOverlays: Binding<Bool>,
        isAddingEdge: Binding<Bool>,
        isSimulating: Binding<Bool>,
        saturation: Binding<Double>  // NEW: Add to init params
    ) {
        self.viewModel = viewModel
        self._zoomScale = zoomScale
        self._offset = offset
        self._draggedNode = draggedNode
        self._dragOffset = dragOffset
        self._potentialEdgeTarget = potentialEdgeTarget
        self._selectedNodeID = selectedNodeID
        self.viewSize = viewSize
        self._panStartOffset = panStartOffset
        self._showMenu = showMenu
        self.maxZoom = maxZoom
        self._crownPosition = crownPosition
        self.onUpdateZoomRanges = onUpdateZoomRanges
        self._selectedEdgeID = selectedEdgeID
        self._showOverlays = showOverlays
        self._isAddingEdge = isAddingEdge
        self._isSimulating = isSimulating
        self._saturation = saturation
    }
    
    var body: some View {
        FocusableView {
            AccessibleCanvas(
                viewModel: viewModel,
                zoomScale: zoomScale,
                offset: offset,
                draggedNode: draggedNode,
                dragOffset: dragOffset,
                potentialEdgeTarget: potentialEdgeTarget,
                selectedNodeID: selectedNodeID,
                viewSize: viewSize,
                selectedEdgeID: selectedEdgeID,
                showOverlays: showOverlays,
                saturation: saturation  // NEW: Pass the value here (draw reads it)
            )
            .modifier(GraphGesturesModifier(
                viewModel: viewModel,
                zoomScale: $zoomScale,
                offset: $offset,
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
                saturation: $saturation  // NEW: Pass binding to modifier for mutation during gesture
            ))
        }
        
        .id("GraphCanvas")  // Add stable ID for crown sequencer
        .digitalCrownRotation($crownPosition, from: 0, through: Double(AppConstants.crownZoomSteps), sensitivity: .high)
        
    }
}
