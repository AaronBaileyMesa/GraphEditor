//
//  PersistenceErrorTests.swift
//  GraphEditorWatchTests
//
//  Tests for persistence error handling and recovery
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
@testable import GraphEditorShared

// Mock storage that can simulate failures
class FailingMockGraphStorage: GraphStorage {
    var shouldFailSave = false
    var shouldFailLoad = false
    var shouldFailDelete = false
    var shouldFailList = false
    
    private var graphs: [String: GraphState] = [:]
    private var viewStates: [String: ViewState] = [:]
    
    func clear() async throws {
        graphs.removeAll()
        viewStates.removeAll()
    }
    
    func listGraphNames() async throws -> [String] {
        if shouldFailList {
            throw GraphStorageError.loadingFailed(NSError(domain: "test", code: 1))
        }
        return Array(graphs.keys).sorted()
    }
    
    func createNewGraph(name: String) async throws {
        if graphs[name] != nil {
            throw GraphStorageError.graphExists(name)
        }
        graphs[name] = GraphState(nodes: [], edges: [], hierarchyEdgeColor: CodableColor(.blue), associationEdgeColor: CodableColor(.white), isSimulating: false, nextNodeLabel: 1)
    }
    
    func deleteGraph(name: String) async throws {
        if shouldFailDelete {
            throw GraphStorageError.decodingFailed(NSError(domain: "test", code: 2))
        }
        guard graphs.removeValue(forKey: name) != nil else {
            throw GraphStorageError.graphNotFound(name)
        }
        viewStates.removeValue(forKey: name)
    }
    
    func saveViewState(_ viewState: ViewState, for name: String) throws {
        viewStates[name] = viewState
    }
    
    func loadViewState(for name: String) throws -> ViewState? {
        return viewStates[name]
    }
    
    func saveGraphState(_ graphState: GraphState, for name: String) async throws {
        if shouldFailSave {
            throw GraphStorageError.writingFailed(NSError(domain: "test", code: 3))
        }
        graphs[name] = graphState
    }
    
    func loadGraphState(for name: String) async throws -> GraphState {
        if shouldFailLoad {
            throw GraphStorageError.loadingFailed(NSError(domain: "test", code: 4))
        }
        guard let state = graphs[name] else {
            throw GraphStorageError.graphNotFound(name)
        }
        return state
    }
}

struct PersistenceErrorTests {
    
    // MARK: - Save Failures
    
    @MainActor @Test("Handle save failure gracefully")
    func testSaveFailureHandling() async {
        let storage = FailingMockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        
        _ = await model.addNode(at: .zero)
        
        storage.shouldFailSave = true
        
        do {
            try await model.saveGraph()
            Issue.record("Save should have thrown an error")
        } catch let error as GraphError {
            // Expected error
            switch error {
            case .storageFailure:
                break  // Expected
            default:
                Issue.record("Wrong error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
        
        // Model state should still be intact
        #expect(model.nodes.count == 1, "Node should still exist in model despite save failure")
    }
    
    // MARK: - Load Failures
    
    @MainActor @Test("Handle load failure with graph not found")
    func testLoadNonexistentGraph() async throws {
        let storage = FailingMockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        
        do {
            try await model.loadGraph()
            // Should either succeed with empty state or throw
        } catch let error as GraphError {
            switch error {
            case .storageFailure, .graphNotFound:
                break  // Expected for missing graph
            default:
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }
    
    @MainActor @Test("Handle corrupted data during load")
    func testLoadWithCorruptedData() async {
        let storage = FailingMockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        
        storage.shouldFailLoad = true
        
        do {
            try await model.loadGraph()
            Issue.record("Load should have thrown an error")
        } catch let error as GraphError {
            switch error {
            case .storageFailure:
                break  // Expected
            default:
                Issue.record("Wrong error type: \(error)")
            }
        } catch {
            // Also acceptable - storage error
        }
    }
    
    // MARK: - Delete Failures
    
    @MainActor @Test("Handle delete non-existent graph")
    func testDeleteNonexistentGraph() async {
        let storage = FailingMockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        
        do {
            try await model.deleteGraph(named: "nonexistent")
            Issue.record("Delete should have thrown an error")
        } catch let error as GraphError {
            switch error {
            case .storageFailure:
                break  // Expected
            default:
                Issue.record("Wrong error type: \(error)")
            }
        } catch {
            // Also acceptable - storage error
        }
    }
    
    @MainActor @Test("Handle delete failure")
    func testDeleteFailure() async throws {
        let storage = FailingMockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        
        // Create a graph first
        try await storage.createNewGraph(name: "testGraph")
        
        storage.shouldFailDelete = true
        
        do {
            try await model.deleteGraph(named: "testGraph")
            Issue.record("Delete should have thrown an error")
        } catch let error as GraphError {
            switch error {
            case .storageFailure:
                break  // Expected
            default:
                Issue.record("Wrong error type: \(error)")
            }
        } catch {
            // Also acceptable - storage error
        }
    }
    
    // MARK: - Create Graph Failures
    
    @MainActor @Test("Handle creating duplicate graph")
    func testCreateDuplicateGraph() async throws {
        let storage = FailingMockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        
        // Create first graph
        try await model.createNewGraph(name: "duplicate")
        
        // Try to create again
        do {
            try await model.createNewGraph(name: "duplicate")
            Issue.record("Should not allow duplicate graph names")
        } catch let error as GraphStorageError {
            switch error {
            case .graphExists:
                break  // Expected
            default:
                Issue.record("Wrong error type: \(error)")
            }
        } catch {
            // Check if it's wrapped in GraphError
            if let graphError = error as? GraphError {
                switch graphError {
                case .storageFailure, .invalidState:
                    break  // Also acceptable
                default:
                    Issue.record("Unexpected error: \(error)")
                }
            }
        }
    }
    
    @MainActor @Test("Handle creating graph with empty name")
    func testCreateGraphWithEmptyName() async {
        let storage = FailingMockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        
        do {
            try await model.createNewGraph(name: "")
            Issue.record("Should not allow empty graph name")
        } catch let error as GraphError {
            switch error {
            case .invalidState:
                break  // Expected
            default:
                Issue.record("Wrong error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @MainActor @Test("Handle creating graph with whitespace-only name")
    func testCreateGraphWithWhitespaceOnlyName() async {
        let storage = FailingMockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        
        do {
            try await model.createNewGraph(name: "   ")
            Issue.record("Should not allow whitespace-only graph name")
        } catch let error as GraphError {
            switch error {
            case .invalidState:
                break  // Expected
            default:
                Issue.record("Wrong error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - List Failures
    
    @MainActor @Test("Handle list graphs failure")
    func testListGraphsFailure() async {
        let storage = FailingMockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        
        storage.shouldFailList = true
        
        do {
            _ = try await model.listGraphNames()
            Issue.record("List should have thrown an error")
        } catch let error as GraphError {
            switch error {
            case .storageFailure:
                break  // Expected
            default:
                Issue.record("Wrong error type: \(error)")
            }
        } catch {
            // Also acceptable - storage error
        }
    }
}
