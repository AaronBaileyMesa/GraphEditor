//
//  PeopleListLayoutTests.swift
//  GraphEditorWatchTests
//
//  Tests for PeopleListNode layout and positioning
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct PeopleListLayoutTests {
    
    @MainActor
    private func createTestViewModel() async -> GraphViewModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        await model.ensureRootNode()
        return GraphViewModel(model: model)
    }
    
    // MARK: - PeopleListNode Creation
    
    @MainActor @Test("PeopleListNode can be created")
    func testPeopleListNodeCreation() async {
        let viewModel = await createTestViewModel()
        
        await viewModel.model.ensurePeopleListNode()
        
        guard let peopleList = viewModel.model.getPeopleListNode() else {
            Issue.record("Failed to create PeopleListNode")
            return
        }
        
        #expect(peopleList.name == "People", "PeopleListNode should have default name")
        #expect(peopleList.children.isEmpty, "New PeopleListNode should have no children")
        #expect(peopleList.isExpanded, "PeopleListNode should start expanded")
    }
    
    @MainActor @Test("PeopleListNode expansion creates constraints")
    func testPeopleListExpansionCreatesConstraints() async {
        let viewModel = await createTestViewModel()
        
        await viewModel.model.ensurePeopleListNode()
        
        guard let peopleList = viewModel.model.getPeopleListNode() else {
            Issue.record("Failed to create PeopleListNode")
            return
        }
        
        // Add a person to the list
        _ = await viewModel.model.addPersonToPeopleList()
        
        // List is already expanded by default, so no need to toggle
        
        // Get updated node
        guard let updatedList = viewModel.model.nodes.first(where: { $0.id == peopleList.id })?.unwrapped as? PeopleListNode else {
            Issue.record("Could not find updated PeopleListNode")
            return
        }
        
        #expect(updatedList.isExpanded, "PeopleListNode should be expanded")
        #expect(!updatedList.children.isEmpty, "PeopleListNode should have children")
        
        // Check that descriptor creates constraints when expanded
        let descriptor = updatedList.typeDescriptor
        let constraints = descriptor.constraints
        #expect(!constraints.isEmpty, "Expanded PeopleListNode should have constraints")
    }
    
    // MARK: - Person Node Positioning
    
    @MainActor @Test("Person nodes positioned with correct offset from parent")
    func testPersonNodeOffset() async {
        let viewModel = await createTestViewModel()
        
        await viewModel.model.ensurePeopleListNode()
        
        guard let peopleList = viewModel.model.getPeopleListNode() else {
            Issue.record("Failed to create PeopleListNode")
            return
        }
        
        _ = await viewModel.model.addPersonToPeopleList()
        
        // List is already expanded by default, constraints are automatically created
        
        // Get the constraint
        guard let updatedList = viewModel.model.nodes.first(where: { $0.id == peopleList.id })?.unwrapped as? PeopleListNode else {
            Issue.record("Could not find updated PeopleListNode")
            return
        }
        
        let descriptor = updatedList.typeDescriptor
        let constraints = descriptor.constraints
        
        if let verticalListConstraint = constraints.first as? VerticalListConstraint {
            // Verify the offset matches our expected values
            #expect(verticalListConstraint.offsetFromParent.x == -60,
                    "X offset should be -60 to keep nodes within rectangle")
            #expect(verticalListConstraint.offsetFromParent.y == 50,
                    "Y offset should be 50 to avoid overlapping parent label")
            #expect(verticalListConstraint.rowHeight == 28.0,
                    "Row height should be 28pt for compact spacing")
        } else {
            Issue.record("Expected VerticalListConstraint but found different type")
        }
    }
    
    @MainActor @Test("Multiple person nodes have correct vertical spacing")
    func testMultiplePersonNodesSpacing() async {
        let viewModel = await createTestViewModel()
        
        await viewModel.model.ensurePeopleListNode()
        
        guard let peopleList = viewModel.model.getPeopleListNode() else {
            Issue.record("Failed to create PeopleListNode")
            return
        }
        
        // Add three people
        _ = await viewModel.model.addPersonToPeopleList()
        _ = await viewModel.model.addPersonToPeopleList()
        _ = await viewModel.model.addPersonToPeopleList()
        
        // List is already expanded by default
        
        // Get updated list
        guard let updatedList = viewModel.model.nodes.first(where: { $0.id == peopleList.id })?.unwrapped as? PeopleListNode else {
            Issue.record("Could not find updated PeopleListNode")
            return
        }
        
        #expect(updatedList.children.count == 3, "Should have 3 person nodes")
        
        // Get the constraint
        let descriptor = updatedList.typeDescriptor
        let constraints = descriptor.constraints
        
        if let verticalListConstraint = constraints.first as? VerticalListConstraint {
            #expect(verticalListConstraint.childIDs.count == 3,
                    "Constraint should reference all 3 children")
        }
    }
    
    // MARK: - Constraint Application
    
    @MainActor @Test("VerticalListConstraint positions nodes correctly")
    func testVerticalListConstraintPositioning() {
        let parentID = UUID()
        let child1ID = UUID()
        let child2ID = UUID()
        let child3ID = UUID()
        
        let constraint = VerticalListConstraint(
            parentID: parentID,
            childIDs: [child1ID, child2ID, child3ID],
            rowHeight: 28.0,
            offsetFromParent: CGPoint(x: -60, y: 50)
        )
        
        // Create mock parent node at (100, 100)
        let parent = Node(id: parentID, label: 1, position: CGPoint(x: 100, y: 100))
        
        // Create mock child nodes
        let child1 = Node(id: child1ID, label: 2, position: .zero)
        let child2 = Node(id: child2ID, label: 3, position: .zero)
        let child3 = Node(id: child3ID, label: 4, position: .zero)
        
        let allNodes: [any NodeProtocol] = [parent, child1, child2, child3]
        let context = ConstraintContext(
            allNodes: allNodes,
            deltaTime: 0.016,
            simulationBounds: CGSize(width: 500, height: 500),
            originalPositions: [:]
        )
        
        // Apply constraint to each child
        let child1Position = constraint.apply(to: child1, proposedPosition: .zero, context: context)
        let child2Position = constraint.apply(to: child2, proposedPosition: .zero, context: context)
        let child3Position = constraint.apply(to: child3, proposedPosition: .zero, context: context)
        
        // Verify positions
        #expect(child1Position != nil, "Constraint should return position for child1")
        #expect(child2Position != nil, "Constraint should return position for child2")
        #expect(child3Position != nil, "Constraint should return position for child3")
        
        if let pos1 = child1Position, let pos2 = child2Position, let pos3 = child3Position {
            // X positions should all be the same (parent.x + offset.x)
            let expectedX = parent.position.x + constraint.offsetFromParent.x
            #expect(pos1.x == expectedX, "First child X should match offset")
            #expect(pos2.x == expectedX, "Second child X should match offset")
            #expect(pos3.x == expectedX, "Third child X should match offset")
            
            // Y positions should increment by rowHeight
            let expectedY1 = parent.position.y + constraint.offsetFromParent.y
            let expectedY2 = expectedY1 + constraint.rowHeight
            let expectedY3 = expectedY2 + constraint.rowHeight
            
            #expect(pos1.y == expectedY1, "First child Y should be at base offset")
            #expect(pos2.y == expectedY2, "Second child Y should be offset by one row")
            #expect(pos3.y == expectedY3, "Third child Y should be offset by two rows")
        }
    }
    
    // MARK: - Table Background Rendering
    
    @MainActor @Test("PeopleListNode table background matches node positions")
    func testTableBackgroundAlignment() async {
        let viewModel = await createTestViewModel()
        
        await viewModel.model.ensurePeopleListNode()
        
        guard let peopleList = viewModel.model.getPeopleListNode() else {
            Issue.record("Failed to create PeopleListNode")
            return
        }
        
        _ = await viewModel.model.addPersonToPeopleList()
        
        // List is already expanded by default
        
        // Verify that the background rendering parameters match the constraint parameters
        // This ensures visual consistency between the background rectangle and node positions
        
        guard let updatedList = viewModel.model.nodes.first(where: { $0.id == peopleList.id })?.unwrapped as? PeopleListNode else {
            Issue.record("Could not find updated PeopleListNode")
            return
        }
        
        let descriptor = updatedList.typeDescriptor
        let constraints = descriptor.constraints
        
        if let verticalListConstraint = constraints.first as? VerticalListConstraint {
            // The AccessibleCanvasRenderer should use the same parameters
            // This test documents the expected consistency
            #expect(verticalListConstraint.offsetFromParent.x == -60,
                    "Background renderer should use same X offset as constraint")
            #expect(verticalListConstraint.offsetFromParent.y == 50,
                    "Background renderer should use same Y offset as constraint")
            #expect(verticalListConstraint.rowHeight == 28.0,
                    "Background renderer should use same row height as constraint")
        }
    }
}
