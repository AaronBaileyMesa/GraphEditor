//
//  InnerView.swift
//  GraphEditor
//
//  Created by handcart on 9/19/25.
//

// InnerView.swift

import SwiftUI
import GraphEditorShared

struct InnerView: View {
    let config: InnerViewConfig  // This now references the one from GraphUtilities.swift
    
    var body: some View {
        let draggedNodeBinding = Binding<(any NodeProtocol)?>(
            get: { config.draggedNode.wrappedValue.node },
            set: { config.draggedNode.wrappedValue = NodeWrapper(node: $0) }
        )
        let potentialEdgeTargetBinding = Binding<(any NodeProtocol)?>(
            get: { config.potentialEdgeTarget.wrappedValue.node },
            set: { config.potentialEdgeTarget.wrappedValue = NodeWrapper(node: $0) }
        )
        
        let canvasView = GraphCanvasView(
            viewModel: config.viewModel,
            zoomScale: config.zoomScale,
            offset: config.offset,
            draggedNode: draggedNodeBinding,
            dragOffset: config.dragOffset,
            potentialEdgeTarget: potentialEdgeTargetBinding,
            selectedNodeID: config.selectedNodeID,
            viewSize: config.geo.size,
            panStartOffset: config.panStartOffset,
            showMenu: config.showMenu,
            maxZoom: config.maxZoom,
            crownPosition: config.crownPosition,
            onUpdateZoomRanges: { config.updateZoomRangesHandler(config.geo.size) },
            selectedEdgeID: config.selectedEdgeID,
            showOverlays: config.showOverlays,
            isAddingEdge: config.isAddingEdge,
            isSimulating: config.isSimulating,
            saturation: config.saturation  // NEW: Pass the binding here
        )
            .accessibilityIdentifier("GraphCanvas")
            .focused(config.canvasFocus.projectedValue)
            .focusable()
        canvasView
    }
}
