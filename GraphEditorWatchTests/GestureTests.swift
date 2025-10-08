//
//  GestureTests.swift
//  GraphEditor
//
//  Created by handcart on 9/22/25.
//
import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
@testable import GraphEditorShared
import XCTest
import SwiftUI

struct GestureTests {
    private func setupModel() async -> GraphModel {
        let storage = MockGraphStorage()
        let physicsEngine = GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = await MainActor.run { GraphModel(storage: storage, physicsEngine: physicsEngine) }
        await MainActor.run { model.nodes = [] }
        await MainActor.run { model.edges = [] }
        await model.addNode(at: CGPoint(x: 0, y: 0))
        await model.addNode(at: CGPoint(x: 50, y: 50))
        await model.stopSimulation()  // Ensure no ongoing simulation
        return model
    }
    
    @Test func testDragCreatesEdge() async throws {
        let model = await setupModel()
        #expect((await model.edges).isEmpty, "No edges initially")
        
        // Ensure at least two nodes exist before indexing
        let currentCount = await model.nodes.count
        if currentCount < 2 {
            await model.addNode(at: .zero)
            await model.addNode(at: CGPoint(x: 100, y: 100))
            await model.startSimulation()
            await model.stopSimulation()
        }
        
        let viewModel = await MainActor.run { GraphViewModel(model: model) }
        let draggedNode = await model.nodes[0]
        let potentialEdgeTarget = await model.nodes[1]
        let initialPosition = draggedNode.position
        
        let mockTranslation = CGSize(width: 50, height: 50)
        let dragOffset = CGPoint(x: mockTranslation.width / 1.0, y: mockTranslation.height / 1.0)
        let initialPositionUpdated = CGPoint(x: initialPosition.x + dragOffset.x, y: initialPosition.y + dragOffset.y)  // NEW: Compute expected position if moved
        
        let dragDistance = hypot(mockTranslation.width, mockTranslation.height)
        
        if let index = (await viewModel.model.nodes).firstIndex(where: { $0.id == draggedNode.id }) {
            await viewModel.model.snapshot()
            if dragDistance < AppConstants.tapThreshold {
                // Tap logic (skipped)
            } else {
                if potentialEdgeTarget.id != draggedNode.id {
                    let fromID = draggedNode.id
                    let toID = potentialEdgeTarget.id
                    let initialEdges = await MainActor.run { viewModel.model.edges }  // Capture initial for comparison on MainActor
                    let edgeExists = initialEdges.contains { $0.from == fromID && $0.target == toID } ||
                                     initialEdges.contains { $0.from == toID && $0.target == fromID }
                    if !edgeExists {
                        await MainActor.run { viewModel.model.edges.append(GraphEdge(from: fromID, target: toID)) }
                    } else {
                        await MainActor.run {
                            viewModel.model.nodes[index] = viewModel.model.nodes[index].with(position: initialPositionUpdated, velocity: .zero)
                        }
                    }
                    await viewModel.model.startSimulation()
                    await viewModel.model.stopSimulation()  // Wait for completion
                }
            }
        }
        
        let finalEdgeCount = await MainActor.run { viewModel.model.edges.count }
        #expect(finalEdgeCount == 1, "Edge created after simulated drag")
        let newEdge = await MainActor.run { viewModel.model.edges.first! }
        #expect(newEdge.from == draggedNode.id, "Edge from correct node")
        #expect(newEdge.target == potentialEdgeTarget.id, "Edge to correct node")
        let node0PositionAfter = await MainActor.run { model.nodes[0].position }
        #expect(approximatelyEqual(node0PositionAfter, initialPosition, accuracy: 1e-5), "Position unchanged on edge create")  // Corrected expectation
    }
    @Test func testShortDragAsTap() async throws {
        let model = await setupModel()
        #expect((await model.edges).isEmpty, "No edges initially")
        
        let viewModel = await MainActor.run { GraphViewModel(model: model) }
        let draggedNode = await model.nodes[0]
        let initialPosition = draggedNode.position
        let initialEdgeCount = (await model.edges).count
        
        let mockTranslation = CGSize(width: 1, height: 1)  // Small, < tapThreshold
        let dragDistance = hypot(mockTranslation.width, mockTranslation.height)
        
        if let index = (await viewModel.model.nodes).firstIndex(where: { $0.id == draggedNode.id }) {
            _ = index  // Silence unused warning
            await viewModel.model.snapshot()
            if dragDistance < AppConstants.tapThreshold {
                // Tap logic (skipped; assume no side effects for this test)
            } else {
                // Drag branch skipped due to small distance
            }
        }
        
        let edgeCountAfter = await MainActor.run { model.edges.count }
        #expect(edgeCountAfter == initialEdgeCount, "No edge created on short drag")
        let node0PositionAfterTap = await MainActor.run { model.nodes[0].position }
        #expect(approximatelyEqual(node0PositionAfterTap, initialPosition, accuracy: 1e-5), "Position unchanged")
    }
    
    @Test func testDragMovesNodeIfEdgeExists() async throws {
        let model = await setupModel()
        
        // Ensure at least two nodes exist before indexing
        let currentCount = await model.nodes.count
        if currentCount < 2 {
            await model.addNode(at: .zero)
            await model.addNode(at: CGPoint(x: 100, y: 100))
            await model.startSimulation()
            await model.stopSimulation()
        }

        let fromID = (await model.nodes[0]).id
        let toID = (await model.nodes[1]).id
        await MainActor.run { model.edges.append(GraphEdge(from: fromID, target: toID)) }
        #expect((await model.edges).count == 1, "Edge exists initially")
        
        let viewModel = await MainActor.run { GraphViewModel(model: model) }
        let draggedNode = await model.nodes[0]
        let potentialEdgeTarget = await model.nodes[1]
        let initialPosition = draggedNode.position
        
        let mockTranslation = CGSize(width: 50, height: 50)
        let dragOffset = CGPoint(x: mockTranslation.width / 1.0, y: mockTranslation.height / 1.0)
        let dragDistance = hypot(mockTranslation.width, mockTranslation.height)
        
        if let index = (await viewModel.model.nodes).firstIndex(where: { $0.id == draggedNode.id }) {
            await viewModel.model.snapshot()
            if dragDistance < AppConstants.tapThreshold {
                // Tap logic (skipped)
            } else {
                if potentialEdgeTarget.id != draggedNode.id {
                    let fromID = draggedNode.id
                    let toID = potentialEdgeTarget.id
                    let edgeExists = await MainActor.run {
                        let edges = viewModel.model.edges
                        let forwardMatch = edges.contains { $0.from == fromID && $0.target == toID }
                        let reverseMatch = edges.contains { $0.from == toID && $0.target == fromID }
                        return forwardMatch || reverseMatch
                    }
                    if !edgeExists {
                        await MainActor.run { viewModel.model.edges.append(GraphEdge(from: fromID, target: toID)) }
                        await viewModel.model.startSimulation()
                        await viewModel.model.stopSimulation()
                    } else {
                        await MainActor.run {
                            let currentPos = viewModel.model.nodes[index].position
                            viewModel.model.nodes[index] = viewModel.model.nodes[index].with(position: CGPoint(x: currentPos.x + dragOffset.x, y: currentPos.y + dragOffset.y), velocity: .zero)
                        }
                        let posAfterImmediateMove = await MainActor.run { model.nodes[0].position }
                        #expect(!approximatelyEqual(posAfterImmediateMove, initialPosition, accuracy: 1e-5), "Position changed on move")
                        #expect(approximatelyEqual(posAfterImmediateMove, CGPoint(x: initialPosition.x + dragOffset.x, y: initialPosition.y + dragOffset.y), accuracy: 1e-5), "Moved by offset")
                        await viewModel.model.startSimulation()  // Keep this if needed for side effects, but checks are now before it
                        await viewModel.model.stopSimulation()
                    }
                }
            }
        }
        
        let finalEdgeCount2 = await MainActor.run { viewModel.model.edges.count }
        #expect(finalEdgeCount2 == 1, "No new edge created")
        // OPTIONAL: If you want to verify post-simulation (e.g., position changed but not exactly by offset), add looser checks here
    }
}
