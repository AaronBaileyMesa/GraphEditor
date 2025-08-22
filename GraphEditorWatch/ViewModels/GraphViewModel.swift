//  GraphViewModel.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.

import SwiftUI
import Combine
import GraphEditorShared
import WatchKit  // For WKApplication

class GraphViewModel: ObservableObject {
    @Published var model: GraphModel
    @Published var selectedEdgeID: UUID? = nil  // New: For edge selection
    @Published var selectedNodeID: UUID? = nil  // Add this; matches bindings in views
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
    
    // New: Timer for debounced resumes
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
        return visibleNodes.centroid() ?? .zero
    }
    
    // New: Enum for focus state, now Equatable
    enum AppFocusState: Equatable {
        case graph
        case node(UUID)
        case edge(UUID)
        case menu
    }

    @Published var focusState: AppFocusState = .graph  // New
    
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
        
        // Call new methods to load on init (preserves original behavior without duplication)
        loadGraph()
        loadViewState()
    }
    
    // New method to save (call from views)
    func saveViewState() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            do {
                try self.model.saveViewState(offset: self.offset, zoomScale: self.zoomScale, selectedNodeID: self.selectedNodeID, selectedEdgeID: self.selectedEdgeID)
                print("Debounced save: selectedNodeID = \(self.selectedNodeID?.uuidString ?? "nil")")
            } catch {
                print("Failed to save view state: \(error)")
            }
        }
    }
    
    // New method to load graph
    private func loadGraph() {
        do {
            try model.loadFromStorage()
            model.startSimulation()
        } catch {
            print("Failed to load graph: \(error)")
        }
    }
    
    // New method to load view state
    private func loadViewState() {
        do {
            if let state = try model.loadViewState() {
                self.offset = state.offset
                self.zoomScale = state.zoomScale
                self.selectedNodeID = state.selectedNodeID
                self.selectedEdgeID = state.selectedEdgeID
                print("Loaded view state: selectedNodeID = \(state.selectedNodeID?.uuidString ?? "nil")")
                if let loadedID = state.selectedNodeID {
                    print("Loaded ID: \(loadedID.uuidString), Node exists? \(model.nodes.contains { $0.id == loadedID })")
                }
            } else {
                self.zoomScale = 1.0  // Default, but onUpdateZoomRanges will override to fit
            }
            self.objectWillChange.send()
        } catch {
            print("Failed to load view state: \(error)")
        }
        
        // After loading IDs, set focusState
        if let id = selectedNodeID {
            focusState = .node(id)
        } else if let id = selectedEdgeID {
            focusState = .edge(id)
        } else {
            focusState = .graph
        }
    }
    
    deinit {
        // Clean up to avoid leaks
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
    
    func deleteNode(withID id: NodeID) {
        model.deleteNode(withID: id)
    }
    
    func deleteSelectedEdge(id: UUID?) {
        model.deleteSelectedEdge(id: id)
    }
    
    func addNode(at position: CGPoint) {
        model.addNode(at: position)
    }
    
    func updateNode(_ updatedNode: any NodeProtocol) {
        model.updateNode(updatedNode)
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
    
    // New: Debounced resume with app state check
    func resumeSimulationAfterDelay() {
        resumeTimer?.invalidate()
        resumeTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if WKApplication.shared().applicationState == .active {
                self.model.resumeSimulation()
            }
        }
    }
    
    func handleTap() {  // Call this before/after selection in gesture
        model.pauseSimulation()
        resumeSimulationAfterDelay()  // Use debounced method
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
}
