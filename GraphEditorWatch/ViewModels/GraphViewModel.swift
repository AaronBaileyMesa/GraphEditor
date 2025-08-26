// GraphViewModel.swift (Add access to model's physicsEngine and confirm centerGraph)

import SwiftUI
import Combine
import GraphEditorShared
import WatchKit  // For WKApplication

class GraphViewModel: ObservableObject {
    @Published var model: GraphModel
    @Published var selectedEdgeID: UUID? = nil
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
            self?.model.pauseSimulation()
        }
        resumeObserver = NotificationCenter.default.addObserver(forName: .graphSimulationResume, object: nil, queue: .main) { [weak self] _ in
            self?.resumeSimulationAfterDelay()
        }
        
        loadGraph()
        loadViewState()
    }
    
    func calculateZoomRanges(for viewSize: CGSize) -> (min: CGFloat, max: CGFloat) {
        let graphBounds = model.physicsEngine.boundingBox(nodes: model.nodes)  // Fixed: Access via model.physicsEngine
        guard graphBounds.width > 0 && graphBounds.height > 0 else {
            return (AppConstants.defaultMinZoom, AppConstants.defaultMaxZoom)
        }
        
        let fitScaleWidth = viewSize.width / graphBounds.width * AppConstants.zoomPaddingFactor
        let fitScaleHeight = viewSize.height / graphBounds.height * AppConstants.zoomPaddingFactor
        let minZoom = min(fitScaleWidth, fitScaleHeight)
        let maxZoom = max(minZoom * 5, AppConstants.defaultMaxZoom)
        
        print("Updated zoom ranges: min=\(minZoom), max=\(maxZoom)")
        return (minZoom, maxZoom)
    }
    
    func saveViewState() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.centerGraph()  // Center before save
            do {
                try self.model.saveViewState(offset: self.offset,
                                             zoomScale: self.zoomScale,
                                             selectedNodeID: self.selectedNodeID,
                                             selectedEdgeID: self.selectedEdgeID)
                print("Saved view state")
            } catch {
                print("Failed to save view state: \(error)")
            }
        }
    }
    
    func loadGraph() {
        do {
            try model.loadFromStorage()
            model.centerGraph()
            model.startSimulation()
        } catch {
            print("Failed to load graph: \(error)")
        }
    }
    
    private func loadViewState() {
        do {
            if let state = try model.loadViewState() {
                self.offset = state.offset
                self.zoomScale = state.zoomScale.clamped(to: 0.01...Constants.App.maxZoom)
                self.selectedNodeID = state.selectedNodeID
                self.selectedEdgeID = state.selectedEdgeID
            } else {
                self.zoomScale = 1.0.clamped(to: 0.01...Constants.App.maxZoom)
                self.offset = .zero
            }
            model.centerGraph()
            self.offset = .zero
            model.expandAllRoots()
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
        model.centerGraph()
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
    
    func snapshot() {
        model.snapshot()
    }
    
    func undo() {
        model.undo()
    }
    
    func redo() {
        model.redo()
    }
    
    func addNode(at position: CGPoint) {
        model.addNode(at: position)
    }

    func resetGraph() {  // Or rename clearGraph to resetGraph if preferred
        model.clearGraph()
    }
    
    public func deleteNode(withID id: NodeID) {
        model.deleteNode(withID: id)
        selectedNodeID = nil
    }

    public func deleteEdge(withID id: UUID) {
        model.deleteEdge(withID: id)
        selectedEdgeID = nil
    }

    public func updateNodeContent(withID id: NodeID, newContent: NodeContent?) {
        model.updateNodeContent(withID: id, newContent: newContent)
    }
    
    func addToggleNode(at position: CGPoint) {
        model.addToggleNode(at: position)
    }
    
    func addChild(to parentID: NodeID) {
        model.addChild(to: parentID)
    }
    
    func clearGraph() {
        model.clearGraph()
    }
    
    func pauseSimulation() {
        model.pauseSimulation()
    }
    
    func resumeSimulation() {
        model.resumeSimulation()
    }
    
    func resumeSimulationAfterDelay() {
        resumeTimer?.invalidate()
        resumeTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if WKApplication.shared().applicationState == .active {
                self.model.resumeSimulation()
            }
        }
    }
    
    func handleTap() {
        model.pauseSimulation()
        resumeSimulationAfterDelay()
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
        offset = .zero  // Basic reset; enhance as needed
        objectWillChange.send()
    }
}
