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
    @Published public var selectedNodeID: UUID? {
        didSet {
            Task { @MainActor in
                objectWillChange.send()
                redrawTrigger += 1  // Force redraw on selection change
                Self.logger.debug("Selected node changed to \(self.selectedNodeID?.uuidString.prefix(8) ?? "nil") – triggered controls update")
                // REMOVED: isAnimating sets – now synced via $isSimulating subscription
            }
        }
    }
    
    @Published public var offset: CGSize = .zero
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var currentGraphName: String = "default"
    @Published public var draggedNodeID: UUID?
    @Published public var redrawTrigger: Int = 0  // Increments to force view redraws
    @Published public var isAnimating: Bool = false  // True for active animations (simulation or transitions)
    @Published public var lastFrameTime: Date? = nil  // For calculating elapsed time per frame
    @Published public var isAddingEdge: Bool = false  // FIXED: Added missing property
    @Published var isEditMode: Bool = false

    private var inactiveObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?
    
    private var saveTimer: Timer?
    private var cancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()  // Not @Published; just private for subscriptions
    
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
    private var hasInitiallyLaunched = false  // Track if app has completed initial launch
    
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
    
    @Published public var focusState: AppFocusState = .graph
    
    @MainActor
    public func generateControls(for nodeID: NodeID) async {
        await model.pauseSimulation()
        await model.updateEphemerals(selectedNodeID: nodeID)
        Self.logger.debug("Generated controls for node \(nodeID.uuidString.prefix(8))")
        
        // Force immediate redraw via SwiftUI overlay
        redrawTrigger += 1
        objectWillChange.send()
        
        // Give SwiftUI a moment to render the overlay before resuming simulation
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
        
        await model.resetVelocityHistory()
        await model.resumeSimulation()
    }
    
    @MainActor
    public func clearControls() async {
        await model.pauseSimulation()
        await model.updateEphemerals(selectedNodeID: nil)
        Self.logger.debug("Cleared controls")
        
        // Force immediate redraw via SwiftUI overlay
        redrawTrigger += 1
        objectWillChange.send()
        
        // Keep simulation paused when nothing is selected
    }
    
    public func updateEphemerals(selectedNodeID: NodeID?) async {
        // (your existing code with prints)
    }
    
    @MainActor
    public func repositionEphemerals(for nodeID: NodeID, to position: CGPoint) {
        model.repositionEphemerals(for: nodeID, to: position)
        Self.logger.debug("Repositioned ephemerals for node \(nodeID.uuidString.prefix(8)) to (\(position.x), \(position.y))")
    }
    
    public init(model: GraphModel) {
            self.model = model
            self.currentGraphName = model.currentGraphName  // Sync on init
            
            // Forward model's changes (store directly without assigning the whole chain)
            model.objectWillChange
                .receive(on: RunLoop.main)  // Use RunLoop.main for immediate execution in the current run loop
                .sink { [weak self] _ in
                    print("Model change forwarded to ViewModel")  // DEBUG: Confirm this prints when ephemerals change
                    self?.redrawTrigger += 1  // NEW: Increment to trigger redraw
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
            
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
            
            activeObserver = NotificationCenter.default.addObserver(forName: WKApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                // FIXED: Don't auto-resume on initial launch - only when returning from background
                guard let self = self, self.hasInitiallyLaunched else { 
                    Task { @MainActor in
                        self?.hasInitiallyLaunched = true
                    }
                    return 
                }
                NotificationCenter.default.post(name: .graphSimulationResume, object: nil)  // Trigger existing resume logic
            }
            
            // NEW: Sync isAnimating to model's simulation state (handles resumption after controls added)
            model.$isSimulating
                .receive(on: RunLoop.main)  // Use RunLoop.main for immediate updates
                .sink { [weak self] isSimulating in
                    self?.isAnimating = isSimulating
                    Self.logger.debug("Synced isAnimating to \(isSimulating) from model.isSimulating")
                }
                .store(in: &cancellables)
            
            // Setup control subscriptions (consolidated to one call)
            model.setupControlSubscriptions(
                selectedNodePublisher: $selectedNodeID.eraseToAnyPublisher()
            )
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
        let minZoom = max(calculatedMin, 0.1)  // Allow zooming out much further
        let maxZoom = minZoom * Constants.App.maxZoom  // Now higher (e.g., *5)
        
        // DEBUG log removed: Too noisy, was firing at 30fps causing log spam
        
        return (minZoom, maxZoom)
    }
    
    public func addNode(at position: CGPoint) async {
        _ = await model.addNode(at: position)
        Task { await startLayoutAnimation() }  // NEW: Animate layout after add
    }
    
    public func addToggleNode(at position: CGPoint) async {  // NEW: Add this method to fix 'no member 'addToggleNode''
        await model.addToggleNode(at: position)
        await saveAfterDelay()
    }
    
    public func addEdge(from fromID: NodeID, to targetID: NodeID, type: EdgeType = .association) async {
        await model.addEdge(from: fromID, target: targetID, type: type)
        await saveAfterDelay()
        Task { await startLayoutAnimation() }  // NEW: Animate layout after add
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
        Task { await startLayoutAnimation() }  // NEW: Re-layout after undo/redo
    }
    
    public func redo() async {
        await model.redo()
        await saveAfterDelay()
        Task { await startLayoutAnimation() }  // NEW: Re-layout after undo/redo
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
    
    // NEW: Triggers a physics-based layout animation until stable
    public func startLayoutAnimation() async {
        model.pushUndo()  // Now accessible (public)
        isAnimating = true  // Enable TimelineView for smooth redraws
        await model.runAnimatedSimulation()  // Use new public wrapper
        isAnimating = false  // Disable when done
        
        // Optional: Post-animation polish (uncomment if needed)
        await model.resetVelocityHistory()  // Clear for next run
        // model.nodes = model.physicsEngine.centerNodes(nodes: model.nodes)  // Re-center graph
        objectWillChange.send()  // Force final redraw
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
    
    @MainActor
    func handleControlTap(control: ControlNode) async {
        let action = control.kind.defaultAction()
        
        // Safe handling if ownerID were optional (recommended even if currently non-optional)
        guard let ownerID = control.ownerID else {
            Self.logger.error("Control node \(control.kind.rawValue) has no ownerID")
            return
        }
        
        await action(self, ownerID)
        
        Self.logger.debug("Handled tap on control \(control.kind.rawValue) for owner \(ownerID.uuidString.prefix(8))")
    }
    
    @MainActor
    public func setSelectedNode(_ id: NodeID?) {
        selectedNodeID = id
        selectedEdgeID = nil                                 // clear any edge selection
        focusState = id.map { .node($0) } ?? .graph
        
        // This is the only new line we need
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
    
    // MARK: - Modern Zoom-to-Fit (uses real screen size)
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
        
        // Pass the actual node objects — physicsEngine.boundingBox expects [any NodeProtocol]
        // model.visibleNodes is already [AnyNode], and AnyNode conforms to NodeProtocol
        let bounds = model.physicsEngine.boundingBox(nodes: model.visibleNodes)
            .insetBy(dx: -30, dy: -30)  // breathing room
        
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
    // MARK: - Viewport Fitting (Correct & Clean)
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
    
    @MainActor
    public func loadGraph(name: String) async throws {
        // Save current view state before switching
        try saveViewState()  // FIXED: Added 'await' assuming it's async; if not, remove 'await'
        try await model.switchToGraph(named: name)  // FIXED: Use switchToGraph(named:) which handles setting name and loading
        currentGraphName = model.currentGraphName  // Sync (unchanged)
        // Load view state for the new graph
        if let viewState = try? model.storage.loadViewState(for: currentGraphName) {  // FIXED: Used try? to handle sync throws safely
            offset = viewState.offset
            zoomScale = viewState.zoomScale
            selectedNodeID = viewState.selectedNodeID
            selectedEdgeID = viewState.selectedEdgeID
        } else {
            // No saved view state → reset to perfect fit once view appears
            offset = .zero
            zoomScale = 1.0
            // Do NOT call resetViewToFitGraph here — we don't have viewSize yet!
            // Instead, ContentView.onAppear will call it with real geo.size
            // So just reset to defaults:
            selectedNodeID = nil
            selectedEdgeID = nil
        }
        focusState = .graph
        await resumeSimulation()
        objectWillChange.send()
        Task { await startLayoutAnimation() }  // NEW: Animate initial layout on load
    }
    
    /// Deletes a graph by name.
    @MainActor
    public func deleteGraph(name: String) async throws {
        try await model.deleteGraph(named: name)
    }
    
    /// Lists all graph names.
    @MainActor
    public func listGraphNames() async throws -> [String] {
        try await model.listGraphNames()
    }
    /// Saves current view state for the current graph.
    public func saveViewState() throws {
        let viewState = ViewState(
            offset: offset,
            zoomScale: zoomScale,
            selectedNodeID: selectedNodeID,
            selectedEdgeID: selectedEdgeID
        )
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
    
    @MainActor
    func startAddingEdge(from nodeID: NodeID) {
        self.draggedNodeID = nodeID  // Or set dragStartNode
        self.pendingEdgeType = .hierarchy  // From existing code
        self.isAddingEdge = true  // Enable gesture mode (from GraphGesturesModifier)
        GraphViewModel.logger.debug("Entered add edge mode from node \(nodeID.uuidString.prefix(8))")
        // Optional: Haptic feedback – WKInterfaceDevice.current().play(.start)
    }
}

extension ControlKind {
    // Added: small logger specific to ControlKind so the extension can log without referencing GraphViewModel
    private static var logger: Logger { Logger(subsystem: "io.handcart.GraphEditor", category: "controlkind") }

    /// Returns a default action closure for this kind (watch-specific).
    /// - Returns: A closure that performs the action using GraphViewModel and owner NodeID.
    public func defaultAction() -> @MainActor (GraphViewModel, NodeID) async -> Void {  // FIXED: Added @MainActor for isolation
        switch self {
        case .addChild:
            return { viewModel, nodeID in
                await viewModel.model.addPlainChild(to: nodeID)  // Call existing model method (ensure it's public)
            }
        case .edit:
            return { viewModel, nodeID in
                viewModel.isEditMode.toggle()
                if viewModel.isEditMode {
                    await viewModel.generateControls(for: nodeID)  // Show extras
                    await viewModel.model.pauseSimulation()  // Or node-specific pause
                    viewModel.model.editingNodeID = nodeID  // Open editor sheet on enter (merged old action)
                } else {
                    await viewModel.clearControls()
                    await viewModel.model.resumeSimulation()
                    
                    // Fixed: Proper error handling instead of force-try
                    do {
                        try await viewModel.model.saveGraph()
                        Self.logger.info("Auto-saved graph on edit mode exit")
                    } catch {
                        Self.logger.error("Auto-save failed on edit mode exit: \(error.localizedDescription)")
                        // Optional: You could also notify the user here (e.g., via a haptic or alert),
                        // but logging is sufficient for a background auto-save.
                    }
                }
                WKInterfaceDevice.current().play(.click)
                Self.logger.debug("Toggled edit mode for node \(nodeID.uuidString.prefix(8)): \(viewModel.isEditMode)")
            }
        case .addEdge:
            return { viewModel, nodeID in
                if viewModel.isEditMode {
                    viewModel.startAddingEdge(from: nodeID)  // Proceed only in edit mode
                } else {
                    Self.logger.warning("Add edge attempted outside edit mode for node \(nodeID.uuidString.prefix(8))")
                    // Optional: viewModel.isEditMode = true; await viewModel.generateControls(for: nodeID)  // Auto-enter mode if desired
                }
            }
        }
    }
}
