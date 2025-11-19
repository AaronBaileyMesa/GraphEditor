import SwiftUI
import WatchKit
import GraphEditorShared
import os

struct GraphCanvasView: View {
    private static var logger: Logger {
        Logger(subsystem: "io.handcart.GraphEditor", category: "graphcanvasview")
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
    
    // These two are now properly declared as stored properties
    let minZoom: CGFloat
    let maxZoom: CGFloat
    
    @Environment(\.crownPosition) private var crownPositionBinding: Binding<Double>
    let onUpdateZoomRanges: () -> Void
    @Binding var selectedEdgeID: UUID?
    @Binding var showOverlays: Bool
    @Binding var isAddingEdge: Bool
    @Binding var isSimulating: Bool
    @Binding var saturation: Double
    
    private var crownPosition: Double {
        get { crownPositionBinding.wrappedValue }
        nonmutating set { crownPositionBinding.wrappedValue = newValue }
    }
    
    // MARK: - Init (updated order + added minZoom)
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
        minZoom: CGFloat,           // ← added
        maxZoom: CGFloat,           // ← already existed
        onUpdateZoomRanges: @escaping () -> Void,
        selectedEdgeID: Binding<UUID?>,
        showOverlays: Binding<Bool>,
        isAddingEdge: Binding<Bool>,
        isSimulating: Binding<Bool>,
        saturation: Binding<Double>
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
        self.minZoom = minZoom          // ← stored
        self.maxZoom = maxZoom          // ← stored
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
                saturation: saturation
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
                crownPosition: crownPositionBinding,
                onUpdateZoomRanges: onUpdateZoomRanges,
                isAddingEdge: $isAddingEdge,
                isSimulating: $isSimulating,
                saturation: $saturation
            ))
        }
        .focusable()
        
        // Crown → Zoom
        // Crown → Zoom
        .onChange(of: crownPosition) { _, newValue in
            let normalized = newValue / Double(AppConstants.crownZoomSteps)
            let targetZoom = minZoom + (maxZoom - minZoom) * CGFloat(normalized.clamped(to: 0...1))
            withAnimation(.easeOut(duration: 0.08)) {
                zoomScale = targetZoom
            }
        }
        
        // Zoom → Crown (bidirectional sync)
        .onChange(of: zoomScale) { _, newZoom in
            let normalized = (newZoom - minZoom) / (maxZoom - minZoom)
            let targetCrown = Double(AppConstants.crownZoomSteps) * normalized.clamped(to: 0...1)
            if abs(targetCrown - crownPosition) > 0.1 {
                crownPosition = targetCrown
            }
        }
        
        // Initial sync on appear
        .onAppear {
            let normalized = (zoomScale - minZoom) / (maxZoom - minZoom)
            let targetCrown = Double(AppConstants.crownZoomSteps) * normalized.clamped(to: 0...1)
            crownPosition = targetCrown
        }
    }
}
