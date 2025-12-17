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
    let config: InnerViewConfig
    
    var body: some View {
        let draggedNodeBinding = Binding<(any NodeProtocol)?>(
            get: { config.draggedNode.wrappedValue.node },
            set: { config.draggedNode.wrappedValue = NodeWrapper(node: $0) }
        )
        let potentialEdgeTargetBinding = Binding<(any NodeProtocol)?>(
            get: { config.potentialEdgeTarget.wrappedValue.node },
            set: { config.potentialEdgeTarget.wrappedValue = NodeWrapper(node: $0) }
        )
        // ADD THIS: Custom binding for dragStartNode (mirrors the above)
        let dragStartNodeBinding = Binding<(any NodeProtocol)?>(
            get: { config.dragStartNode.wrappedValue.node },
            set: { config.dragStartNode.wrappedValue = NodeWrapper(node: $0) }
        )
        
        let canvasView = GraphCanvasView(
            viewModel: config.viewModel,
            draggedNode: draggedNodeBinding,
            dragOffset: config.dragOffset,
            potentialEdgeTarget: potentialEdgeTargetBinding,
            selectedNodeID: config.selectedNodeID,
            selectedEdgeID: config.selectedEdgeID,
            viewSize: config.viewSize,
            panStartOffset: config.panStartOffset,
            showMenu: config.showMenu,
            onUpdateZoomRanges: { _, _ in config.updateZoomRangesHandler(config.geo.size) },
            isAddingEdge: config.isAddingEdge,
            isSimulating: config.isSimulating,
            saturation: config.saturation,
            currentDragLocation: config.currentDragLocation,
            dragStartNode: dragStartNodeBinding  // Use the custom binding
        )
        .accessibilityIdentifier("GraphCanvas")
        .focused(config.canvasFocus.projectedValue)
        .focusable()
        
        canvasView
    }
}

