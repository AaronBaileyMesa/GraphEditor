// GraphViewModel.swift (Fixed: Corrected handleTap function, removed invalid SwiftUI code, fixed scoping/syntax errors, added proper ToggleNode handling)

import Combine
import GraphEditorShared
import WatchKit  // For WKApplication

@MainActor public class GraphViewModel: ObservableObject {
    @Published public var model: GraphModel
    @Published public var selectedEdgeID: UUID? = nil
    @Published public var pendingEdgeType: EdgeType = .association
    @Published public var selectedNodeID: UUID? = nil
    @Published public var offset: CGPoint = .zero
    @Published public var zoomScale: CGFloat = 1.0
    
    private var saveTimer: Timer? = nil
    private var cancellable: AnyCancellable?
    
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
                  let to = visibleNodes.first(where: { $0.id == edge.target }) {
            return CGPoint(x: (from.position.x + to.position.x) / 2, y: (from.position.y + to.position.y) / 2)
        }
        return centroid(of: visibleNodes) ?? .zero
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

        model.nodes = model.nodes.map { AnyNode($0.with(position: $0.position, velocity: .zero)) }
    }
    
    public func calculateZoomRanges(for viewSize: CGSize) -> (min: CGFloat, max: CGFloat) {
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
    
    // Updated saveViewState in GraphViewModel.swift to handle throwing call with do-try-catch
    public func saveViewState() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                do {
                    try await self.model.saveViewState(
                        offset: self.offset,
                        zoomScale: self.zoomScale,
                        selectedNodeID: self.selectedNodeID,
                        selectedEdgeID: self.selectedEdgeID
                    )
                } catch {
                    print("Error saving view state: \(error)")
                    // Optionally, add user-facing error handling, e.g., set a @Published error property
                }
            }
        }
    }
    
    public func loadGraph() async {
            await model.load()  // Now compiles
            await model.startSimulation()
    }
    
    private func loadViewState() async {
        do {
            if let state = try await model.loadViewState() {
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
    
    public func snapshot() async {
        await model.snapshot()
    }
    
    public func undo() async {
        await model.undo()
    }
    
    public func redo() async {
        await model.redo()
    }
    
    public func addNode(at position: CGPoint) async {
        await model.addNode(at: position)
        await model.resizeSimulationBounds(for: model.nodes.count)  // New: Resize after adding
        model.objectWillChange.send()
    }

    public func resetGraph() async {  // Or rename clearGraph to resetGraph if preferred
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
    
    public func updateNodePosition(id: NodeID, newPosition: CGPoint) async {
        if let index = model.nodes.firstIndex(where: { $0.id == id }) {
            model.nodes[index].position = newPosition
            model.nodes[index].velocity = .zero  // Stop movement
            await model.startSimulation()
        }
    }
    
    public func addToggleNode(at position: CGPoint) async {
        await model.addToggleNode(at: position)
    }
    
    public func addChild(to parentID: NodeID) async {
        await model.addChild(to: parentID)
    }
    
    // NEW: Add this method for edge creation (used in gestures/menu)
    public func addEdge(from: NodeID, to: NodeID, type: EdgeType) async {
        model.edges.append(GraphEdge(from: from, to: to, type: type))
        await model.startSimulation()
        await model.save()  // Persist if needed
            objectWillChange.send()
    }
    
    public func clearGraph() async {
        await model.clearGraph()
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
                print("Selected node \(tappedNode.label) (type: \(type(of: tappedNode))")
                
                // Add toggle if ToggleNode
            if let toggleNode = tappedNode as? ToggleNode {
                        let toggled = toggleNode.handlingTap()
                        if let index = model.nodes.firstIndex(where: { $0.id == toggled.id }) {
                            model.nodes[index] = AnyNode(toggled)
                            await model.handleTap(on: toggled.id)  // Reposition
                            // Immediate offset if expanded
                            if toggled.isExpanded {
                                let children = model.edges.filter { $0.from == toggled.id && $0.type == .hierarchy }.map { $0.target }
                                for (idx, childID) in children.enumerated() {
                                    if let childIdx = model.nodes.firstIndex(where: { $0.id == childID }) {
                                        var child = model.nodes[childIdx]
                                        let offX = CGFloat(idx * 20) - CGFloat(children.count * 10)
                                        child.position += CGPoint(x: offX, y: 20)
                                        model.nodes[childIdx] = child
                                    }
                                }
                            }
                        }
                    }
            model.objectWillChange.send()  // Trigger UI refresh
            
            // Delay simulation restart slightly to let changes settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                Task {
                    await self.model.startSimulation()
                }
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
