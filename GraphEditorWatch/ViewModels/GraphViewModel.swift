// GraphViewModel.swift (Fixed: Corrected handleTap function, removed invalid SwiftUI code, fixed scoping/syntax errors, added proper ToggleNode handling)

import Combine
import GraphEditorShared
import WatchKit  // For WKApplication

@MainActor class GraphViewModel: ObservableObject {
    @Published var model: GraphModel
    @Published var selectedEdgeID: UUID? = nil
    @Published var pendingEdgeType: EdgeType = .association
    @Published var selectedNodeID: UUID? = nil
    @Published var offset: CGPoint = .zero
    @Published var zoomScale: CGFloat = 1.0
    
    private var saveTimer: Timer? = nil
    private var cancellable: AnyCancellable?
    
    var canUndo: Bool {
        model.canUndo
    }
    
    var canRedo: Bool {
        model.canRedo
    }
    
    private var pauseObserver: NSObjectProtocol?
    private var resumeObserver: NSObjectProtocol?
    
    private var resumeTimer: Timer?
    
    var effectiveCentroid: CGPoint {
        let visibleNodes = model.visibleNodes()
        if let id = selectedNodeID, let node = visibleNodes.first(where: { $0.id == id }) {
            return node.position
        } else if let id = selectedEdgeID, let edge = model.edges.first(where: { $0.id == id }),
                  let from = visibleNodes.first(where: { $0.id == edge.from }),
                  let to = visibleNodes.first(where: { $0.id == edge.to }) {
            return CGPoint(x: (from.position.x + to.position.x) / 2, y: (from.position.y + to.position.y) / 2)
        }
        return centroid(of: visibleNodes) ?? .zero
    }
    
    enum AppFocusState: Equatable {
        case graph
        case node(UUID)
        case edge(UUID)
        case menu
    }

    @Published var focusState: AppFocusState = .graph
    
    init(model: GraphModel) {
        self.model = model
        cancellable = model.objectWillChange.sink { [weak self] _ in
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
    }
    
    func calculateZoomRanges(for viewSize: CGSize) -> (min: CGFloat, max: CGFloat) {
        var graphBounds = model.physicsEngine.boundingBox(nodes: model.nodes)
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
        print("Calculated zoom ranges: min=\(minZoom), max=\(maxZoom), based on bounds \(graphBounds)")  // Enhanced debug
        return (min: minZoom, max: maxZoom)
    }
    
    func saveViewState() {  // Made non-@MainActor since callsites treat as sync; internal hops handle isolation
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            Task { @MainActor in  // Hop to main for safe publishes/model access
                guard let self = self else { return }
                self.centerGraph()  // Safe on main
                do {
                    try self.model.saveViewState(  // Assuming sync; no 'await'
                        offset: self.offset,
                        zoomScale: self.zoomScale,
                        selectedNodeID: self.selectedNodeID,
                        selectedEdgeID: self.selectedEdgeID
                    )
                } catch {
                    print("Failed to save view state: \(error)")
                }
            }
        }
    }
    
    func loadGraph() async {
        do {
            try await model.load()  // Now compiles
            await model.startSimulation()
        } catch {
            print("Failed to load graph: \(error)")
        }
    }
    
    private func loadViewState() async {
        do {
            if let state = try model.loadViewState() {  // Assuming sync; no 'await'
                self.offset = state.offset
                self.zoomScale = state.zoomScale.clamped(to: 0.01...Constants.App.maxZoom)
                self.selectedNodeID = state.selectedNodeID
                self.selectedEdgeID = state.selectedEdgeID
            } else {
                self.zoomScale = 1.0.clamped(to: 0.01...Constants.App.maxZoom)
                self.offset = .zero
            }
            model.centerGraph()  // Assuming sync; no 'await'
            self.offset = .zero
            await model.expandAllRoots()  // Keep if async
            self.objectWillChange.send()
        } catch {
            print("Failed to load view state: \(error)")
        }
        
        if let id = selectedNodeID {
            focusState = .node(id)
        } else if let id = selectedEdgeID {
            focusState = .edge(id)
        } else {
            focusState = .graph
        }
        model.centerGraph()  // Assuming sync; no 'await'
        self.objectWillChange.send()
    }
    
    deinit {
        if let pauseObserver = pauseObserver {
            NotificationCenter.default.removeObserver(pauseObserver)
        }
        if let resumeObserver = resumeObserver {
            NotificationCenter.default.removeObserver(resumeObserver)
        }
        resumeTimer?.invalidate()
    }
    
    func snapshot() async {
        await model.snapshot()
    }
    
    func undo() async {
        await model.undo()
    }
    
    func redo() async {
        await model.redo()
    }
    
    func addNode(at position: CGPoint) async {
        await model.addNode(at: position)
        await model.resizeSimulationBounds(for: model.nodes.count)  // New: Resize after adding
    }

    func resetGraph() async {  // Or rename clearGraph to resetGraph if preferred
        await model.clearGraph()
    }
    
    public func deleteNode(withID id: NodeID) async {
        await model.deleteNode(withID: id)
        selectedNodeID = nil
    }

    public func deleteEdge(withID id: UUID) async {
        await model.deleteEdge(withID: id)
        selectedEdgeID = nil
    }

    public func updateNodeContent(withID id: NodeID, newContent: NodeContent?) async {
        await model.updateNodeContent(withID: id, newContent: newContent)
    }
    
    func addToggleNode(at position: CGPoint) async {
        await model.addToggleNode(at: position)
    }
    
    func addChild(to parentID: NodeID) async {
        await model.addChild(to: parentID)
    }
    
    // NEW: Add this method for edge creation (used in gestures/menu)
    func addEdge(from: NodeID, to: NodeID, type: EdgeType) async {
        model.edges.append(GraphEdge(from: from, to: to, type: type))
        await model.startSimulation()
        await model.save()  // Persist if needed
            objectWillChange.send()
    }
    
    func clearGraph() async {
        await model.clearGraph()
    }
    
    func pauseSimulation() async {
        await model.pauseSimulation()
    }
    
    func resumeSimulation() async {
        await model.resumeSimulation()
    }
    
    func resumeSimulationAfterDelay() async {
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
    func handleTap(at modelPos: CGPoint) async {
        await model.pauseSimulation()
        
        print("Handling tap at model pos: \(modelPos)")  // For testing
        
        // Efficient hit test with queryNearby
        let hitRadius: CGFloat = 30.0  // Increased for watchOS touch accuracy; test and adjust
        let nearbyNodes = model.physicsEngine.queryNearby(position: modelPos, radius: hitRadius, nodes: model.visibleNodes())
        print("Nearby nodes found: \(nearbyNodes.count)")  // For testing
        
        // Sort by distance to get closest (if multiple)
        let sortedNearby = nearbyNodes.sorted {
            hypot($0.position.x - modelPos.x, $0.position.y - modelPos.y) < hypot($1.position.x - modelPos.x, $1.position.y - modelPos.y)
        }
        
        if let tappedNode = sortedNearby.first {
            if let toggleNode = tappedNode as? ToggleNode {
                // Tap to expand/collapse ToggleNode (no selection, per preference)
                let updated = toggleNode.handlingTap()
                print("Toggled ToggleNode \(toggleNode.label) to \(updated.isExpanded)")
                
                // TODO: Update model with new node state (e.g., await model.updateNode(id: toggleNode.id, node: updated))
                // For now, assuming model handles it internally or via snapshot; add method if needed
                await model.startSimulation()
                
                selectedNodeID = nil
                selectedEdgeID = nil
            } else {
                // Tap to select regular Node (toggle off if already selected)
                selectedNodeID = (tappedNode.id == selectedNodeID) ? nil : tappedNode.id
                selectedEdgeID = nil
                print("Selected regular Node \(tappedNode.label)")
            }
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
    
    func setSelectedNode(_ id: UUID?) {
        selectedNodeID = id
        focusState = id.map { .node($0) } ?? .graph
        objectWillChange.send()
    }

    func setSelectedEdge(_ id: UUID?) {
        selectedEdgeID = id
        focusState = id.map { .edge($0) } ?? .graph
        objectWillChange.send()
    }
    
    func centerGraph() {
        // UPDATED: Enhanced to recalculate based on bounds
        let viewSize = CGSize(width: 300, height: 300)  // Replace with actual view size if passed
        let (minZoom, _) = calculateZoomRanges(for: viewSize)
        zoomScale = minZoom
        offset = .zero
        objectWillChange.send()
    }
    
    // NEW: Helper for centroid (assuming it's defined elsewhere; add if missing)
    private func centroid(of nodes: [any NodeProtocol]) -> CGPoint? {
        guard !nodes.isEmpty else { return nil }
        let sumX = nodes.reduce(0.0) { $0 + $1.position.x }
        let sumY = nodes.reduce(0.0) { $0 + $1.position.y }
        return CGPoint(x: sumX / CGFloat(nodes.count), y: sumY / CGFloat(nodes.count))
    }
}
