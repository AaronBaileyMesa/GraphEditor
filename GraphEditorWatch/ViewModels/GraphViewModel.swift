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
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            print("Debounced save: selectedNodeID = \(self.selectedNodeID?.uuidString ?? "nil")")  // Optional debug
            try? self.model.saveViewState(offset: self.offset, zoomScale: self.zoomScale, selectedNodeID: self.selectedNodeID, selectedEdgeID: self.selectedEdgeID)
        }
    }
    
    // Added: Reloads graph data from storage (mirrors init logic)
    func loadGraph() {
        do {
            try model.loadFromStorage()  // Use public wrapper (avoids private 'storage' access)
        } catch {
            print("Load graph failed: \(error.localizedDescription)")  // Or log as in model
        }
        objectWillChange.send()
    }
    
    // Added: Loads and applies view state (extracted from original init)
    func loadViewState() {
        if let state = try? model.loadViewState() {
            print("Loaded view state: selectedNodeID = \(state.selectedNodeID?.uuidString ?? "nil")")
            self.offset = state.offset
            self.zoomScale = state.zoomScale
            self.selectedNodeID = state.selectedNodeID
            self.selectedEdgeID = state.selectedEdgeID
            self.objectWillChange.send()  // Refresh views with loaded selection
        }
        
        print("Loaded ID: \(selectedNodeID?.uuidString ?? "nil"), Node exists? \(model.nodes.contains { $0.id == selectedNodeID ?? UUID() })")  // Adjust to unwrap
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
}
