//
//  GraphViewModel+NodeOperations.swift
//  GraphEditorWatch
//
//  Extension for node and edge CRUD operations, undo/redo

import Foundation
import GraphEditorShared

// MARK: - Node & Edge Operations
extension GraphViewModel {
    
    // MARK: Adding Nodes & Edges
    
    public func addNode(at position: CGPoint) async {
        _ = await model.addNode(at: position)
        Task { await startLayoutAnimation() }
    }
    
    public func addToggleNode(at position: CGPoint) async {
        await model.addToggleNode(at: position)
        await saveAfterDelay()
    }
    
    public func addEdge(from fromID: NodeID, to targetID: NodeID, type: EdgeType = .association) async {
        await model.addEdge(from: fromID, target: targetID, type: type)
        await saveAfterDelay()
        Task { await startLayoutAnimation() }
    }
    
    // MARK: Moving Nodes
    
    @MainActor
    func moveNode(_ node: any NodeProtocol, to newPosition: CGPoint) async {
        await model.moveNode(node, to: newPosition)
    }
    
    // MARK: Deleting Nodes & Edges
    
    public func deleteSelected() async {
        await model.deleteSelected(selectedNodeID: selectedNodeID, selectedEdgeID: selectedEdgeID)
        selectedNodeID = nil
        selectedEdgeID = nil
        await saveAfterDelay()
    }
    
    public func deleteNode(withID id: NodeID) async {
        await model.deleteNode(withID: id)
        if selectedNodeID == id { selectedNodeID = nil }
        selectedEdgeID = nil
        await saveAfterDelay()
    }
    
    public func clearGraph() async {
        await model.resetGraph()
        await saveAfterDelay()
    }
    
    // MARK: Toggle Node Operations
    
    public func toggleExpansion(for nodeID: NodeID) async {
        await model.toggleExpansion(for: nodeID)
        await saveAfterDelay()
    }
    
    public func toggleSelectedNode() async {
        if let id = selectedNodeID {
            await toggleExpansion(for: id)
        }
    }
    
    // MARK: Undo & Redo
    
    public func undo() async {
        await model.undo()
        await saveAfterDelay()
        Task { await startLayoutAnimation() }
    }
    
    public func redo() async {
        await model.redo()
        await saveAfterDelay()
        Task { await startLayoutAnimation() }
    }
}
