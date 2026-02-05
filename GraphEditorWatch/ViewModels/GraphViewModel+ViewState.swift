//
//  GraphViewModel+ViewState.swift
//  GraphEditorWatch
//
//  Extension for view state management (zoom, offset, selection, focus)

import Foundation
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
    
    // MARK: Selection & Focus
    
    @MainActor
    public func setSelectedNode(_ id: NodeID?) {
        selectedNodeID = id
        selectedEdgeID = nil
        focusState = id.map { .node($0) } ?? .graph
        
        Task { @MainActor in
            model.updateControlNodes(for: id)
        }
        
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
        
        objectWillChange.send()
    }
    
    public func setSelectedEdge(_ id: UUID?) {
        selectedEdgeID = id
        focusState = id.map { .edge($0) } ?? .graph
        objectWillChange.send()
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
            selectedNodeID = (tappedNode.id == selectedNodeID) ? nil : tappedNode.id
            selectedEdgeID = nil
            
            #if DEBUG
            Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
                .debug("Selected node \(tappedNode.label) (type: \(type(of: tappedNode)))")
            #endif
            
            model.objectWillChange.send()
        } else {
            selectedNodeID = nil
            selectedEdgeID = nil
            
            #if DEBUG
            Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
                .debug("Tap missed; cleared selections")
            #endif
        }
        
        focusState = selectedNodeID.map { .node($0) } ?? .graph
        objectWillChange.send()
        await resumeSimulationAfterDelay()
    }
}
