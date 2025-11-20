//
//  GraphViewModel.swift
//  GraphEditorWatch
//
//  Created by handcart on 10/3/25.
//

import Combine
import GraphEditorShared
import WatchKit  // For WKApplication
import os  // Added for logging

@MainActor public class GraphViewModel: ObservableObject {
    @Published public var model: GraphModel
    @Published public var selectedEdgeID: UUID?
    @Published public var pendingEdgeType: EdgeType = .association
    @Published public var selectedNodeID: UUID?
    @Published public var offset: CGPoint = .zero
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var currentGraphName: String = "default"
    
    private var inactiveObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?
        
    private var saveTimer: Timer?
    private var cancellable: AnyCancellable?
    
    private static var logger: Logger {
        Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
    }
    
    var isSelectedToggleNode: Bool {
        guard let id = selectedNodeID else { return false }
        return model.nodes.first { $0.id == id }?.unwrapped is ToggleNode
    }
    
    public var canUndo: Bool {
        model.canUndo
    }
    
    public var canRedo: Bool {
        model.canRedo
    }
    
    private var pauseObserver: NSObjectProtocol?
    private var resumeObserver: NSObjectProtocol?
    
    private var resumeTimer: Timer?
    
    @MainActor
    public var effectiveCentroid: CGPoint {
        model.centroid ?? .zero
    }
    
    public enum AppFocusState: Equatable {
        case graph
        case node(UUID)
        case edge(UUID)
        case menu
    }
    
    private var logicalCanvasSize: CGSize {
        AppConstants.logicalCanvasSize
    }

    @Published public var focusState: AppFocusState = .graph
    
    public init(model: GraphModel) {
        self.model = model
        self.currentGraphName = model.currentGraphName  // Sync on init
        cancellable = model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        
        pauseObserver = NotificationCenter.default.addObserver(forName: .graphSimulationPause, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in  // Ensure main for publishes
                await self?.model.pauseSimulation()
            }
        }
        
        resumeObserver = NotificationCenter.default.addObserver(forName: .graphSimulationResume, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in  // Ensure main for publishes
                await self?.resumeSimulationAfterDelay()
            }
        }
        
        inactiveObserver = NotificationCenter.default.addObserver(forName: WKApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
            NotificationCenter.default.post(name: .graphSimulationPause, object: nil)  // Trigger existing pause logic
        }

        activeObserver = NotificationCenter.default.addObserver(forName: WKApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            NotificationCenter.default.post(name: .graphSimulationResume, object: nil)  // Trigger existing resume logic
        }
    }
    
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
        let minZoom = max(calculatedMin, 0.5)
        let maxZoom = minZoom * Constants.App.maxZoom  // Now higher (e.g., *5)
        
#if DEBUG
        GraphViewModel.logger.debug("Calculated zoom ranges: min=\(minZoom), max=\(maxZoom), based on bounds x=\(graphBounds.origin.x), y=\(graphBounds.origin.y), width=\(graphBounds.width), height=\(graphBounds.height)")
        #endif
        
        return (minZoom, maxZoom)
    }
    
    public func addNode(at position: CGPoint) async {
        await model.addNode(at: position)
    }
    
    public func addToggleNode(at position: CGPoint) async {  // NEW: Add this method to fix 'no member 'addToggleNode''
        await model.addToggleNode(at: position)
        await saveAfterDelay()
    }
    
    public func addEdge(from fromID: NodeID, to targetID: NodeID, type: EdgeType = .association) async {
        await model.addEdge(from: fromID, target: targetID, type: type)
        await saveAfterDelay()
    }
    
    @MainActor
    func moveNode(_ node: any NodeProtocol, to newPosition: CGPoint) async {
        await model.moveNode(node, to: newPosition)  // assuming GraphModel has this
        // or directly:
        // await model.updateNodePosition(node.id, newPosition: newPosition)
    }
    
    public func undo() async {
        await model.undo()
        await saveAfterDelay()
    }
    
    public func redo() async {
        await model.redo()
        await saveAfterDelay()
    }
    
    public func deleteSelected() async {
        await model.deleteSelected(selectedNodeID: selectedNodeID, selectedEdgeID: selectedEdgeID)
        selectedNodeID = nil
        selectedEdgeID = nil
        await saveAfterDelay()
    }
    
    public func toggleExpansion(for nodeID: NodeID) async {
        await model.toggleExpansion(for: nodeID)
        await saveAfterDelay()
        
    }
    
    public func toggleSelectedNode() async {  // NEW: Add this method to fix 'no member 'toggleSelectedNode''
        if let id = selectedNodeID {
            await toggleExpansion(for: id)
        }
    }
    
    public func deleteNode(withID id: NodeID) async {
        await model.deleteNode(withID: id)
        if selectedNodeID == id { selectedNodeID = nil }
        // Deleting a node may also invalidate an edge selection
        selectedEdgeID = nil
        await saveAfterDelay()
    }
    
    public func clearGraph() async {
        await model.resetGraph()
        await saveAfterDelay()
    }
    
    public func pauseSimulation() async {
        await model.pauseSimulation()
    }
    
    public func resumeSimulation() async {
        await model.resumeSimulation()
    }
    
    public func resumeSimulationAfterDelay() async {
        resumeTimer?.invalidate()
        resumeTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor in  // Hop to main for safe access
                guard let self = self else { return }
                if WKApplication.shared().applicationState == .active {
                    await self.model.resumeSimulation()  // Consistent async call
                }
            }
        }
    }
    
    // Fixed: handleTap with proper scoping, removed invalid SwiftUI Text, added ToggleNode update logic (assumes model.updateNode method; adjust if needed)
    public func handleTap(at modelPos: CGPoint) async {
        await model.pauseSimulation()
        
        #if DEBUG
        GraphViewModel.logger.debug("Handling tap at model pos: x=\(modelPos.x), y=\(modelPos.y)")
        #endif
        
        // Efficient hit test with queryNearby
        let hitRadius: CGFloat = 25.0 / max(1.0, zoomScale)  // Dynamic: Smaller radius at higher zoom for precision; test and adjust
        let nearbyNodes = model.physicsEngine.queryNearby(position: modelPos, radius: hitRadius, nodes: model.visibleNodes)
        
        #if DEBUG
        GraphViewModel.logger.debug("Nearby nodes found: \(nearbyNodes.count)")
        #endif
        
        // Sort by distance to get closest (if multiple)
        let sortedNearby = nearbyNodes.sorted {
            hypot($0.position.x - modelPos.x, $0.position.y - modelPos.y) < hypot($1.position.x - modelPos.x, $1.position.y - modelPos.y)
        }
        
        if let tappedNode = sortedNearby.first {
            selectedNodeID = (tappedNode.id == selectedNodeID) ? nil : tappedNode.id
            selectedEdgeID = nil
            
            #if DEBUG
            GraphViewModel.logger.debug("Selected node \(tappedNode.label) (type: \(type(of: tappedNode)))")
            #endif
            
            model.objectWillChange.send()  // Trigger UI refresh
        } else {
            // Miss: Clear selections
            selectedNodeID = nil
            selectedEdgeID = nil
            
            #if DEBUG
            GraphViewModel.logger.debug("Tap missed; cleared selections")
            #endif
        }
        
        focusState = selectedNodeID.map { .node($0) } ?? .graph
        objectWillChange.send()
        await resumeSimulationAfterDelay()
    }
    
    public func setSelectedNode(_ id: UUID?) {
        selectedNodeID = id
        focusState = id.map { .node($0) } ?? .graph
        objectWillChange.send()
    }

    public func setSelectedEdge(_ id: UUID?) {
        selectedEdgeID = id
        focusState = id.map { .edge($0) } ?? .graph
        objectWillChange.send()
    }
    
    // MARK: - Zoom to Fit & Centering (now uses logical canvas)

    /// Updates zoom to fit all visible nodes with padding
    @MainActor
    public func updateZoomToFit(paddingFactor: CGFloat = AppConstants.zoomPaddingFactor) {
        let visibleNodes = model.visibleNodes
        guard !visibleNodes.isEmpty else { return }
        
        let bounds = boundingBox(nodes: visibleNodes).insetBy(dx: -20, dy: -20) // small extra margin
        
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        // Critical: use logical canvas size here
        let scaleX = logicalCanvasSize.width  / bounds.width
        let scaleY = logicalCanvasSize.height / bounds.height
        let newZoom = min(scaleX, scaleY) * paddingFactor
        
        // Clamp to reasonable bounds
        zoomScale = max(0.2, min(5.0, newZoom))
        
        // Re-center after zoom change
        centerGraph()
    }
    
    /// Centers and fits the graph to the view — intended for initial load or explicit user action only
    @MainActor
    public func resetViewToFitGraph(viewSize: CGSize) {
        guard viewSize.width > 0 && viewSize.height > 0 else {
            Self.logger.warning("resetViewToFitGraph called with invalid size: \(String(describing: viewSize))")
            return
        }
        
        let (minZoom, _) = calculateZoomRanges(for: viewSize)
        zoomScale = minZoom
        offset = .zero
        objectWillChange.send()
    }
    
    deinit {
        if let pause = pauseObserver { NotificationCenter.default.removeObserver(pause) }
        if let resume = resumeObserver { NotificationCenter.default.removeObserver(resume) }
        if let inactive = inactiveObserver { NotificationCenter.default.removeObserver(inactive) }
        if let active = activeObserver { NotificationCenter.default.removeObserver(active) }
    }
}

extension GraphViewModel {
    // MARK: - Multi-Graph Support
    
    /// Creates a new empty graph and switches to it, resetting view state.
    @MainActor
    public func createNewGraph(name: String) async throws {
        // Save current view state before switching
        try saveViewState()
        
        try await model.createNewGraph(name: name)
        currentGraphName = model.currentGraphName  // Sync
        
        // Reset view state for new graph
        offset = .zero
        zoomScale = 1.0
        selectedNodeID = nil
        selectedEdgeID = nil
        focusState = .graph
        
        await resumeSimulation()
        objectWillChange.send()
    }
    
    /// Loads a specific graph by name, switches to it, and loads its view state.
    @MainActor
    public func loadGraph(name: String) async throws {
        // Save current view state before switching
        try saveViewState()
        
        await model.loadGraph(name: name)
        currentGraphName = model.currentGraphName  // Sync
        
        // Load view state for the new graph
        if let viewState = try model.storage.loadViewState(for: currentGraphName) {
            offset = viewState.offset
            zoomScale = viewState.zoomScale
            selectedNodeID = viewState.selectedNodeID
            selectedEdgeID = viewState.selectedEdgeID
        } else {
            // Default if no view state
            offset = .zero
            zoomScale = 1.0
            resetViewToFitGraph()
            selectedNodeID = nil
            selectedEdgeID = nil
        }
        focusState = .graph
        
        await resumeSimulation()
        objectWillChange.send()
    }
    
    /// Deletes a graph by name.
    @MainActor
    public func deleteGraph(name: String) async throws {
        try await model.deleteGraph(name: name)
    }
    
    /// Lists all graph names.
    @MainActor
    public func listGraphNames() async throws -> [String] {
        try await model.listGraphNames()
    }
}

extension GraphViewModel {
    // MARK: - View State Persistence
    
    /// Saves current view state for the current graph.
    public func saveViewState() throws {
        let viewState = ViewState(offset: offset, zoomScale: zoomScale, selectedNodeID: selectedNodeID, selectedEdgeID: selectedEdgeID)
        try model.storage.saveViewState(viewState, for: currentGraphName)
        
        #if DEBUG
        GraphViewModel.logger.debug("Saved view state for '\(self.currentGraphName)'")
        #endif
    }
}

extension GraphViewModel {
    // MARK: - Helpers
    
    @MainActor
    private func saveAfterDelay() async {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                do {
                    try await self?.model.saveGraph()
                    try self?.saveViewState()
                } catch {
                    #if DEBUG
                    GraphViewModel.logger.error("Save failed: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }
}

extension GraphViewModel {
    // MARK: - Logical Canvas Zoom & Centering (final consistent version)
    
    /// Centers the visible graph perfectly in the logical square canvas
    @MainActor
        public func centerGraph() {
            guard !model.visibleNodes.isEmpty else {
                offset = .zero
                return
            }
        
        let centroid = model.centroid ?? .zero
        
        // Use logical canvas — this is now the single source of truth
        let canvas = logicalCanvasSize
        offset = CGPoint(
            x: canvas.width  / 2 - centroid.x * zoomScale,
            y: canvas.height / 2 - centroid.y * zoomScale
        )
    }
    
    /// Zooms to fit all visible nodes with consistent padding
    @MainActor
    public func resetViewToFitGraph(paddingFactor: CGFloat = 0.8) {
        let visibleNodes = model.visibleNodes
        guard !visibleNodes.isEmpty else {
            zoomScale = 1.0
            offset = .zero
            return
        }
        
        // Compute graph bounds with a little breathing room
        let bounds = boundingBox(nodes: visibleNodes).insetBy(dx: -30, dy: -30)
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        let canvas = logicalCanvasSize
        
        let scaleX = canvas.width  / bounds.width
        let scaleY = canvas.height / bounds.height
        let newZoom = min(scaleX, scaleY) * paddingFactor
        
        zoomScale = newZoom.clamped(to: 0.2...5.0)
        centerGraph()  // Re-center after zoom change
    }
    
    /// Helper: compute axis-aligned bounding box of nodes
    private func boundingBox(nodes: [any NodeProtocol]) -> CGRect {
        guard let first = nodes.first else { return .zero }
        
        var minX = first.position.x - first.radius
        var minY = first.position.y - first.radius
        var maxX = first.position.x + first.radius
        var maxY = first.position.y + first.radius
        
        for node in nodes.dropFirst() {
            minX = min(minX, node.position.x - node.radius)
            minY = min(minY, node.position.y - node.radius)
            maxX = max(maxX, node.position.x + node.radius)
            maxY = max(maxY, node.position.y + node.radius)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
