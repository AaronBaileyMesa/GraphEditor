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

class GraphViewModel: ObservableObject {
    @Published var model: GraphModel
    @Published var selectedEdgeID: UUID? = nil  // New: For edge selection
    
    private var cancellable: AnyCancellable?
    
    var canUndo: Bool {
        model.canUndo
    }
    
    var canRedo: Bool {
        model.canRedo
    }
    
    private var pauseObserver: NSObjectProtocol?
    private var resumeObserver: NSObjectProtocol?
    
    init(model: GraphModel) {
        self.model = model
        cancellable = model.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
            
        }
        pauseObserver = NotificationCenter.default.addObserver(forName: .graphSimulationPause, object: nil, queue: .main) { [weak self] _ in
            self?.model.pauseSimulation()
        }
        resumeObserver = NotificationCenter.default.addObserver(forName: .graphSimulationResume, object: nil, queue: .main) { [weak self] _ in
            self?.model.resumeSimulation()
            
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
    func handleTap() {  // Call this before/after selection in gesture
        model.pauseSimulation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {  // 0.5s delay for stability
            self.model.resumeSimulation()
        }
    }
    
}
