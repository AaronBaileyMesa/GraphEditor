//
//  GraphViewModel.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//

// ViewModels/GraphViewModel.swift
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
        
        if let state = try? model.loadViewState() {
            print("Loaded view state: selectedNodeID = \(state.selectedNodeID?.uuidString ?? "nil")")
            self.offset = state.offset
            self.zoomScale = state.zoomScale
            self.selectedNodeID = state.selectedNodeID
            self.selectedEdgeID = state.selectedEdgeID
            self.objectWillChange.send()  // Add this to refresh views with loaded selection
        }
        
        print("Loaded ID: \(selectedNodeID), Node exists? \(model.nodes.contains { $0.id == selectedNodeID })")
    }
    
    // New method to save (call from views)
    func saveViewState() {
        print("Saving view state: selectedNodeID = \(selectedNodeID?.uuidString ?? "nil")")
        try? model.saveViewState(offset: offset, zoomScale: zoomScale, selectedNodeID: selectedNodeID, selectedEdgeID: selectedEdgeID)
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
