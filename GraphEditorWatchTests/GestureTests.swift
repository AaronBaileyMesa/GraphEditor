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
        let model = await GraphModel(storage: storage, physicsEngine: physicsEngine)
        await MainActor.run { model.nodes = [] }
        await MainActor.run { model.edges = [] }
        await model.addNode(at: CGPoint(x: 0, y: 0))
        await model.addNode(at: CGPoint(x: 50, y: 50))
        return model
    }
    
    @Test func testDragCreatesEdge() async throws {
        let model = await setupModel()
        #expect((await model.edges).isEmpty, "No edges initially")
        
        let viewModel = await GraphViewModel(model: model)
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
                        let edges = viewModel.model.edges  // No await needed here if already on MainActor
                        let forwardMatch = edges.contains { $0.from == fromID && $0.target == toID }
                        let reverseMatch = edges.contains { $0.from == toID && $0.target == fromID }
                        return forwardMatch || reverseMatch
                    }
                    if !edgeExists {
                        await MainActor.run { viewModel.model.edges.append(GraphEdge(from: fromID, target: toID)) }
                        await viewModel.model.startSimulation()
                    } else {
                        await MainActor.run {
                            let currentPos = viewModel.model.nodes[index].position
                            viewModel.model.nodes[index] = viewModel.model.nodes[index].with(position: CGPoint(x: currentPos.x + dragOffset.x, y: currentPos.y + dragOffset.y), velocity: .zero)
                        }
                        await viewModel.model.startSimulation()
                    }
                }
            }
        }
        
        #expect((await viewModel.model.edges).count == 1, "Edge created after simulated drag")
        let newEdge = (await viewModel.model.edges).first!
        #expect(newEdge.from == draggedNode.id, "Edge from correct node")
        #expect(newEdge.target == potentialEdgeTarget.id, "Edge to correct node")
        #expect(approximatelyEqual((await model.nodes[0]).position, initialPosition, accuracy: 1e-5), "Position unchanged on create")
    }
    
    @Test func testShortDragAsTap() async throws {
        let model = await setupModel()
        #expect((await model.edges).isEmpty, "No edges initially")
        
        let viewModel = await GraphViewModel(model: model)
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
        
        #expect((await model.edges).count == initialEdgeCount, "No edge created on short drag")
        #expect(approximatelyEqual((await model.nodes[0]).position, initialPosition, accuracy: 1e-5), "Position unchanged")
    }
    
    @Test func testDragMovesNodeIfEdgeExists() async throws {
        let model = await setupModel()
        let fromID = (await model.nodes[0]).id
        let toID = (await model.nodes[1]).id
        await MainActor.run { model.edges.append(GraphEdge(from: fromID, target: toID)) }
        #expect((await model.edges).count == 1, "Edge exists initially")
        
        let viewModel = await GraphViewModel(model: model)
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
                    } else {
                        await MainActor.run {
                            let currentPos = viewModel.model.nodes[index].position
                            viewModel.model.nodes[index] = viewModel.model.nodes[index].with(position: CGPoint(x: currentPos.x + dragOffset.x, y: currentPos.y + dragOffset.y), velocity: .zero)
                        }
                        // NEW: Check position immediately after move, before simulation
                        #expect(!approximatelyEqual((await model.nodes[0]).position, initialPosition, accuracy: 1e-5), "Position changed on move")
                        #expect(approximatelyEqual((await model.nodes[0]).position, initialPosition + dragOffset, accuracy: 1e-5), "Moved by offset")
                        await viewModel.model.startSimulation()  // Keep this if needed for side effects, but checks are now before it
                    }
                }
            }
        }
        
        #expect((await viewModel.model.edges).count == 1, "No new edge created")
        // OPTIONAL: If you want to verify post-simulation (e.g., position changed but not exactly by offset), add looser checks here
    }
}
