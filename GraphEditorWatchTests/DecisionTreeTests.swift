//
//  DecisionTreeTests.swift
//  GraphEditorWatchTests
//
//  Tests for decision tree creation and layout
//

import Testing
import Foundation
import CoreGraphics
import GraphEditorShared
@testable import GraphEditorWatch

@MainActor
struct DecisionTreeTests {
    
    private func createTestViewModel() -> GraphViewModel {
        let storage = MockGraphStorage()
        let screenBounds = CGSize(width: 205, height: 251)
        let simulationBounds = CGSize(width: screenBounds.width * 4, height: screenBounds.height * 4)
        let physicsEngine = PhysicsEngine(simulationBounds: simulationBounds, layoutMode: .hierarchy)
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        return GraphViewModel(model: model)
    }
    
    @Test("Decision tree nodes are created at correct initial positions")
    func testDecisionTreeInitialPositions() async {
        let viewModel = createTestViewModel()
        
        // Begin bulk operation to prevent simulation during and after build
        await viewModel.model.beginBulkOperation()
        
        // Build the decision tree at a specific starting position
        let startPosition = CGPoint(x: 50, y: 125)
        _ = await TacoTemplateBuilder.buildDecisionTree(
            in: viewModel.model,
            at: startPosition
        )
        
        // Check positions BEFORE ending bulk operation (before simulation can run)
        // Get all decision nodes
        let decisions = viewModel.model.nodes.compactMap { $0.unwrapped as? DecisionNode }
        
        // Debug: Print actual positions
        print("📍 Decision node positions:")
        for decision in decisions.sorted(by: { $0.position.x < $1.position.x }) {
            print("  Node \(decision.id.uuidString.prefix(8)): x=\(decision.position.x), y=\(decision.position.y)")
        }
        
        // Verify we have 4 decision nodes
        #expect(decisions.count == 4, "Should have created 4 decision nodes")
        
        // Verify initial positions
        // All decision nodes should start at y=125
        for decision in decisions {
            let yPosition = decision.position.y
            #expect(yPosition == 125.0, "Decision node \(decision.id.uuidString.prefix(8)) should be at y=125, but is at y=\(yPosition)")
        }
        
        // Verify horizontal spacing (50 points apart)
        let sortedByX = decisions.sorted { $0.position.x < $1.position.x }
        let expectedXPositions = [50.0, 100.0, 150.0, 200.0]
        
        for (index, decision) in sortedByX.enumerated() {
            let expectedX = expectedXPositions[index]
            let actualX = decision.position.x
            let tolerance: CGFloat = 0.001
            #expect(abs(actualX - expectedX) < tolerance, "Decision node at index \(index) should be at x=\(expectedX), but is at x=\(actualX)")
        }
        
        // Now end bulk operation
        await viewModel.model.endBulkOperation()
        
        print("✅ All decision nodes at correct initial positions")
    }
    
    @Test("Decision tree has segment config")
    func testDecisionTreeSegmentConfig() async {
        let viewModel = createTestViewModel()
        
        let startPosition = CGPoint(x: 50, y: 125)
        let rootDecision = await TacoTemplateBuilder.buildDecisionTree(
            in: viewModel.model,
            at: startPosition
        )
        
        // Verify segment config exists for root decision
        let segmentConfig = viewModel.model.segmentConfigs[rootDecision.id]
        #expect(segmentConfig != nil, "Should have segment config for root decision")
        #expect(segmentConfig?.direction == .horizontal, "Segment should be horizontal")
        #expect(segmentConfig?.nodeSpacing == 50.0, "Node spacing should be 50")
        
        print("✅ Segment config correctly set")
    }
    
    @Test("Decision tree nodes are connected with precedes edges")
    func testDecisionTreeEdges() async {
        let viewModel = createTestViewModel()
        
        let startPosition = CGPoint(x: 50, y: 125)
        _ = await TacoTemplateBuilder.buildDecisionTree(
            in: viewModel.model,
            at: startPosition
        )
        
        // Get all precedes edges
        let precedesEdges = viewModel.model.edges.filter { $0.type == .precedes }
        
        // Should have 3 precedes edges (4 decisions connected in sequence)
        #expect(precedesEdges.count == 3, "Should have 3 precedes edges, found \(precedesEdges.count)")
        
        print("✅ Decision tree has correct precedes edges")
    }
    
    @Test("Decision tree segment membership is calculated correctly")
    func testSegmentMembership() async {
        let viewModel = createTestViewModel()
        
        let startPosition = CGPoint(x: 50, y: 125)
        let rootDecision = await TacoTemplateBuilder.buildDecisionTree(
            in: viewModel.model,
            at: startPosition
        )
        
        // Build segment membership
        let membership = DirectionalLayoutCalculator.buildSegmentMembership(
            nodes: viewModel.model.nodes.map { $0.unwrapped },
            edges: viewModel.model.edges,
            segmentConfigs: viewModel.model.segmentConfigs
        )
        
        // All 4 decision nodes should be in the segment
        let decisions = viewModel.model.nodes.compactMap { $0.unwrapped as? DecisionNode }
        #expect(decisions.count == 4, "Should have 4 decisions")
        
        for decision in decisions {
            let rootID = membership[decision.id]
            #expect(rootID != nil, "Decision \(decision.id.uuidString.prefix(8)) should be in a segment")
            #expect(rootID == rootDecision.id, "Decision should belong to root segment")
        }
        
        print("✅ All decision nodes correctly identified as segment members")
    }
}
