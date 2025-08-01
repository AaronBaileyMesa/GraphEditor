//
//  GraphViewModel.swift
//  GraphEditor
//
//  Created by handcart on 7/31/25.
//


import SwiftUI

class GraphViewModel: ObservableObject {
    @ObservedObject var model: GraphModel
    
    init(model: GraphModel) {
        self.model = model
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
    
    func deleteNode(withID id: UUID) {
        model.deleteNode(withID: id)
    }
    
    func deleteEdge(withID id: UUID) {
        model.deleteEdge(withID: id)
    }
}
