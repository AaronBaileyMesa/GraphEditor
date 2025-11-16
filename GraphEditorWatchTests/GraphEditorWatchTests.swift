
//
//  MockGraphStorage.swift
//  GraphEditorShared
//
//  Created by handcart on 11/6/25.
//

import Testing
@testable import GraphEditorWatch
import XCTest
import SwiftUI
import Foundation  // For UUID, JSONEncoder, JSONDecoder
import CoreGraphics  // For CGPoint
@testable import GraphEditorShared

class MockGraphStorage: GraphStorage {
    // In-memory multi-graph storage using full GraphState (includes colors)
    private var graphs: [String: GraphState] = [:]
    private var viewStates: [String: ViewState] = [:]
    private let defaultName = "default"
    
    // Derived single-graph properties for convenience in tests (syncs with default graph)
    var nodes: [any NodeProtocol] {
        get { graphs[defaultName]?.nodes ?? [] }
        set {
            let currentState = graphs[defaultName] ?? GraphState(nodes: [], edges: [], hierarchyEdgeColor: CodableColor(.blue), associationEdgeColor: CodableColor(.white))
            let updatedState = GraphState(nodes: newValue, edges: currentState.edges, hierarchyEdgeColor: currentState.hierarchyEdgeColor, associationEdgeColor: currentState.associationEdgeColor)
            graphs[defaultName] = updatedState
        }
    }
    
    var edges: [GraphEdge] {
        get { graphs[defaultName]?.edges ?? [] }
        set {
            let currentState = graphs[defaultName] ?? GraphState(nodes: [], edges: [], hierarchyEdgeColor: CodableColor(.blue), associationEdgeColor: CodableColor(.white))
            let updatedState = GraphState(nodes: currentState.nodes, edges: newValue, hierarchyEdgeColor: currentState.hierarchyEdgeColor, associationEdgeColor: currentState.associationEdgeColor)
            graphs[defaultName] = updatedState
        }
    }
    
    var savedViewState: ViewState? {
        get { viewStates[defaultName] }
        set { viewStates[defaultName] = newValue }
    }
    
    // MARK: - Single-graph (default) methods (using default graph under the hood)
    // Note: Removed deprecated save(nodes:edges:) and load() as they are not used/needed.
    
    func clear() async throws {  // Clear all for full reset in tests
        graphs.removeAll()
        viewStates.removeAll()
    }
    
    func saveViewState(_ viewState: ViewState) throws {  // Changed to sync (remove async)
        viewStates[defaultName] = viewState
    }
    
    func loadViewState() throws -> ViewState? {  // Changed to sync (remove async)
        return viewStates[defaultName]
    }
    
    // MARK: - Multi-graph methods
    func listGraphNames() async throws -> [String] {
        return Array(graphs.keys).sorted()
    }
    
    func createNewGraph(name: String) async throws {
        if graphs[name] != nil {
            throw GraphStorageError.graphExists(name)
        }
        graphs[name] = GraphState(nodes: [], edges: [], hierarchyEdgeColor: CodableColor(.blue), associationEdgeColor: CodableColor(.white))
        viewStates.removeValue(forKey: name)
    }
    
    // Note: Removed deprecated save(nodes:edges:for:) and load(for:) as they are not used/needed.
    
    func deleteGraph(name: String) async throws {
        guard graphs.removeValue(forKey: name) != nil else {
            throw GraphStorageError.graphNotFound(name)
        }
        viewStates.removeValue(forKey: name)
    }
    
    // MARK: - View state per graph (synchronous variants required by protocol)
    func saveViewState(_ viewState: ViewState, for name: String) throws {
        viewStates[name] = viewState
    }
    
    func loadViewState(for name: String) throws -> ViewState? {
        return viewStates[name]
    }
    
    // MARK: - GraphState methods (now fully implemented)
    public func saveGraphState(_ graphState: GraphState, for name: String) async throws {
        graphs[name] = graphState
    }

    public func loadGraphState(for name: String) async throws -> GraphState {
        guard let state = graphs[name] else {
            throw GraphStorageError.graphNotFound(name)
        }
        return state
    }
}

@MainActor @Test func testUndoRedoRoundTrip() async {
    let storage = MockGraphStorage()
    let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
    let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
    await model.loadGraph()  // Explicit load to start empty
    let initialNode = AnyNode(Node(id: UUID(), label: 1, position: .zero))
    await model.snapshot()  // Pre-add initial (appends empty)
    model.nodes = [initialNode]  // "Add" initial
    let newNode = AnyNode(Node(id: UUID(), label: 2, position: .zero))
    await model.snapshot()  // Pre-add new (appends [initial])
    model.nodes.append(newNode)  // Add new
    await model.undo()  // Back to 1 node
    #expect(model.nodes.count == 1, "Undo removes node")
    #expect(model.nodes[0].id == initialNode.id, "Initial state restored")
    #expect(model.redoStack.count == 1, "Redo stack populated")
    await model.redo()  // Forward to 2 nodes
    #expect(model.nodes.count == 2, "Redo adds node")
    #expect(model.undoStack.count == 2, "Undo stack updated")
}
