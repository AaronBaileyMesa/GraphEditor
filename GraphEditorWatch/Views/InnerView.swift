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
            draggedNode: draggedNodeBinding,
            dragOffset: config.dragOffset,
            potentialEdgeTarget: potentialEdgeTargetBinding,
            selectedNodeID: config.selectedNodeID,
            selectedEdgeID: config.selectedEdgeID,
            viewSize: config.geo.size,
            panStartOffset: config.panStartOffset,
            showMenu: config.showMenu,
            onUpdateZoomRanges: { config.updateZoomRangesHandler(config.geo.size) },
            isAddingEdge: config.isAddingEdge,
            isSimulating: config.isSimulating,
            saturation: config.saturation,
            crownPosition: config.crownPosition
        )
            .accessibilityIdentifier("GraphCanvas")
            .focused(config.canvasFocus.projectedValue)
            .focusable()
        canvasView
    }
}
