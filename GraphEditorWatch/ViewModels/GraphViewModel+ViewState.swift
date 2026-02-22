//
//  GraphViewModel+ViewState.swift
//  GraphEditorWatch
//
//  Extension for view state management (zoom, offset, selection, focus)

import Foundation
import SwiftUI
import GraphEditorShared
import WatchKit
import os

// MARK: - View State Management
extension GraphViewModel {
    
    // MARK: Zoom & Fit
    
    public func calculateZoomRanges(for viewSize: CGSize) -> (min: CGFloat, max: CGFloat) {
        var graphBounds = model.physicsEngine.boundingBox(nodes: model.nodes.map { $0.unwrapped })
        if graphBounds.width < 100 || graphBounds.height < 100 {
            graphBounds = graphBounds.insetBy(dx: -50, dy: -50)
        }
        let contentPadding: CGFloat = Constants.App.contentPadding
        let paddedWidth = graphBounds.width + 2 * contentPadding
        let paddedHeight = graphBounds.height + 2 * contentPadding
        let fitWidth = viewSize.width / paddedWidth
        let fitHeight = viewSize.height / paddedHeight
        let calculatedMin = min(fitWidth, fitHeight)
        let minZoom = max(calculatedMin, 0.1)  // Allow zooming out much further
        let maxZoom = minZoom * Constants.App.maxZoom
        
        return (minZoom, maxZoom)
    }
    
    @MainActor
    public func updateZoomToFit(
        viewSize: CGSize,
        paddingFactor: CGFloat = AppConstants.zoomPaddingFactor
    ) {
        guard !model.visibleNodes.isEmpty else {
            zoomScale = 1.0
            offset = .zero
            return
        }
        
        let bounds = model.physicsEngine.boundingBox(nodes: model.visibleNodes)
            .insetBy(dx: -30, dy: -30)
        
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        let scaleX = viewSize.width  / bounds.width
        let scaleY = viewSize.height / bounds.height
        let targetZoom = min(scaleX, scaleY) * paddingFactor
        
        zoomScale = targetZoom.clamped(to: 0.2...5.0)
        
        let centroid = model.centroid ?? .zero
        offset = CGSize(
            width: viewSize.width  / 2 - centroid.x * zoomScale,
            height: viewSize.height / 2 - centroid.y * zoomScale
        )
    }
    
    /// Centers and fits the graph to the view — intended for initial load or explicit user action only
    @MainActor
    public func resetViewToFitGraph(viewSize: CGSize, paddingFactor: CGFloat = 0.85) {
        guard !model.visibleNodes.isEmpty else {
            zoomScale = 1.0
            offset = .zero
            return
        }
        
        let bounds = model.physicsEngine.boundingBox(nodes: model.visibleNodes)
            .insetBy(dx: -40, dy: -40)
        
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        let scaleX = viewSize.width  / bounds.width
        let scaleY = viewSize.height / bounds.height
        let newZoom = min(scaleX, scaleY) * paddingFactor
        
        zoomScale = newZoom.clamped(to: 0.2...5.0)
    }
    
    /// Centers a specific node on the screen by adjusting the offset
    /// - Parameters:
    ///   - nodeID: The ID of the node to center
    ///   - viewSize: The size of the viewport
    ///   - animated: Whether to animate the centering (default: true)
    @MainActor
    public func centerNode(_ nodeID: NodeID, viewSize: CGSize, animated: Bool = true) {
        guard let node = model.nodes.first(where: { $0.id == nodeID }) else { return }
        
        let nodePos = node.position
        let centroid = effectiveCentroid
        
        // Calculate what offset would place the node at screen center
        // From modelToScreen: screenPos = viewCenter + (modelPos - centroid) * zoom + offset
        // Solving for offset when screenPos = viewCenter:
        // viewCenter = viewCenter + (nodePos - centroid) * zoom + offset
        // offset = -(nodePos - centroid) * zoom
        
        let relativePos = nodePos - centroid
        let scaledPos = relativePos * zoomScale
        let newOffset = CGSize(width: -scaledPos.x, height: -scaledPos.y)
        
        if animated {
            withAnimation(.easeInOut(duration: 1.0)) {
                offset = newOffset
            }
        } else {
            offset = newOffset
        }
    }
    
    /// Centers view on RootNode with optimal zoom for control node interaction
    /// Uses 0.85x zoom to fit RootNode + all control positions on screen
    @MainActor
    public func resetViewToRootNode(viewSize: CGSize) {
        guard let rootNode = model.getRootNode() else {
            // Fallback to standard fit if no root
            resetViewToFitGraph(viewSize: viewSize)
            return
        }
        
        // Set zoom optimized for empty graph with RootNode + controls
        zoomScale = 0.85
        
        // Center on RootNode at origin (0, 0)
        centerNode(rootNode.id, viewSize: viewSize)
    }
    
    // MARK: Selection & Focus
    
    /// Zooms to fit a PersonNode in a table, including its row, parent PeopleListNode, and control nodes
    @MainActor
    public func zoomToFitTableRow(_ nodeID: NodeID, viewSize: CGSize, animated: Bool = true) {
        guard let personNode = model.nodes.first(where: { $0.id == nodeID })?.unwrapped as? PersonNode else { return }
        
        // Find the parent PeopleListNode
        guard let parentEdge = model.edges.first(where: { $0.target == nodeID && $0.type == .hierarchy }),
              let peopleList = model.nodes.first(where: { $0.id == parentEdge.from })?.unwrapped as? PeopleListNode,
              peopleList.isExpanded else {
            // Not in a table, use standard centering
            centerNode(nodeID, viewSize: viewSize, animated: animated)
            return
        }
        
        // Get control nodes if they exist
        let controlNodes = model.nodes.filter { $0.unwrapped is ControlNode }
        
        // Calculate bounding box for: PersonNode + PeopleListNode + control nodes
        var nodesToFit: [any NodeProtocol] = [personNode, peopleList]
        nodesToFit.append(contentsOf: controlNodes)
        
        // Add label width to the bounding box - improved estimate to match rendering
        let labelWidth: CGFloat = CGFloat(personNode.contents.first?.displayText.count ?? 10) * 11.0 * 0.9
        let labelOffset: CGFloat = personNode.radius + 10
        
        // Calculate bounding box manually to include label
        var minX = personNode.position.x - personNode.radius
        var maxX = personNode.position.x + labelOffset + labelWidth
        var minY = personNode.position.y - personNode.radius
        var maxY = personNode.position.y + personNode.radius
        
        for node in nodesToFit {
            minX = min(minX, node.position.x - node.radius)
            maxX = max(maxX, node.position.x + node.radius)
            minY = min(minY, node.position.y - node.radius)
            maxY = max(maxY, node.position.y + node.radius)
        }
        
        // Add padding
        let padding: CGFloat = 40.0
        minX -= padding
        maxX += padding
        minY -= padding
        maxY += padding
        
        let boundsWidth = maxX - minX
        let boundsHeight = maxY - minY
        
        guard boundsWidth > 0, boundsHeight > 0 else { return }
        
        // Calculate zoom to fit
        let scaleX = viewSize.width / boundsWidth
        let scaleY = viewSize.height / boundsHeight
        let targetZoom = min(scaleX, scaleY) * 0.85  // 85% padding factor
        
        let newZoom = targetZoom.clamped(to: 0.2...5.0)
        
        // Calculate center of bounding box
        let boundsCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        
        // Calculate offset to center this bounding box
        let centroid = effectiveCentroid
        let relativePos = boundsCenter - centroid
        let scaledPos = relativePos * newZoom
        let newOffset = CGSize(width: -scaledPos.x, height: -scaledPos.y)
        
        if animated {
            withAnimation(.easeInOut(duration: 0.5)) {
                zoomScale = newZoom
                offset = newOffset
            }
        } else {
            zoomScale = newZoom
            offset = newOffset
        }
    }
    
    @MainActor
    public func setSelectedNode(_ id: NodeID?, zoomToFit: Bool = false) {
        selectedNodeID = id
        selectedEdgeID = nil
        focusState = id.map { .node($0) } ?? .graph
        
        Task { @MainActor in
            model.updateControlNodes(for: id)
            
            // If zoomToFit requested and node is a PersonNode in a table, zoom to fit
            if zoomToFit, let nodeID = id, viewSize != .zero {
                if model.nodes.first(where: { $0.id == nodeID })?.unwrapped is PersonNode {
                    // Check if this PersonNode is in an expanded PeopleListNode
                    if let parentEdge = model.edges.first(where: { $0.target == nodeID && $0.type == .hierarchy }),
                       let peopleList = model.nodes.first(where: { $0.id == parentEdge.from })?.unwrapped as? PeopleListNode,
                       peopleList.isExpanded {
                        // It's in a table, zoom to fit the row
                        zoomToFitTableRow(nodeID, viewSize: viewSize, animated: true)
                    }
                }
            }
        }
        
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
    
    public func setSelectedEdge(_ id: UUID?) {
        selectedEdgeID = id
        focusState = id.map { .edge($0) } ?? .graph
    }
    
    // MARK: Tap Handling
    
    public func handleTap(at modelPos: CGPoint) async {
        await model.pauseSimulation()
        
        #if DEBUG
        Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
            .debug("Handling tap at model pos: x=\(modelPos.x), y=\(modelPos.y)")
        #endif
        
        let hitRadius: CGFloat = 25.0 / max(1.0, zoomScale)
        let nearbyNodes = model.physicsEngine.queryNearby(position: modelPos, radius: hitRadius, nodes: model.visibleNodes)
        
        #if DEBUG
        Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
            .debug("Nearby nodes found: \(nearbyNodes.count)")
        #endif
        
        let sortedNearby = nearbyNodes.sorted {
            hypot($0.position.x - modelPos.x, $0.position.y - modelPos.y) < hypot($1.position.x - modelPos.x, $1.position.y - modelPos.y)
        }
        
        if let tappedNode = sortedNearby.first {
            let newSelectionID = (tappedNode.id == selectedNodeID) ? nil : tappedNode.id
            
            // Check if this is a PersonNode in a table to enable zoom-to-fit
            let shouldZoomToFit = newSelectionID != nil && tappedNode is PersonNode
            
            // Use setSelectedNode to handle zoom-to-fit logic
            setSelectedNode(newSelectionID, zoomToFit: shouldZoomToFit)
            
            #if DEBUG
            Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
                .debug("Selected node \(tappedNode.label) (type: \(type(of: tappedNode)))")
            #endif
        } else {
            setSelectedNode(nil, zoomToFit: false)
            
            #if DEBUG
            Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
                .debug("Tap missed; cleared selections")
            #endif
        }
        await resumeSimulationAfterDelay()
    }
}
