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
    
    init(model: GraphModel) {
        self.model = model
        cancellable = model.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
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
    
    
}
