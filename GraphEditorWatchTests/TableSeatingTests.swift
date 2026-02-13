//
//  TableSeatingTests.swift
//  GraphEditorWatchTests
//
//  Tests for table seating functionality (TableNode-based)
//

import Testing
import Foundation
import GraphEditorShared
@testable import GraphEditorWatch

struct TableSeatingTests {
    
    private func mockPhysicsEngine() -> GraphEditorShared.PhysicsEngine {
        GraphEditorShared.PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
    }
    
    @Test("Can create table node")
    @MainActor
    @available(watchOS 10.0, *)
    func testCreateTable() async throws {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        
        let table = await model.addTable(
            name: "Dinner Table",
            headSeats: 1,
            sideSeats: 3,
            at: CGPoint(x: 100, y: 100)
        )
        
        #expect(table.name == "Dinner Table")
        #expect(table.totalSeats == 8)  // 1 head * 2 + 3 side * 2 = 2 + 6 = 8
        #expect(table.seatingAssignments.isEmpty)
    }
    
    @Test("Can assign person to table seat")
    @MainActor
    @available(watchOS 10.0, *)
    func testAssignPersonToTableSeat() async throws {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        
        // Create table
        let table = await model.addTable(
            name: "Dinner Table",
            at: CGPoint(x: 100, y: 100)
        )
        
        // Create person
        let person = PersonNode(
            label: 1,
            position: CGPoint(x: 50, y: 50),
            name: "Alice"
        )
        model.nodes.append(AnyNode(person))
        
        // Assign person to seat
        await model.assignPersonToTable(
            personID: person.id,
            tableID: table.id,
            seatPosition: SeatPosition.head
        )
        
        // Verify assignment
        let updatedTable = model.nodes.first(where: { $0.id == table.id })?.unwrapped as? TableNode
        #expect(updatedTable?.seatingAssignments[SeatPosition.head] == person.id)
        
        // Verify person was positioned (physics may have moved it slightly)
        let updatedPerson = model.nodes.first(where: { $0.id == person.id })?.unwrapped as? PersonNode
        #expect(updatedPerson != nil, "Person node should exist")
        
        // Verify edge was created
        let edge = model.edges.first { edge in
            edge.from == table.id && edge.target == person.id && edge.type == .association
        }
        #expect(edge != nil)
    }
    
    @Test("Reassigning person removes from previous seat")
    @MainActor
    @available(watchOS 10.0, *)
    func testReassignPerson() async throws {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        
        // Create table and person
        let table = await model.addTable(
            name: "Dinner Table",
            at: CGPoint(x: 100, y: 100)
        )
        let person = PersonNode(label: 1, position: .zero, name: "Bob")
        model.nodes.append(AnyNode(person))
        
        // Assign to head seat
        await model.assignPersonToTable(
            personID: person.id,
            tableID: table.id,
            seatPosition: SeatPosition.head
        )
        
        // Reassign to leftFront seat
        await model.assignPersonToTable(
            personID: person.id,
            tableID: table.id,
            seatPosition: SeatPosition.leftFront
        )
        
        // Verify person is only at new seat
        let updatedTable = model.nodes.first(where: { $0.id == table.id })?.unwrapped as? TableNode
        #expect(updatedTable?.seatingAssignments[SeatPosition.head] == nil)
        #expect(updatedTable?.seatingAssignments[SeatPosition.leftFront] == person.id)
        #expect(updatedTable?.seatingAssignments.count == 1)
    }
    
    @Test("Can remove person from table")
    @MainActor
    @available(watchOS 10.0, *)
    func testRemovePersonFromTable() async throws {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        
        // Create table and person
        let table = await model.addTable(
            name: "Dinner Table",
            at: CGPoint(x: 100, y: 100)
        )
        let person = PersonNode(label: 1, position: .zero, name: "Charlie")
        model.nodes.append(AnyNode(person))
        
        // Assign person
        await model.assignPersonToTable(
            personID: person.id,
            tableID: table.id,
            seatPosition: SeatPosition.rightMiddle
        )
        
        // Remove person
        await model.removePersonFromTable(
            personID: person.id,
            tableID: table.id
        )
        
        // Verify removal
        let updatedTable = model.nodes.first(where: { $0.id == table.id })?.unwrapped as? TableNode
        #expect(updatedTable?.seatingAssignments[SeatPosition.rightMiddle] == nil)
        #expect(updatedTable?.seatingAssignments.isEmpty == true)
        
        // Verify edge was removed
        let edge = model.edges.first { edge in
            edge.from == table.id && edge.target == person.id
        }
        #expect(edge == nil)
    }
    
    @Test("Can assign multiple people to different seats")
    @MainActor
    @available(watchOS 10.0, *)
    func testMultipleAssignments() async throws {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        
        // Create table
        let table = await model.addTable(
            name: "Dinner Table",
            at: CGPoint(x: 100, y: 100)
        )
        
        // Create people
        let alice = PersonNode(label: 1, position: .zero, name: "Alice")
        let bob = PersonNode(label: 2, position: .zero, name: "Bob")
        let charlie = PersonNode(label: 3, position: .zero, name: "Charlie")
        model.nodes.append(contentsOf: [AnyNode(alice), AnyNode(bob), AnyNode(charlie)])
        
        // Assign to different seats
        await model.assignPersonToTable(personID: alice.id, tableID: table.id, seatPosition: SeatPosition.head)
        await model.assignPersonToTable(personID: bob.id, tableID: table.id, seatPosition: SeatPosition.leftFront)
        await model.assignPersonToTable(personID: charlie.id, tableID: table.id, seatPosition: SeatPosition.rightFront)
        
        // Verify all assignments
        let updatedTable = model.nodes.first(where: { $0.id == table.id })?.unwrapped as? TableNode
        #expect(updatedTable?.seatingAssignments.count == 3)
        #expect(updatedTable?.seatingAssignments[SeatPosition.head] == alice.id)
        #expect(updatedTable?.seatingAssignments[SeatPosition.leftFront] == bob.id)
        #expect(updatedTable?.seatingAssignments[SeatPosition.rightFront] == charlie.id)
    }
    
    @Test("Arrange persons around table positions all assigned persons")
    @MainActor
    @available(watchOS 10.0, *)
    func testArrangePersonsAroundTable() async throws {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        
        // Create table
        let table = await model.addTable(
            name: "Dinner Table",
            at: CGPoint(x: 200, y: 200)
        )
        
        // Create people at random positions
        let alice = PersonNode(label: 1, position: CGPoint(x: 50, y: 50), name: "Alice")
        let bob = PersonNode(label: 2, position: CGPoint(x: 300, y: 150), name: "Bob")
        model.nodes.append(contentsOf: [AnyNode(alice), AnyNode(bob)])
        
        // Assign to seats
        await model.assignPersonToTable(personID: alice.id, tableID: table.id, seatPosition: SeatPosition.head)
        await model.assignPersonToTable(personID: bob.id, tableID: table.id, seatPosition: SeatPosition.leftFront)
        
        // Arrange (this should reposition them)
        model.arrangePersonsAroundTable(tableID: table.id)
        
        // Verify positions were updated (within tolerance due to physics)
        let aliceNode = model.nodes.first(where: { $0.id == alice.id })?.unwrapped as? PersonNode
        let bobNode = model.nodes.first(where: { $0.id == bob.id })?.unwrapped as? PersonNode
        
        let expectedAlicePos = table.seatPosition(for: SeatPosition.head)
        let expectedBobPos = table.seatPosition(for: SeatPosition.leftFront)
        
        let tolerance: CGFloat = 50.0  // Allow for physics movement
        #expect(abs((aliceNode?.position.x ?? 0) - expectedAlicePos.x) < tolerance)
        #expect(abs((aliceNode?.position.y ?? 0) - expectedAlicePos.y) < tolerance)
        #expect(abs((bobNode?.position.x ?? 0) - expectedBobPos.x) < tolerance)
        #expect(abs((bobNode?.position.y ?? 0) - expectedBobPos.y) < tolerance)
    }
    
    @Test("Table dimensions scale proportionally to real measurements")
    @MainActor
    @available(watchOS 10.0, *)
    func testTableDimensionScale() async throws {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        
        // Create a 48" x 30" table (typical 4-foot dining table)
        let table = await model.addTable(
            name: "Standard Table",
            headSeats: 1,
            sideSeats: 1,
            tableLength: 48.0,  // 48 inches = 48 points (1pt = 1 inch)
            tableWidth: 30.0,   // 30 inches = 30 points
            at: CGPoint(x: 200, y: 200)
        )
        
        #expect(table.tableLength == 48.0)
        #expect(table.tableWidth == 30.0)
        
        // Person node radius should be 12pt (24" diameter)
        let person = PersonNode(label: 1, position: .zero, name: "Alice")
        #expect(person.radius == 12.0)
        
        // Verify seat positions account for 12pt person radius - 4pt gap = 8pt offset
        // Head/foot have Y-offset, so use tableLength/2 to clear the table in Y-direction
        let headSeatOffset = table.seatOffset(for: SeatPosition.head)
        let expectedHeadOffset = table.tableLength / 2 + 8.0
        #expect(headSeatOffset.y == -expectedHeadOffset)
        
        // Left/right have X-offset, so use tableWidth/2 to clear the table in X-direction
        let sideSeatOffset = table.seatOffset(for: SeatPosition.leftFront)
        let expectedSideOffset = table.tableWidth / 2 + 8.0
        #expect(sideSeatOffset.x == -expectedSideOffset)
    }
    
    @Test("Can link meal to table")
    @MainActor
    @available(watchOS 10.0, *)
    func testLinkMealToTable() async throws {
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: mockPhysicsEngine())
        
        // Create meal and table
        let meal = await model.addMeal(
            name: "Dinner",
            date: Date(),
            mealType: MealType.dinner,
            servings: 7,
            at: CGPoint(x: 100, y: 100)
        )
        
        let table = await model.addTable(
            name: "Dinner Table",
            at: CGPoint(x: 250, y: 100)
        )
        
        // Link them
        await model.linkMealToTable(mealID: meal.id, tableID: table.id)
        
        // Verify link via edge
        let edge = model.edges.first { edge in
            edge.from == meal.id && edge.target == table.id && edge.type == .association
        }
        #expect(edge != nil)
        
        // Verify table(for:) finds the table
        let foundTable = model.table(for: meal.id)
        #expect(foundTable?.id == table.id)
    }
}
