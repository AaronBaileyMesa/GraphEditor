//
//  AddPersonTests.swift
//  GraphEditorWatchTests
//
//  Tests for addPerson() and the full TacoNight wizard creation flow
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct AddPersonTests {

    @MainActor
    private func makeModel() -> GraphModel {
        let storage = MockGraphStorage()
        let engine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: engine)
        model.isSimulating = false
        return model
    }

    // MARK: - addPerson basics

    @MainActor @Test("addPerson creates a PersonNode in the graph")
    func testAddPersonCreatesNode() async {
        let model = makeModel()
        let before = model.nodes.count

        _ = await model.addPerson(name: "Alice", at: CGPoint(x: 100, y: 100))

        #expect(model.nodes.count == before + 1, "Graph should gain one node")
    }

    @MainActor @Test("addPerson stores name correctly")
    func testAddPersonName() async {
        let model = makeModel()
        let person = await model.addPerson(name: "Bob", at: .zero)

        let found = model.nodes.first(where: { $0.id == person.id })?.unwrapped as? PersonNode
        #expect(found?.name == "Bob")
    }

    @MainActor @Test("addPerson stores protein preference")
    func testAddPersonProteinPreference() async {
        let model = makeModel()
        let person = await model.addPerson(
            name: "Carol",
            proteinPreference: .chicken,
            at: .zero
        )

        let found = model.nodes.first(where: { $0.id == person.id })?.unwrapped as? PersonNode
        #expect(found?.proteinPreference == .chicken)
    }

    @MainActor @Test("addPerson stores shell preference")
    func testAddPersonShellPreference() async {
        let model = makeModel()
        let person = await model.addPerson(
            name: "Dana",
            shellPreference: .softCorn,
            at: .zero
        )

        let found = model.nodes.first(where: { $0.id == person.id })?.unwrapped as? PersonNode
        #expect(found?.shellPreference == .softCorn)
    }

    @MainActor @Test("addPerson stores spice level")
    func testAddPersonSpiceLevel() async {
        let model = makeModel()
        let person = await model.addPerson(
            name: "Eve",
            defaultSpiceLevel: "hot",
            at: .zero
        )

        let found = model.nodes.first(where: { $0.id == person.id })?.unwrapped as? PersonNode
        #expect(found?.defaultSpiceLevel == "hot")
    }

    @MainActor @Test("addPerson stores topping preferences")
    func testAddPersonToppingPreferences() async {
        let model = makeModel()
        let toppings = ["Cheese", "Guacamole", "Cilantro"]
        let person = await model.addPerson(
            name: "Frank",
            toppingPreferences: toppings,
            at: .zero
        )

        let found = model.nodes.first(where: { $0.id == person.id })?.unwrapped as? PersonNode
        #expect(found?.toppingPreferences == toppings)
    }

    @MainActor @Test("addPerson stores dietary restrictions")
    func testAddPersonDietaryRestrictions() async {
        let model = makeModel()
        let restrictions = ["vegetarian", "gluten-free"]
        let person = await model.addPerson(
            name: "Grace",
            dietaryRestrictions: restrictions,
            at: .zero
        )

        let found = model.nodes.first(where: { $0.id == person.id })?.unwrapped as? PersonNode
        #expect(found?.dietaryRestrictions == restrictions)
    }

    @MainActor @Test("addPerson increments nextNodeLabel")
    func testAddPersonIncrementsLabel() async {
        let model = makeModel()
        let labelBefore = model.nextNodeLabel

        _ = await model.addPerson(name: "Hank", at: .zero)

        #expect(model.nextNodeLabel == labelBefore + 1)
    }

    @MainActor @Test("addPerson assigns correct position")
    func testAddPersonPosition() async {
        let model = makeModel()
        let pos = CGPoint(x: 42, y: 99)
        let person = await model.addPerson(name: "Ivy", at: pos)

        let found = model.nodes.first(where: { $0.id == person.id })?.unwrapped as? PersonNode
        #expect(found?.position == pos)
    }

    @MainActor @Test("multiple addPerson calls produce distinct nodes")
    func testMultiplePersonsAreDistinct() async {
        let model = makeModel()

        let alice = await model.addPerson(name: "Alice", at: CGPoint(x: 10, y: 10))
        let bob = await model.addPerson(name: "Bob", at: CGPoint(x: 20, y: 20))

        #expect(alice.id != bob.id)

        let persons = model.nodes.compactMap { $0.unwrapped as? PersonNode }
        #expect(persons.count == 2)
    }

    // MARK: - Full wizard creation flow

    @MainActor @Test("Wizard flow: persons + meal creates expected node types")
    func testWizardFlowCreatesExpectedNodes() async {
        let model = makeModel()

        // Step 1: Create persons (mimicking wizard personPreferences loop)
        let alice = await model.addPerson(
            name: "Alice",
            defaultSpiceLevel: "medium",
            proteinPreference: .beef,
            shellPreference: .crunchy,
            at: CGPoint(x: 100, y: 100)
        )
        let bob = await model.addPerson(
            name: "Bob",
            defaultSpiceLevel: "mild",
            proteinPreference: .chicken,
            shellPreference: .softFlour,
            at: CGPoint(x: 120, y: 100)
        )

        // Step 2: Create table and assign persons
        let table = await model.addTable(
            name: "Dining Table",
            headSeats: 2,
            sideSeats: 2,
            at: CGPoint(x: 100, y: 50)
        )
        await model.assignPersonToTable(personID: alice.id, tableID: table.id, seatIndex: 0)
        await model.assignPersonToTable(personID: bob.id, tableID: table.id, seatIndex: 1)

        // Step 3: Create meal via TacoTemplateBuilder
        _ = await TacoTemplateBuilder.buildGraph(
            in: model,
            guests: 2,
            dinnerTime: Date(),
            protein: .beef,
            at: CGPoint(x: 20, y: 200)
        )

        // Verify node types are all present
        let personNodes = model.nodes.compactMap { $0.unwrapped as? PersonNode }
        let tableNodes = model.nodes.compactMap { $0.unwrapped as? TableNode }
        let mealNodes = model.nodes.compactMap { $0.unwrapped as? MealNode }
        let taskNodes = model.nodes.compactMap { $0.unwrapped as? TaskNode }

        #expect(personNodes.count == 2, "Should have 2 person nodes")
        #expect(tableNodes.count == 1, "Should have 1 table node")
        #expect(mealNodes.count == 1, "Should have 1 meal node")
        #expect(taskNodes.count >= 6, "Should have at least 6 task nodes (shop/prep/cook/assemble/serve/cleanup)")
    }

    @MainActor @Test("Wizard flow: person preferences are preserved")
    func testWizardFlowPreservesPersonPreferences() async {
        let model = makeModel()

        let person = await model.addPerson(
            name: "Alice",
            defaultSpiceLevel: "hot",
            proteinPreference: .chicken,
            shellPreference: .softCorn,
            toppingPreferences: ["Cheese", "Jalapeños"],
            at: .zero
        )

        let retrieved = model.nodes.first(where: { $0.id == person.id })?.unwrapped as? PersonNode
        #expect(retrieved?.name == "Alice")
        #expect(retrieved?.defaultSpiceLevel == "hot")
        #expect(retrieved?.proteinPreference == .chicken)
        #expect(retrieved?.shellPreference == .softCorn)
        #expect(retrieved?.toppingPreferences.contains("Cheese") == true)
        #expect(retrieved?.toppingPreferences.contains("Jalapeños") == true)
    }

    @MainActor @Test("Wizard flow: table seating assigns persons correctly")
    func testWizardFlowTableSeating() async {
        let model = makeModel()

        let alice = await model.addPerson(name: "Alice", at: CGPoint(x: 100, y: 100))
        let bob = await model.addPerson(name: "Bob", at: CGPoint(x: 120, y: 100))

        let table = await model.addTable(
            name: "Dining Table",
            headSeats: 2,
            sideSeats: 1,
            at: CGPoint(x: 100, y: 50)
        )

        await model.assignPersonToTable(personID: alice.id, tableID: table.id, seatIndex: 0)
        await model.assignPersonToTable(personID: bob.id, tableID: table.id, seatIndex: 1)

        let updatedTable = model.nodes.first(where: { $0.id == table.id })?.unwrapped as? TableNode
        #expect(updatedTable?.seatingAssignments[0] == alice.id, "Alice should be in seat 0")
        #expect(updatedTable?.seatingAssignments[1] == bob.id, "Bob should be in seat 1")
    }

    @MainActor @Test("Wizard flow: meal has correct guest count")
    func testWizardFlowMealGuestCount() async {
        let model = makeModel()

        _ = await TacoTemplateBuilder.buildGraph(
            in: model,
            guests: 4,
            dinnerTime: Date(),
            protein: .chicken,
            at: .zero
        )

        let meal = model.nodes.compactMap { $0.unwrapped as? MealNode }.first
        #expect(meal?.guests == 4, "Meal should record 4 guests")
    }

    @MainActor @Test("Wizard flow: workflow tasks start as pending")
    func testWizardFlowTasksStartPending() async {
        let model = makeModel()

        _ = await TacoTemplateBuilder.buildGraph(
            in: model,
            guests: 2,
            dinnerTime: Date(),
            protein: .beef,
            at: .zero
        )

        let meal = model.nodes.compactMap { $0.unwrapped as? MealNode }.first!
        let tasks = model.orderedTasks(for: meal.id)

        #expect(!tasks.isEmpty, "Should have tasks")
        let allPending = tasks.allSatisfy { $0.status == .pending }
        #expect(allPending, "All tasks should start as pending")
    }

    @MainActor @Test("Wizard flow: createTacoOrder control creates TacoNode linked to person")
    func testCreateTacoOrderControl() async {
        let model = makeModel()
        let person = await model.addPerson(name: "Alice", at: CGPoint(x: 100, y: 100))

        // Simulate the createTacoOrder action directly (same logic as handleCreateTacoOrder)
        let tacoPosition = CGPoint(x: person.position.x + 60, y: person.position.y)
        let tacoNode = TacoNode(label: model.nextNodeLabel, position: tacoPosition)
        model.nextNodeLabel += 1
        model.nodes.append(AnyNode(tacoNode))
        await model.addEdge(from: person.id, target: tacoNode.id, type: .association)

        // Verify TacoNode exists and is linked
        let tacos = model.nodes.compactMap { $0.unwrapped as? TacoNode }
        #expect(tacos.count == 1, "Should have one taco node")

        let edge = model.edges.first(where: {
            $0.from == person.id && $0.target == tacoNode.id && $0.type == .association
        })
        #expect(edge != nil, "Should have association edge from person to taco")
    }

    @MainActor @Test("Wizard flow: taco protein toggle updates node")
    func testTacoProteinToggle() async {
        let model = makeModel()

        var taco = TacoNode(label: model.nextNodeLabel, position: .zero, protein: .beef)
        model.nextNodeLabel += 1
        model.nodes.append(AnyNode(taco))

        // Toggle to chicken
        guard let index = model.nodes.firstIndex(where: { $0.id == taco.id }) else {
            Issue.record("TacoNode not found")
            return
        }
        taco = taco.with(protein: .chicken)
        model.nodes[index] = AnyNode(taco)

        let updated = model.nodes[index].unwrapped as? TacoNode
        #expect(updated?.protein == .chicken)
    }

    @MainActor @Test("Wizard flow: taco topping toggle adds and removes")
    func testTacoToppingToggle() async {
        let model = makeModel()

        var taco = TacoNode(label: model.nextNodeLabel, position: .zero, toppings: [])
        model.nextNodeLabel += 1
        model.nodes.append(AnyNode(taco))

        guard let index = model.nodes.firstIndex(where: { $0.id == taco.id }) else {
            Issue.record("TacoNode not found")
            return
        }

        // Add cheese
        taco = taco.with(toppings: ["Cheese"])
        model.nodes[index] = AnyNode(taco)
        #expect((model.nodes[index].unwrapped as? TacoNode)?.toppings == ["Cheese"])

        // Remove cheese
        taco = taco.with(toppings: [])
        model.nodes[index] = AnyNode(taco)
        #expect((model.nodes[index].unwrapped as? TacoNode)?.toppings.isEmpty == true)
    }
}
