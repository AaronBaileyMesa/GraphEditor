import SwiftUI
import Combine  // Add this import for AnyCancellable

class GraphViewModel: ObservableObject {
    @Published var model: GraphModel
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
    
    func deleteNode(withID id: UUID) {
        model.deleteNode(withID: id)
    }
    
    func deleteEdge(withID id: UUID) {
        model.deleteEdge(withID: id)
    }
}
