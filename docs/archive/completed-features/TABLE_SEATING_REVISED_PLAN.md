# Table Seating Implementation Plan (REVISED)

**Date**: 2026-02-12
**Status**: Ready for Implementation
**Approach**: TableNode-centric (Option A - Simple)

---

## 🎯 GOAL

Enable users to arrange seating for meals using:
- **TableNode** - Visible rectangle on graph (the physical table)
- **PersonNodes** - Positioned around the table at assigned seats
- **MealNode** - Links to the table for meal planning context

---

## 🏗️ ARCHITECTURE

```
MealNode (meal planning)
    ↓ (link via edge or property)
TableNode (visual table on graph)
    ↓ seatingAssignments: [SeatPosition: NodeID]
    ↓ arrangePersonsAroundTable()
PersonNodes positioned around table
```

**Single source of truth**: TableNode.seatingAssignments

---

## 📝 PHASE 1: CORE IMPLEMENTATION

### Task 1.1: Wire TableNode into Menu System ✓

**File**: `GraphEditor/GraphEditorWatch/Views/MenuView.swift`

**Change**: Add TableNode routing (currently missing!)

```swift
// Add after PersonNode check (line 55-60)
} else if node.unwrapped is TableNode {
    TableNodeMenuView(
        viewModel: viewModel,
        onDismiss: { showMenu = false },
        selectedNodeID: $selectedNodeID
    )
}
```

### Task 1.2: Test TableNode Menu Access

**Manual Test**:
1. Create a TableNode on graph
2. Tap to select it
3. Verify TableNodeMenuView appears
4. Check seat assignment UI works

### Task 1.3: Link MealNode to TableNode

**Option A** (Simpler): Use edges
- Create association edge: MealNode → TableNode
- No MealNode property changes needed
- Find table via edges

**Option B**: Add property to MealNode
- Add `var tableID: NodeID?` to MealNode
- More direct, but requires data model changes

**Decision**: Start with **Option A (edges)** for simplicity.

**File**: `GraphEditorShared/Sources/GraphEditorShared/HomeEconomics/GraphModel+MealPlanning.swift`

**Add method**:
```swift
/// Links a meal to its table
@MainActor
public func linkMealToTable(mealID: NodeID, tableID: NodeID) async {
    await addEdge(from: mealID, target: tableID, type: .association)
}

/// Gets the table for a meal
@MainActor
public func table(for mealID: NodeID) -> TableNode? {
    guard let tableEdge = edges.first(where: {
        $0.from == mealID && $0.type == .association
    }) else {
        return nil
    }

    return nodes.first(where: { $0.id == tableEdge.target })?.unwrapped as? TableNode
}
```

### Task 1.4: Update MealNodeMenuView

**File**: `GraphEditor/GraphEditorWatch/Views/MealNodeMenuView.swift`

**Changes**:
1. Remove `showTableSeating` state (line 20)
2. Remove `.sheet(isPresented: $showTableSeating)` (lines 147-153)
3. Update "Arrange Seating" button to navigate to table:

```swift
// Replace lines 122-126
Text("Table Seating").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading)

if let table = viewModel.model.table(for: meal.id) {
    actionButton("Manage Table Seating", icon: "person.3.fill", color: .orange) {
        selectedNodeID = table.id  // Navigate to table node
    }
} else {
    actionButton("Create Table", icon: "plus.rectangle.fill", color: .orange) {
        createTableForMeal()
    }
}
```

**Add helper method**:
```swift
private func createTableForMeal() {
    guard let meal = mealNode else { return }

    Task {
        // Create table near meal
        let tablePosition = CGPoint(
            x: meal.position.x + 150,
            y: meal.position.y
        )

        let table = await viewModel.model.addTable(
            name: "\(meal.name) Table",
            headSeats: 1,
            sideSeats: min(3, meal.guests / 2),  // Adjust based on guest count
            at: tablePosition
        )

        // Link meal to table
        await viewModel.model.linkMealToTable(mealID: meal.id, tableID: table.id)

        // Navigate to table
        await MainActor.run {
            selectedNodeID = table.id
        }
    }
}
```

### Task 1.5: Remove Obsolete Files

**Delete**:
- `GraphEditor/GraphEditorWatch/Views/TableSeatingSheet.swift`
- `GraphEditor/GraphEditorWatch/Views/TableSeatingView.swift`

**Remove from**:
- Any imports referencing these files

### Task 1.6: Update/Remove Obsolete Data Model

**File**: `GraphEditorShared/Sources/GraphEditorShared/HomeEconomics/GraphModel+MealPlanning.swift`

**Options**:
1. **Remove entirely**: Delete TableSeating struct and all meal-based seating methods
2. **Deprecate**: Mark as deprecated but keep for compatibility

**Decision**: **Remove entirely** for simplicity.

**Remove**:
- `TableSeating` struct (from TableSeating.swift)
- `GraphModel.tableSeatingsByMeal` property
- Methods: `tableSeating(for:)`, `updateTableSeating()`, `assignSeat()`, `removeSeat()`, `seatedPersons()`, `unseatedPersons()`

**Keep**:
- TableNode-related methods: `addTable()`, `assignPersonToTable()`, `removePersonFromTable()`, `arrangePersonsAroundTable()`

### Task 1.7: Update Tests

**File**: `GraphEditorWatchTests/TableSeatingTests.swift`

**Options**:
1. **Rewrite** to test TableNode-based seating
2. **Remove** and create new tests

**Decision**: **Rewrite** to test TableNode seating:

```swift
@Test("Can assign person to table seat")
@MainActor
func testAssignPersonToTableSeat() async throws {
    let storage = MockGraphStorage()
    let model = GraphModel(storage: storage)

    // Create table
    let table = await model.addTable(
        name: "Dinner Table",
        at: CGPoint(x: 100, y: 100)
    )

    // Create person
    let person = PersonNode(label: 1, position: CGPoint(x: 50, y: 50), name: "Alice")
    model.nodes.append(AnyNode(person))

    // Assign person to seat
    await model.assignPersonToTable(
        personID: person.id,
        tableID: table.id,
        seatPosition: .head
    )

    // Verify assignment
    let updatedTable = model.nodes.first(where: { $0.id == table.id })?.unwrapped as? TableNode
    #expect(updatedTable?.seatingAssignments[.head] == person.id)

    // Verify person was positioned
    let updatedPerson = model.nodes.first(where: { $0.id == person.id })?.unwrapped as? PersonNode
    let expectedPosition = table.seatPosition(for: .head)
    #expect(updatedPerson?.position.x == expectedPosition.x)
    #expect(updatedPerson?.position.y == expectedPosition.y)
}
```

---

## 🎯 PHASE 1 DELIVERABLES

After Phase 1, users should be able to:

1. ✅ Create a TableNode on the graph (already works)
2. ✅ Select TableNode and open TableNodeMenuView
3. ✅ Assign PersonNodes to seats via TableNodeMenuView
4. ✅ Click "Arrange All" to position persons around table
5. ✅ Create a MealNode
6. ✅ Link MealNode to TableNode (create new table or link existing)
7. ✅ Navigate from MealNodeMenuView to TableNodeMenuView
8. ❌ No more modal TableSeatingSheet

---

## 🧪 TESTING CHECKLIST

### Manual Tests
- [ ] Create TableNode, verify it appears on graph
- [ ] Select TableNode, verify menu opens
- [ ] Assign person to seat, verify assignment works
- [ ] Click "Arrange All", verify persons move to correct positions
- [ ] Create MealNode
- [ ] Create table from MealNodeMenu
- [ ] Navigate from MealNode to TableNode via menu
- [ ] Save and reload graph
- [ ] Verify table-person positions persist

### Unit Tests
- [ ] TableNode seat position calculations
- [ ] assignPersonToTable updates both table and person
- [ ] arrangePersonsAroundTable positions all assigned persons
- [ ] linkMealToTable creates edge
- [ ] table(for:) finds linked table

---

## 📋 FILES TO CHANGE

### GraphEditorShared (Submodule)

**Modify**:
- `Sources/GraphEditorShared/HomeEconomics/GraphModel+MealPlanning.swift`
  - Add: `linkMealToTable()`, `table(for:)`
  - Remove: TableSeating-related methods (optional - can deprecate)

**Remove** (optional):
- `Sources/GraphEditorShared/HomeEconomics/TableSeating.swift` (if removing entirely)

### GraphEditorWatch

**Modify**:
- `Views/MenuView.swift` - Add TableNode routing
- `Views/MealNodeMenuView.swift` - Replace sheet with navigation to table

**Delete**:
- `Views/TableSeatingSheet.swift`
- `Views/TableSeatingView.swift`

**Keep**:
- `Views/TableNodeMenuView.swift` - Already has the UI we need!

**Tests**:
- `GraphEditorWatchTests/TableSeatingTests.swift` - Rewrite for TableNode approach

---

## 🚀 IMPLEMENTATION ORDER

1. Wire TableNode into MenuView
2. Add meal-to-table linking methods in GraphModel
3. Update MealNodeMenuView to navigate to table
4. Test manually
5. Delete obsolete sheet files
6. Update tests
7. Remove obsolete TableSeating data model (optional cleanup)

---

## 💡 KEY DECISIONS

1. **TableNode is the visual table** - Shows as rectangle on graph
2. **Single source of truth** - TableNode.seatingAssignments
3. **Meal links to table via edge** - Simple, no data model changes
4. **Reuse existing TableNodeMenuView** - Already has seating UI!
5. **Remove MealNode-based TableSeating** - Eliminates duplication

---

## ✨ SIMPLIFICATIONS

Compared to original plan:
- ❌ No MealNode seat calculations (use TableNode's)
- ❌ No new data structures (use existing TableNode)
- ❌ No new menu views (use existing TableNodeMenuView)
- ✅ Just wire everything together!
- ✅ Delete obsolete code

---

**This is much simpler!** Ready to implement.
