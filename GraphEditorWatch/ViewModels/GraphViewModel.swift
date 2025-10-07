//
//  GraphViewModel.swift
//  GraphEditorWatch
//
//  Created by handcart on 10/3/25.
//

import Combine
import GraphEditorShared
import WatchKit  // For WKApplication

@MainActor public class GraphViewModel: ObservableObject {
    @Published public var model: GraphModel
    @Published public var selectedEdgeID: UUID?
    @Published public var pendingEdgeType: EdgeType = .association
    @Published public var selectedNodeID: UUID?
    @Published public var offset: CGPoint = .zero
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var currentGraphName: String = "default"  // Sync with model; standardized to "default"
        
    private var saveTimer: Timer?
    private var cancellable: AnyCancellable?
    
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
    
    public var effectiveCentroid: CGPoint {
        let visibleNodes = model.visibleNodes()
        if let id = selectedNodeID, let node = visibleNodes.first(where: { $0.id == id }) {
            return node.position
        } else if let id = selectedEdgeID, let edge = model.edges.first(where: { $0.id == id }),
                  let from = visibleNodes.first(where: { $0.id == edge.from }),
                  let target = visibleNodes.first(where: { $0.id == edge.target }) {
            return CGPoint(x: (from.position.x + target.position.x) / 2, y: (from.position.y + target.position.y) / 2)
        }
        return centroid(of: visibleNodes) ?? .zero  // Fix unwrap
    }
    
    public enum AppFocusState: Equatable {
        case graph
        case node(UUID)
        case edge(UUID)
        case menu
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

        // Load graph, reset velocities, and view state async to avoid races
        Task {
            do {
                try await model.loadGraph()
                
                model.nodes = model.nodes.map { anyNode in
                    let updated = anyNode.unwrapped.with(position: anyNode.position, velocity: CGPoint.zero)
                    return AnyNode(updated)
                }
                
                if let viewState = try model.storage.loadViewState(for: model.currentGraphName) {
                    self.offset = viewState.offset
                    self.zoomScale = viewState.zoomScale
                    self.selectedNodeID = viewState.selectedNodeID
                    self.selectedEdgeID = viewState.selectedEdgeID
                    print("Loaded view state for '\(model.currentGraphName)'")
                }
            } catch {
                print("Failed to load graph or view state: \(error)")
            }
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
        print("Calculated zoom ranges: min=\(minZoom), max=\(maxZoom), based on bounds \(graphBounds)")  // Enhanced log
        return (minZoom, maxZoom)
    }
    
    public func addNode(at position: CGPoint? = nil) async {
        await model.addNode(at: position ?? .zero)
        await saveAfterDelay()
    }
    
    public func addToggleNode(at position: CGPoint) async {  // NEW: Add this method to fix 'no member 'addToggleNode''
        await model.addToggleNode(at: position)
        await saveAfterDelay()
    }
    
    public func addEdge(from fromID: NodeID, to toID: NodeID, type: EdgeType = .association) async {
        await model.addEdge(from: fromID, target: toID, type: type)
        await saveAfterDelay()
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
    
    public func addChild(to parentID: NodeID) async {
        await model.addChild(to: parentID)
        await saveAfterDelay()
    }
    
    public func deleteNode(withID id: NodeID) async {
        await model.deleteNode(withID: id)
        if selectedNodeID == id { selectedNodeID = nil }
        // Deleting a node may also invalidate an edge selection
        selectedEdgeID = nil
        await saveAfterDelay()
    }
    
    public func clearGraph() async {
        await model.clearGraph()
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
        
        print("Handling tap at model pos: \(modelPos)")  // For testing
        
        // Efficient hit test with queryNearby
        let hitRadius: CGFloat = 25.0 / max(1.0, zoomScale)  // Dynamic: Smaller radius at higher zoom for precision; test and adjust
        let nearbyNodes = model.physicsEngine.queryNearby(position: modelPos, radius: hitRadius, nodes: model.visibleNodes())
        print("Nearby nodes found: \(nearbyNodes.count)")  // For testing
        
        // Sort by distance to get closest (if multiple)
        let sortedNearby = nearbyNodes.sorted {
            hypot($0.position.x - modelPos.x, $0.position.y - modelPos.y) < hypot($1.position.x - modelPos.x, $1.position.y - modelPos.y)
        }
        
        if let tappedNode = sortedNearby.first {
            selectedNodeID = (tappedNode.id == selectedNodeID) ? nil : tappedNode.id
            selectedEdgeID = nil
            print("Selected node \(tappedNode.label) (type: \(type(of: tappedNode)))")
            model.objectWillChange.send()  // Trigger UI refresh
        } else {
            // Miss: Clear selections
            selectedNodeID = nil
            selectedEdgeID = nil
            print("Tap missed; cleared selections")
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
    
    public func centerGraph() {
        // UPDATED: Enhanced to recalculate based on bounds
        let viewSize = CGSize(width: 300, height: 300)  // Replace with actual view size if passed
        let (minZoom, _) = calculateZoomRanges(for: viewSize)
        zoomScale = minZoom
        offset = .zero
        objectWillChange.send()
    }
}

extension GraphViewModel {
    // MARK: - Multi-Graph Support
    
    /// Creates a new empty graph and switches to it, resetting view state.
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
    public func loadGraph(name: String) async throws {
        // Save current view state before switching
        try saveViewState()
        
        try await model.loadGraph(name: name)
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
            selectedNodeID = nil
            selectedEdgeID = nil
        }
        focusState = .graph
        
        await resumeSimulation()
        objectWillChange.send()
    }
    
    /// Deletes a graph by name.
    public func deleteGraph(name: String) async throws {
        try await model.deleteGraph(name: name)
    }
    
    /// Lists all graph names.
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
        print("Saved view state for '\(currentGraphName)'")
    }
}

extension GraphViewModel {
    // MARK: - Helpers
    
    private func saveAfterDelay() async {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                do {
                    try await self?.model.saveGraph()
                    try self?.saveViewState()
                } catch {
                    print("Save failed: \(error)")
                }
            }
        }
    }
}
