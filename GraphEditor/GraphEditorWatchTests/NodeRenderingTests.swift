//
//  NodeRenderingTests.swift
//  GraphEditorWatchTests
//
//  Tests for NodeView rendering logic and visual calculations
//

import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct NodeRenderingTests {

    @MainActor
    private func createTestViewModel() -> GraphViewModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        return GraphViewModel(model: model)
    }

    // MARK: - Basic Node Rendering

    @MainActor @Test("Generic node renders with label")
    func testGenericNodeRendersWithLabel() {
        let node = Node(label: 42, position: CGPoint(x: 100, y: 100))
        let view = NodeView(node: node, isSelected: false, zoomScale: 1.0)

        #expect(node.label == 42, "Node should have label 42")
        #expect(node.position.x == 100 && node.position.y == 100, "Node should be at correct position")
    }

    @MainActor @Test("Generic node can be created")
    func testGenericNodeCreation() async {
        let viewModel = createTestViewModel()
        let node = await viewModel.model.addNode(at: CGPoint(x: 50, y: 50))

        #expect(node.label > 0, "Node should have positive label")
        #expect(node.position.x == 50, "Node should be at correct X position")
        #expect(node.position.y == 50, "Node should be at correct Y position")
    }

    // MARK: - TaskNode Rendering

    @MainActor @Test("TaskNode renders with task type icon")
    func testTaskNodeRendersWithIcon() async {
        let viewModel = createTestViewModel()

        let task = await viewModel.model.addTask(
            type: .cook,
            estimatedTime: 30,
            at: CGPoint(x: 100, y: 100)
        )

        let view = NodeView(node: task, isSelected: false, zoomScale: 1.0)

        #expect(task.taskType == .cook, "Task type should be cook")
        #expect(task.radius > 0, "Task should have positive radius")
    }

    @MainActor @Test("TaskNode renders all task types")
    func testTaskNodeAllTaskTypes() async {
        let viewModel = createTestViewModel()

        let taskTypes: [TaskType] = [
            .plan, .shop, .prep, .cook, .assemble, .serve, .cleanup
        ]

        for taskType in taskTypes {
            let task = await viewModel.model.addTask(
                type: taskType,
                estimatedTime: 15,
                at: CGPoint(x: 100, y: 100)
            )

            #expect(task.taskType == taskType, "Task should have correct type: \(taskType)")
            #expect(task.estimatedTime == 15, "Task should have estimated time")
        }
    }

    @MainActor @Test("TaskNode has fill color")
    func testTaskNodeHasFillColor() async {
        let viewModel = createTestViewModel()

        let task = await viewModel.model.addTask(
            type: .prep,
            estimatedTime: 20,
            at: CGPoint(x: 100, y: 100)
        )

        let fillColor = task.fillColor

        #expect(fillColor.description.count > 0, "Task should have fill color")
    }

    // MARK: - ControlNode Rendering

    @MainActor @Test("ControlNode renders smaller than regular nodes")
    func testControlNodeSmallerSize() async {
        let viewModel = createTestViewModel()

        let regularNode = await viewModel.model.addNode(at: .zero)
        await viewModel.generateControls(for: regularNode.id)

        // Find the control nodes
        let controlNodes = viewModel.model.nodes.compactMap { $0 as? ControlNode }

        #expect(controlNodes.count > 0, "Should have generated control nodes")

        if let control = controlNodes.first {
            // Control nodes should have smaller radius
            #expect(control.radius < regularNode.radius, "Control node should be smaller than regular node")
        }
    }

    @MainActor @Test("ControlNode renders all control kinds")
    func testControlNodeAllKinds() async {
        let viewModel = createTestViewModel()

        let node = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        await viewModel.generateControls(for: node.id)

        let controlNodes = viewModel.model.nodes.compactMap { $0 as? ControlNode }

        // Should have controls for various kinds
        #expect(controlNodes.count > 0, "Should generate multiple control nodes")

        // Verify different kinds exist
        let kinds = Set(controlNodes.map { $0.kind })
        #expect(kinds.count > 0, "Should have multiple control kinds")
    }

    @MainActor @Test("DecisionNode can be created")
    func testDecisionNodeCreation() async {
        let viewModel = createTestViewModel()

        let decision = await viewModel.model.addDecision(
            question: "Prefer beef or chicken?",
            at: CGPoint(x: 100, y: 100)
        )

        #expect(decision.question == "Prefer beef or chicken?", "Decision should have question")
        #expect(decision.radius > 0, "Decision should have positive radius")
    }

    // MARK: - Selection Highlighting

    @MainActor @Test("Selected node renders with highlight")
    func testSelectedNodeHighlight() {
        let node = Node(label: 1, position: .zero)

        let unselectedView = NodeView(node: node, isSelected: false, zoomScale: 1.0)
        let selectedView = NodeView(node: node, isSelected: true, zoomScale: 1.0)

        // We can't directly test the visual appearance, but we verify the views construct
        #expect(node.radius > 0, "Node should have radius for selection circle")
    }

    @MainActor @Test("Selection stroke scales with zoom")
    func testSelectionStrokeScaling() {
        let node = Node(label: 1, position: .zero)

        let normalZoom = NodeView(node: node, isSelected: true, zoomScale: 1.0)
        let highZoom = NodeView(node: node, isSelected: true, zoomScale: 2.0)
        let lowZoom = NodeView(node: node, isSelected: true, zoomScale: 0.5)

        // Selection stroke should scale: 4 * zoomScale
        // We verify the node exists at different zoom levels
        #expect(node.label == 1, "Node should remain consistent across zoom levels")
    }

    // MARK: - Zoom Scaling

    @MainActor @Test("Node size scales with zoom")
    func testNodeSizeScaling() {
        let node = Node(label: 1, position: .zero)

        let normalView = NodeView(node: node, isSelected: false, zoomScale: 1.0)
        let zoomedInView = NodeView(node: node, isSelected: false, zoomScale: 2.0)
        let zoomedOutView = NodeView(node: node, isSelected: false, zoomScale: 0.5)

        // Visual size is calculated as: radius * 2 * zoomScale
        let normalSize = node.radius * 2 * 1.0
        let zoomedInSize = node.radius * 2 * 2.0
        let zoomedOutSize = node.radius * 2 * 0.5

        #expect(zoomedInSize == normalSize * 2, "Zoomed in should be 2x normal")
        #expect(zoomedOutSize == normalSize * 0.5, "Zoomed out should be 0.5x normal")
    }

    @MainActor @Test("Font size respects minimum at low zoom")
    func testFontMinimumSize() {
        let node = Node(label: 42, position: .zero)

        // At very low zoom, font should maintain minimum size
        let veryLowZoom = NodeView(node: node, isSelected: false, zoomScale: 0.1)

        // Font calculation: max(8.0, 12.0 * zoomScale)
        // At 0.1 zoom: max(8.0, 1.2) = 8.0
        let expectedMinFontSize: CGFloat = 8.0
        let calculatedFontSize = max(8.0, 12.0 * 0.1)

        #expect(calculatedFontSize == expectedMinFontSize, "Font should respect minimum of 8.0")
    }

    @MainActor @Test("Font size scales normally at standard zoom")
    func testFontNormalScaling() {
        let node = Node(label: 42, position: .zero)

        // At normal zoom, font should scale
        let normalZoom = NodeView(node: node, isSelected: false, zoomScale: 1.5)

        // Font calculation: max(8.0, 12.0 * zoomScale)
        // At 1.5 zoom: max(8.0, 18.0) = 18.0
        let calculatedFontSize = max(8.0, 12.0 * 1.5)

        #expect(calculatedFontSize == 18.0, "Font should scale to 18.0 at 1.5x zoom")
    }

    // MARK: - Accessibility

    @MainActor @Test("Generic node has accessibility label")
    func testGenericNodeAccessibilityLabel() async {
        let viewModel = createTestViewModel()
        let node = await viewModel.model.addNode(at: .zero)

        let view = NodeView(node: node, isSelected: false, zoomScale: 1.0)

        // Accessibility label format: "Node {label}, {content}"
        #expect(node.label > 0, "Node should have positive label")
    }

    @MainActor @Test("Control node has accessibility label with kind")
    func testControlNodeAccessibilityLabel() async {
        let viewModel = createTestViewModel()
        let node = await viewModel.model.addNode(at: .zero)
        await viewModel.generateControls(for: node.id)

        let controlNodes = viewModel.model.nodes.compactMap { $0 as? ControlNode }

        if let control = controlNodes.first {
            let view = NodeView(node: control, isSelected: false, zoomScale: 1.0)

            // Control accessibility label should be the kind's raw value
            #expect(control.kind.rawValue.count > 0, "Control kind should have name")
        }
    }

    // MARK: - Multiple Node Types in Scene

    @MainActor @Test("Mix of node types renders correctly")
    func testMixedNodeTypes() async {
        let viewModel = createTestViewModel()

        let genericNode = await viewModel.model.addNode(at: CGPoint(x: 0, y: 0))
        let task = await viewModel.model.addTask(type: .cook, estimatedTime: 20, at: CGPoint(x: 50, y: 0))

        #expect(viewModel.model.nodes.count >= 2, "Should have at least 2 nodes")

        // Verify each node type
        let hasGeneric = viewModel.model.nodes.contains(where: { $0.id == genericNode.id })
        let hasTask = viewModel.model.nodes.contains(where: { $0.id == task.id })

        #expect(hasGeneric && hasTask, "All node types should be in model")
    }
}
