//
//  AccessibilityTests.swift
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

struct AccessibilityTests {
    private func mockPhysicsEngine() -> GraphEditorShared.PhysicsEngine {
        GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
    }
    
    @Test func testGraphDescription() async throws {
        let storage = MockGraphStorage()
        storage.nodes = [Node(label: 0, position: .zero)]
        let model = await GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        await MainActor.run { model.nextNodeLabel = 1 }
        await model.addNode(at: .zero)
        await model.addNode(at: CGPoint(x: 10, y: 10))
        
        await MainActor.run { model.edges.append(GraphEdge(from: model.nodes[0].id, target: model.nodes[1].id)) }
        
        let descNoSelect = await MainActor.run { model.graphDescription(selectedID: nil, selectedEdgeID: nil) }
        #expect(descNoSelect == "Graph with 2 nodes and 1 directed edge. No node or edge selected.", "Correct desc without selection")
        
        let descWithSelect = await MainActor.run { model.graphDescription(selectedID: model.nodes[0].id, selectedEdgeID: nil) }
        #expect(descWithSelect == "Graph with 2 nodes and 1 directed edge. Node 1 selected, outgoing to: 2; incoming from: none.", "Correct desc with selection")
    }
}
