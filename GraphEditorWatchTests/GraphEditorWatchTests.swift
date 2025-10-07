import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
@testable import GraphEditorShared
import XCTest
import SwiftUI

class MockGraphStorage: GraphStorage {
    // In-memory single-graph (default) storage for convenience in tests
    var nodes: [any NodeProtocol] = []
    var edges: [GraphEdge] = []
    var savedViewState: ViewState?

    // In-memory multi-graph storage
    private var graphs: [String: (nodes: [any NodeProtocol], edges: [GraphEdge])] = [:]
    private var viewStates: [String: ViewState] = [:]
    private let defaultName = "default"

    // MARK: - Single-graph (default) methods
    func save(nodes: [any NodeProtocol], edges: [GraphEdge]) async throws {
        self.nodes = nodes
        self.edges = edges
        // Keep default graph in sync
        graphs[defaultName] = (nodes, edges)
    }

    func load() async throws -> (nodes: [any NodeProtocol], edges: [GraphEdge]) {
        return (nodes, edges)
    }

    func clear() async throws {
        nodes = []
        edges = []
        savedViewState = nil
        graphs[defaultName] = ([], [])
        viewStates.removeValue(forKey: defaultName)
    }

    func saveViewState(_ viewState: ViewState) async throws {
        savedViewState = viewState
        viewStates[defaultName] = viewState
    }

    func loadViewState() async throws -> ViewState? {
        return savedViewState
    }

    // MARK: - Multi-graph methods
    func listGraphNames() async throws -> [String] {
        var names = Set(graphs.keys)
        names.insert(defaultName)
        return Array(names).sorted()
    }

    func createNewGraph(name: String) async throws {
        if graphs[name] != nil {
            throw GraphStorageError.graphExists(name)
        }
        graphs[name] = ([], [])
        viewStates.removeValue(forKey: name)
    }

    func save(nodes: [any NodeProtocol], edges: [GraphEdge], for name: String) async throws {
        graphs[name] = (nodes, edges)
        if name == defaultName {
            self.nodes = nodes
            self.edges = edges
        }
    }

    func load(for name: String) async throws -> (nodes: [any NodeProtocol], edges: [GraphEdge]) {
        if name == defaultName {
            return (nodes, edges)
        }
        if let state = graphs[name] {
            return state
        }
        throw GraphStorageError.graphNotFound(name)
    }

    func deleteGraph(name: String) async throws {
        if name == defaultName {
            nodes = []
            edges = []
            savedViewState = nil
            graphs[defaultName] = ([], [])
            viewStates.removeValue(forKey: defaultName)
            return
        }
        guard graphs.removeValue(forKey: name) != nil else {
            throw GraphStorageError.graphNotFound(name)
        }
        viewStates.removeValue(forKey: name)
    }

    // MARK: - View state per graph (sync variants required by protocol)
    func saveViewState(_ viewState: ViewState, for name: String) throws {
        viewStates[name] = viewState
        if name == defaultName {
            savedViewState = viewState
        }
    }

    func loadViewState(for name: String) throws -> ViewState? {
        if name == defaultName {
            return savedViewState ?? viewStates[name]
        }
        return viewStates[name]
    }
}

@MainActor @Test func testUndoRedoRoundTrip() async {
    let storage = MockGraphStorage()
    let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
    let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
    try? await model.loadGraph()  // Explicit load to start empty
    let initialNode = AnyNode(Node(id: UUID(), label: 1, position: .zero))
    await model.snapshot()  // Pre-add initial (appends empty)
    model.nodes = [initialNode]  // "Add" initial
    let newNode = AnyNode(Node(id: UUID(), label: 2, position: .zero))
    await model.snapshot()  // Pre-add new (appends [initial])
    model.nodes.append(newNode)  // Add new
    await model.undo()  // Back to 1 node
    #expect(await model.nodes.count == 1, "Undo removes node")
    #expect(await model.nodes[0].id == initialNode.id, "Initial state restored")
    #expect(await model.redoStack.count == 1, "Redo stack populated")
    await model.redo()  // Forward to 2 nodes
    #expect(await model.nodes.count == 2, "Redo adds node")
    #expect(await model.undoStack.count == 2, "Undo stack updated")
}

func approximatelyEqual(_ lhs: CGPoint, _ rhs: CGPoint, accuracy: CGFloat) -> Bool {
    return hypot(lhs.x - rhs.x, lhs.y - rhs.y) < accuracy
}
