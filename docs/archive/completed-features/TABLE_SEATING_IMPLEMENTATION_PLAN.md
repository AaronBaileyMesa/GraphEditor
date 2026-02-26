# Table Seating Implementation Plan

**Date**: 2026-02-12
**Status**: Planning Phase
**Goal**: Implement graph-based seating arrangement for meals using existing person nodes

---

## 🎯 EXECUTIVE SUMMARY

The goal is to enable users to arrange seating for meals directly on the graph canvas by positioning existing PersonNode instances around a virtual table layout. The current implementation has **two conflicting approaches**:

1. **Sheet-based UI** (TableSeatingSheet + TableSeatingView) - Modal sheet with visual table representation
2. **TableNode-based UI** (TableNodeMenuView) - Separate table node with its own seating assignments

**User's Requirement**: Use the graph itself for seating arrangement with person nodes positioned spatially.

---

## 📊 CURRENT STATE ANALYSIS

### Data Model (GraphEditorShared)

#### 1. TableSeating Structure
**Location**: `GraphEditorShared/Sources/GraphEditorShared/HomeEconomics/TableSeating.swift`

```swift
public struct TableSeating: Codable {
    public let id: UUID
    public let mealID: NodeID  // Links to a MealNode
    public var assignments: [SeatPosition: NodeID]  // Maps seat positions to PersonNode IDs
}
```

**Key Features**:
- 7 seat positions: head, leftFront, leftMiddle, leftBack, rightFront, rightMiddle, rightBack
- Associated with MealNode (not TableNode)
- Stored in `GraphModel.tableSeatingsByMeal: [NodeID: TableSeating]`

**API Methods in GraphModel+MealPlanning.swift**:
- `tableSeating(for mealID:) -> TableSeating` - Get/create seating for a meal
- `assignSeat(personID:, to:, for:)` - Assign person to seat position
- `removeSeat(personID:, for:)` - Remove person from seat
- `seatedPersons(for:) -> [(PersonNode, SeatPosition)]` - Get seated people
- `unseatedPersons(for:) -> [PersonNode]` - Get available people

#### 2. TableNode Structure
**Location**: `GraphEditorShared/Sources/GraphEditorShared/HomeEconomics/TableNode.swift`

```swift
public struct TableNode: NodeProtocol {
    // ... standard node properties ...
    public let name: String
    public let headSeats: Int
    public let sideSeats: Int
    public let tableLength: CGFloat
    public let tableWidth: CGFloat
    public var seatingAssignments: [SeatPosition: NodeID]

    public func seatOffset(for position: SeatPosition) -> CGPoint
    public func seatPosition(for position: SeatPosition) -> CGPoint
}
```

**Key Features**:
- Separate node type with its own graph position
- Has its own seating assignments (duplicates TableSeating concept)
- Can calculate positions for person nodes around the table
- Uses association edges to link to person nodes

**API Methods in GraphModel+MealPlanning.swift**:
- `addTable(name:, ...)` - Create a new TableNode
- `assignPersonToTable(personID:, tableID:, seatPosition:)` - Assign and position person
- `removePersonFromTable(personID:, tableID:)` - Remove person from table
- `arrangePersonsAroundTable(tableID:)` - Position all assigned persons

### UI Implementation (GraphEditorWatch)

#### 1. Sheet-Based Approach (Legacy - Should Remove)

**TableSeatingSheet.swift** (261 lines):
- Modal sheet presented from MealNodeMenuView
- Shows table visualization + list of seat assignments
- Uses TableSeatingView for visual representation
- Manages person picker for seat selection
- **Uses MealNode-based seating (TableSeating struct)**

**TableSeatingView.swift** (124 lines):
- Visual table representation with seat circles
- Renders table as brown rounded rectangle
- Shows 7 seat positions around table
- Displays person labels on occupied seats
- **This is embedded IN the sheet, not on the main graph**

**Integration Point**:
```swift
// MealNodeMenuView.swift:147-153
.sheet(isPresented: $showTableSeating) {
    if let mealID = selectedNodeID {
        TableSeatingSheet(
            viewModel: viewModel,
            mealID: mealID,
            onDismiss: { showTableSeating = false }
        )
    }
}
```

#### 2. TableNode-Based Approach (Alternative - Conflicts with Goal)

**TableNodeMenuView.swift** (269 lines):
- Menu for TableNode instances (separate graph nodes)
- Manages seating via `TableNode.seatingAssignments`
- Has "Arrange All" button to position person nodes
- Uses different data model than MealNode seating
- **Not integrated with MenuView routing** (missing from switch statement)

**Problem**: TableNode is a separate approach using different data structures.

#### 3. Menu Integration

**MenuView.swift**:
```swift
// Lines 28-68: Routes to specialized menus based on node type
if node.unwrapped is MealNode {
    MealNodeMenuView(...)
} else if node.unwrapped is PersonNode {
    PersonNodeMenuView(...)
}
// MISSING: TableNode routing
```

**TableNode is not wired into the menu system!**

### Test Coverage

**TableSeatingTests.swift** (218 lines):
- Tests TableSeating struct operations (MealNode-based approach)
- Tests assignSeat, removeSeat, multiple assignments
- Tests seated/unseated person queries
- **Does NOT test TableNode operations**
- **Does NOT test UI positioning/arrangement**

---

## 🔍 CORE PROBLEM ANALYSIS

### The Fundamental Conflict

There are **TWO separate and incompatible table seating systems**:

#### System A: MealNode + TableSeating (Current Primary)
- **Data**: `GraphModel.tableSeatingsByMeal[mealID]` → `TableSeating` struct
- **UI**: TableSeatingSheet (modal) + TableSeatingView (visualization in sheet)
- **Positioning**: No automatic positioning of person nodes
- **Integration**: Accessed via MealNodeMenuView
- **Problem**: Seating visualization is in a modal sheet, not on the graph

#### System B: TableNode + seatingAssignments (Incomplete Alternative)
- **Data**: `TableNode.seatingAssignments` (separate from TableSeating)
- **UI**: TableNodeMenuView (not integrated into MenuView routing)
- **Positioning**: Has `arrangePersonsAroundTable()` to position nodes
- **Integration**: Not connected to menu system
- **Problem**: Creates a separate table node instead of using meal context

### What User Actually Wants

Based on the request: *"I want the user interface to be on the graph, with the arrangement of the existing person nodes"*

**Requirements**:
1. Seating should be configured in context of a **MealNode** (not a separate TableNode)
2. PersonNodes should be **visually positioned** around an implied table layout on the graph
3. Users should see the seating arrangement **directly on the graph canvas**, not in a modal
4. Should leverage existing PersonNode instances
5. Should integrate with meal planning workflow

---

## 🎨 PROPOSED SOLUTION

### Architecture Decision

**Use MealNode + TableSeating as the primary model**, but add visual positioning capabilities similar to TableNode's `arrangePersonsAroundTable()`.

**Key Insight**: We don't need a separate TableNode. The MealNode can serve as the "center" of the table, and we can position PersonNodes around it based on seat assignments.

### High-Level Design

```
MealNode (center of table)
    ↓ TableSeating (seat assignments)
    ↓ arrangePersonsAroundMeal()
PersonNode positioned around meal at calculated offsets
```

### Required Changes

#### 1. **Add Table Layout Calculations to MealNode**

**Where**: `GraphEditorShared/Sources/GraphEditorShared/HomeEconomics/MealNode.swift`

**Add methods**:
```swift
extension MealNode {
    /// Get position offset for a seat relative to meal center
    public func seatOffset(for position: SeatPosition) -> CGPoint

    /// Get absolute position for a seat
    public func seatPosition(for position: SeatPosition) -> CGPoint

    /// Table dimensions based on guest count
    public var tableLength: CGFloat
    public var tableWidth: CGFloat
}
```

**Logic**: Calculate table size based on `guests` property. Use similar math to TableNode.

#### 2. **Add Positioning Method to GraphModel**

**Where**: `GraphEditorShared/Sources/GraphEditorShared/HomeEconomics/GraphModel+MealPlanning.swift`

**Add method**:
```swift
@MainActor
public func arrangePersonsAroundMeal(mealID: NodeID) async {
    // Get meal node
    // Get table seating for meal
    // For each assignment:
    //   - Calculate position using meal.seatPosition(for:)
    //   - Update person node position
    //   - Optionally create/update edges
    // Save graph
}
```

#### 3. **Modify MealNodeMenuView**

**Where**: `GraphEditor/GraphEditorWatch/Views/MealNodeMenuView.swift`

**Changes**:
- Replace modal sheet with inline seating list
- Add "Arrange Seating" button that calls `arrangePersonsAroundMeal()`
- Show seated persons count
- Allow quick seat assignment/removal
- Optionally: Add "View on Graph" button that centers viewport on meal

#### 4. **Remove or Deprecate Sheet-Based UI**

**Files to Remove/Deprecate**:
- `TableSeatingSheet.swift` - Remove entirely
- `TableSeatingView.swift` - Remove entirely (or repurpose as graph overlay)

**Rationale**: These provide modal-based seating that conflicts with graph-based approach.

#### 5. **Handle TableNode (Decide on Future)**

**Options**:
1. **Remove TableNode entirely** - Simplest, removes confusion
2. **Keep TableNode for different use case** - E.g., restaurant layout planning
3. **Convert TableNode to decoration** - Visual element without seating logic

**Recommendation**: Keep TableNode but clearly separate it from meal seating. It could be useful for:
- Planning restaurant layouts
- Multi-table events
- Future expansion

But **do NOT use it for meal planning seating**. That should use MealNode + TableSeating.

#### 6. **Visual Feedback on Graph**

**Enhancement Ideas**:
- Show faint lines from MealNode to seated PersonNodes
- Highlight seated persons differently
- Optionally draw table outline around meal node (similar to TableSeatingView)

**Implementation**: Could add to `AccessibleCanvasRenderer.swift` or create new overlay.

---

## 📝 DETAILED IMPLEMENTATION STEPS

### Phase 1: Data Model Extensions (GraphEditorShared)

**Task 1.1**: Add table layout calculations to MealNode
- [ ] Add `seatOffset(for: SeatPosition) -> CGPoint` method
- [ ] Add `seatPosition(for: SeatPosition) -> CGPoint` method
- [ ] Add computed `tableLength` and `tableWidth` based on `guests`
- [ ] Consider seat spacing and positioning logic

**Task 1.2**: Add meal-based arrangement method to GraphModel
- [ ] Implement `arrangePersonsAroundMeal(mealID:)` in GraphModel+MealPlanning.swift
- [ ] Handle edge cases (meal not found, no seating, etc.)
- [ ] Decide on edge creation/removal behavior
- [ ] Add appropriate logging

**Task 1.3**: Write tests for new functionality
- [ ] Test seat position calculations for various guest counts
- [ ] Test `arrangePersonsAroundMeal()` positions nodes correctly
- [ ] Test with different numbers of seated persons
- [ ] Test edge creation behavior

### Phase 2: UI Changes (GraphEditorWatch)

**Task 2.1**: Modify MealNodeMenuView
- [ ] Remove `showTableSeating` state and sheet
- [ ] Add inline seating section with seat list
- [ ] Add "Arrange on Graph" button
- [ ] Show seated/unseated counts
- [ ] Add seat assignment UI (either inline or new focused view)

**Task 2.2**: Add seating assignment UI
**Option A**: Inline in menu
- Simpler, but limited space
- Good for quick assignments

**Option B**: Dedicated full-screen view
- More space for person selection
- Better UX for complex arrangements
- Can show preview of positions

**Recommendation**: Start with Option A, can enhance to B later.

**Task 2.3**: Remove obsolete views
- [ ] Delete TableSeatingSheet.swift
- [ ] Delete TableSeatingView.swift (or repurpose)
- [ ] Update any imports/references

### Phase 3: Integration & Polish

**Task 3.1**: Add visual feedback
- [ ] Optionally draw table outline in AccessibleCanvasRenderer
- [ ] Highlight seated persons
- [ ] Add edges from meal to seated persons

**Task 3.2**: Test end-to-end workflow
- [ ] Create meal
- [ ] Create persons
- [ ] Assign seats via menu
- [ ] Trigger arrangement
- [ ] Verify positions on graph
- [ ] Test save/load persistence

**Task 3.3**: Update documentation
- [ ] Update README if exists
- [ ] Add code comments
- [ ] Document user workflow

### Phase 4: Cleanup (Optional)

**Task 4.1**: Decide TableNode fate
- [ ] Document TableNode as separate from meal seating
- [ ] Either remove or clearly scope its purpose
- [ ] Update tests accordingly

**Task 4.2**: Performance optimization
- [ ] Ensure no unnecessary recomputations
- [ ] Test with many persons/seats
- [ ] Optimize rendering if needed

---

## 🧪 TESTING STRATEGY

### Unit Tests

**GraphEditorShared**:
- MealNode.seatOffset() returns correct positions
- MealNode.seatPosition() accounts for meal position
- arrangePersonsAroundMeal() updates node positions
- Edge creation/removal works correctly
- Persistence of arranged positions

**GraphEditorWatch**:
- MealNodeMenuView shows correct seating state
- Seat assignment updates model
- UI reflects changes after arrangement

### Integration Tests

- Full workflow: meal creation → person creation → assignment → arrangement
- Save/load preserves seating and positions
- Multiple meals with different seatings
- Edge cases: no persons, all seats filled, etc.

### Manual Testing Checklist

- [ ] Create meal with 7 guests
- [ ] Create 7 person nodes scattered on graph
- [ ] Open meal menu
- [ ] Assign persons to seats
- [ ] Trigger "Arrange on Graph"
- [ ] Verify persons move to positions around meal
- [ ] Save and reload graph
- [ ] Verify positions persist
- [ ] Test with fewer persons than seats
- [ ] Test reassignment
- [ ] Test removal from seat

---

## 🚨 POTENTIAL CHALLENGES

### 1. **Position Conflicts**

**Problem**: What if person nodes are already positioned for other purposes?

**Solutions**:
- User must explicitly trigger arrangement (not automatic)
- Provide undo capability
- Warn user before moving nodes
- Consider "snap to seat" vs "suggest position"

### 2. **Physics Simulation Interference**

**Problem**: Physics might move arranged nodes away from calculated positions.

**Solutions**:
- Use bulk operations during arrangement (learned from DECISION_TREE_ALIGNMENT_DEBUG.md)
- Pin nodes to positions after arrangement
- Create strong spring forces from meal to persons
- Temporarily disable simulation

**Recommendation**: Use bulk operations pattern:
```swift
await model.beginBulkOperation()
// Arrange all persons
await model.endBulkOperation()
await model.saveGraph()
```

### 3. **Edge Management**

**Problem**: Should we create edges from meal to persons? What about existing edges?

**Decisions Needed**:
- Create association edges? (TableNode does this)
- Remove edges on unassignment?
- Visual appearance of seating edges vs other edges

**Recommendation**:
- Create association edges for visual clarity
- Tag them as "seating" edges for special rendering
- Remove on unassignment

### 4. **Multi-Meal Conflicts**

**Problem**: Can a person be seated at multiple meals?

**Current Behavior**: TableSeating is per-meal, so technically yes.

**Decisions Needed**:
- Allow or prevent multi-meal seating?
- How to handle if person is already seated elsewhere?

**Recommendation**: Allow it for now (different meals at different times), but add warning in UI.

### 5. **Scale and Spacing**

**Problem**: What if graph is zoomed out? Positions too close/far?

**Solutions**:
- Make spacing configurable
- Scale based on zoom level
- Use AppConstants for default spacing

### 6. **Accessibility**

**Problem**: VoiceOver navigation of spatial seating arrangement.

**Solutions**:
- Ensure seat labels are clear
- Provide ordered list in menu
- Announce positions when arranged

---

## 🎯 RECOMMENDED IMPLEMENTATION ORDER

### Sprint 1: Core Functionality (Minimum Viable)
1. Add MealNode seat calculation methods
2. Add arrangePersonsAroundMeal() to GraphModel
3. Test positioning logic
4. Update MealNodeMenuView to call arrangement
5. Remove TableSeatingSheet/View

**Goal**: User can assign seats in menu and trigger arrangement on graph.

### Sprint 2: UI Polish
1. Improve seat assignment UX in menu
2. Add visual feedback on graph (edges, highlighting)
3. Add undo/confirmation
4. Handle edge cases

**Goal**: Smooth, intuitive user experience.

### Sprint 3: Integration & Testing
1. Full integration testing
2. Performance testing
3. Accessibility testing
4. Documentation

**Goal**: Production-ready feature.

### Sprint 4: Optional Enhancements
1. Decide TableNode future
2. Advanced visuals (table outline on graph)
3. Multi-table support (if needed)
4. Animation of arrangement

---

## 🔧 KEY TECHNICAL DECISIONS

### Decision 1: Data Model Primary

**Choice**: Use MealNode + TableSeating (System A), extend with positioning.

**Rationale**:
- Already integrated with meal workflow
- Tests exist
- Makes semantic sense (seating is part of meal planning)
- TableNode is redundant for this use case

### Decision 2: TableNode Fate

**Choice**: Keep TableNode but scope it separately from meal seating.

**Rationale**:
- May be useful for different scenarios
- Minimal effort to keep vs remove
- Clearly document separation

### Decision 3: UI Approach

**Choice**: Remove modal sheet, add inline controls in MealNodeMenuView.

**Rationale**:
- User wants seating on graph, not in modal
- Simpler mental model
- Reduces UI complexity

### Decision 4: Automatic vs Manual Arrangement

**Choice**: Manual arrangement triggered by button.

**Rationale**:
- Avoids unintended position changes
- User has control
- Can pre-assign seats, then arrange all at once

### Decision 5: Edge Creation

**Choice**: Create association edges from meal to seated persons.

**Rationale**:
- Visual clarity
- Follows TableNode pattern
- Can be styled differently

---

## 📚 FILES TO MODIFY

### GraphEditorShared (Submodule)

**Modify**:
- `Sources/GraphEditorShared/HomeEconomics/MealNode.swift` - Add seat calculations
- `Sources/GraphEditorShared/HomeEconomics/GraphModel+MealPlanning.swift` - Add arrangePersonsAroundMeal()

**Tests**:
- Create `Tests/GraphEditorSharedTests/HomeEconomics/MealSeatingTests.swift` (new)

### GraphEditorWatch

**Modify**:
- `Views/MealNodeMenuView.swift` - Update seating UI

**Delete**:
- `Views/TableSeatingSheet.swift`
- `Views/TableSeatingView.swift`

**Keep (but document scope)**:
- `Views/TableNodeMenuView.swift` - Keep for non-meal table management

**Tests**:
- Update `GraphEditorWatchTests/MealDefinitionSheetTests.swift` if affected
- Possibly add UI tests for meal menu seating

---

## 🎓 LESSONS FROM DECISION_TREE_ALIGNMENT_DEBUG.md

### Apply Bulk Operations Pattern

When creating/arranging nodes programmatically:
```swift
await model.beginBulkOperation()
// Create or move nodes
await model.saveGraph()  // SAVE BEFORE ending bulk ops!
await model.endBulkOperation()
```

**Why**: Prevents physics simulation from interfering with intended positions.

### Save Before Ending Bulk Operations

The pattern:
```swift
await model.beginBulkOperation()
// ... modifications ...
await model.saveGraph()      // ← Save first!
await model.endBulkOperation() // ← Then end bulk mode
```

**Why**: Ensures positions are persisted before simulation can modify them.

### Test Position Preservation

Add tests that verify:
- Positions immediately after setting
- Positions after save/load cycle
- Positions don't drift during simulation

---

## 📊 SUCCESS CRITERIA

### Functional Requirements
- [ ] User can assign persons to seats via MealNodeMenuView
- [ ] "Arrange on Graph" button positions persons around meal
- [ ] Positions are calculated correctly based on seat assignments
- [ ] Positions persist after save/load
- [ ] Seated persons are visually connected to meal (edges)
- [ ] Unseated persons remain in original positions

### Non-Functional Requirements
- [ ] Performance: Arrangement completes in < 500ms
- [ ] No physics drift after arrangement
- [ ] Clear visual feedback of seating state
- [ ] Accessible via VoiceOver
- [ ] Works with 1-7 seated persons
- [ ] Code is well-documented

### User Experience
- [ ] Intuitive workflow
- [ ] No modal interruptions
- [ ] Clear seat labels
- [ ] Easy to modify seating
- [ ] Visual feedback on graph

---

## 🚀 NEXT STEPS

1. **Review this plan** with user for alignment
2. **Confirm scope**: Which phases to implement now vs later
3. **Start with Phase 1, Task 1.1**: Add seat calculations to MealNode
4. **Work through implementation systematically**
5. **Test thoroughly at each step**

---

## ❓ OPEN QUESTIONS FOR USER

1. **TableNode**: Should we remove it, or keep it for other use cases?
2. **Edge styling**: Should seating edges look different from other edges?
3. **Arrangement trigger**: Automatic on assignment, or manual button?
4. **Multi-meal seating**: Allow or prevent a person being seated at multiple meals?
5. **Table visualization**: Show table outline on graph, or just position persons?
6. **Spacing**: Fixed spacing or configurable by user?

---

**End of Plan**
