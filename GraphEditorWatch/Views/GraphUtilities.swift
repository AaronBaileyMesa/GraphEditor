// GraphUtilities.swift
//  GraphEditor
//
//  Created by handcart on 9/19/25.
//
import SwiftUI
import GraphEditorShared
import CoreGraphics

struct ViewSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct NodeWrapper: Equatable, Identifiable {
    let id: UUID?
    let node: (any NodeProtocol)?
    
    init(node: (any NodeProtocol)?) {
        self.node = node
        self.id = node?.id
    }
    
    static func == (lhs: NodeWrapper, rhs: NodeWrapper) -> Bool {
        lhs.id == rhs.id
    }
}

struct InnerViewConfig {
    let geo: GeometryProxy
    let viewModel: GraphViewModel
    let zoomScale: Binding<CGFloat>
    let offset: Binding<CGSize>
    let draggedNode: Binding<NodeWrapper>
    let dragOffset: Binding<CGPoint>
    let potentialEdgeTarget: Binding<NodeWrapper>
    let panStartOffset: Binding<CGSize?>
    let showMenu: Binding<Bool>
    let showOverlays: Binding<Bool>
    let maxZoom: CGFloat
    let crownPosition: Binding<Double>
    let updateZoomRangesHandler: (CGSize) -> Void
    let selectedNodeID: Binding<NodeID?>
    let selectedEdgeID: Binding<UUID?>
    let canvasFocus: FocusState<Bool>
    let onCenterGraph: () -> Void
    let isAddingEdge: Binding<Bool>
    let isSimulating: Binding<Bool>
    
    init(
        geo: GeometryProxy,
        viewModel: GraphViewModel,
        zoomScale: Binding<CGFloat>,
        offset: Binding<CGSize>,
        draggedNode: Binding<NodeWrapper>,
        dragOffset: Binding<CGPoint>,
        potentialEdgeTarget: Binding<NodeWrapper>,
        panStartOffset: Binding<CGSize?>,
        showMenu: Binding<Bool>,
        showOverlays: Binding<Bool>,
        maxZoom: CGFloat,
        crownPosition: Binding<Double>,
        updateZoomRangesHandler: @escaping (CGSize) -> Void,
        selectedNodeID: Binding<NodeID?>,
        selectedEdgeID: Binding<UUID?>,
        canvasFocus: FocusState<Bool>,
        onCenterGraph: @escaping () -> Void,
        isAddingEdge: Binding<Bool>,
        isSimulating: Binding<Bool>  // NEW: Add this param
    ) {
        self.geo = geo
        self.viewModel = viewModel
        self.zoomScale = zoomScale
        self.offset = offset
        self.draggedNode = draggedNode
        self.dragOffset = dragOffset
        self.potentialEdgeTarget = potentialEdgeTarget
        self.panStartOffset = panStartOffset
        self.showMenu = showMenu
        self.showOverlays = showOverlays
        self.maxZoom = maxZoom
        self.crownPosition = crownPosition
        self.updateZoomRangesHandler = updateZoomRangesHandler
        self.selectedNodeID = selectedNodeID
        self.selectedEdgeID = selectedEdgeID
        self.canvasFocus = canvasFocus
        self.onCenterGraph = onCenterGraph
        self.isAddingEdge = isAddingEdge
        self.isSimulating = isSimulating
    }
}
