# Taco Night Wizard - Implementation Plan

## Overview
Redesign the taco night creation flow to be bachelor-friendly, segment-based, and preference-aware. The wizard should leverage existing infrastructure while introducing per-person customization and reusable seating plans.

## Current State Analysis

### Existing Infrastructure We're Leveraging

1. **Node Types** (GraphEditorShared/HomeEconomics/)
   - `PersonNode` - Has name, defaultSpiceLevel, dietaryRestrictions
   - `TableNode` - Has seatingAssignments, dimensions, shape
   - `MealNode` - Has date, mealType, servings, protein (needs review)
   - `TaskNode` - Has taskType, status, estimatedTime, hierarchy

2. **Segment System** (GraphModel)
   - `setSegmentConfig(rootNodeID, direction, strength, nodeSpacing)`
   - Already used for meal → task hierarchy layout
   - Can be extended for table → person layout

3. **Edge Types** (EdgeType enum)
   - `.association` - Currently used for table → person
   - `.hierarchy` - Used for parent → child tasks
   - `.configures` - Could link meal → table segment

4. **Helper Methods**
   - `addPerson(name, spiceLevel, restrictions, at:)` ✅
   - `addTable(name, headSeats, sideSeats, at:)` ✅
   - `assignPersonToTable(personID, tableID, seatPosition)` ✅
   - `createTacoNightTasks(for:guestCount:mealPosition:)` ✅ (Week 1 work)

### What Needs to Change

1. **PersonNode Enhancement**
   - Add protein preference (beef/chicken/veggie)
   - Add shell preference (soft/hard)
   - Add topping preferences
   - Keep existing: spiceLevel, dietaryRestrictions

2. **MealNode Simplification**
   - Remove protein (now person-level)
   - Keep: date, mealType, servings
   - Add: reference to table segment (via edge)

3. **Segment Strategy**
   - **Meal Segment**: Meal → Tasks (already exists)
   - **Table Segment**: Table → Persons (new)
   - Segments are reusable across graphs

## Proposed Wizard Flow

### Step 1: Guest Count
**UI**: Large number with crown input
- **Range**: 1-20 guests
- **Display**: "Taco Night for [N] people?"
- **Logic**:
  - If N = 1: Skip table setup, go to meal time
  - If N ≥ 2: Proceed to table selection

### Step 2: Table Selection (if ≥2 guests)
**UI**: List of options + "New Table" button
- **Options**:
  1. Show existing tables in graph (if any)
  2. "Create New Table" button
- **If existing table selected**: Skip to Step 4
- **If new table**: Proceed to Step 3

### Step 3: Table Creation (if needed)
**Screen 3a: Table Shape**
- **UI**: Three large buttons with icons
  - Rectangle 📐
  - Square ⬜
  - Circle ⭕

**Screen 3b: Table Dimensions** (based on shape)
- Rectangle: Length × Width
- Square: Size
- Circle: Diameter
- Auto-calculate seat count from dimensions + shape

**Screen 3c: Table Name**
- TextField with default: "Dining Table"
- Save as reusable segment

### Step 4: Guest Selection & Details
**Screen 4a: Who's Coming?**
- **UI**: Checklist of existing PersonNodes from graph
  - Shows name + last used preferences (e.g., "Alice - Beef, Hot, Hard shell")
  - Pre-select familiar attendees based on history
  - "✓ Alice" → Auto-loads her preferences
  - "+ Add New Guest" button at bottom
- **Fast path**: Tap checkboxes for regulars, hit Next
- **Slow path**: Add new guests, customize preferences

**Screen 4b: Person Preferences** (for each selected/new person)
- **UI**: Per-person full configuration
  - **Name**: TextField (editable, even for existing persons)
  - **Protein**: Beef / Chicken / Veggie (horizontal buttons)
  - **Spice**: Mild / Medium / Hot (horizontal buttons)
  - **Shell**: Soft / Hard (horizontal buttons)
  - **Toppings**: Multi-select grid (cheese, lettuce, tomato, onion, cilantro, sour cream, guac)
  - **Restrictions**: Multi-select chips (vegetarian, gluten-free, dairy-free, etc.)
- **Navigation**: Previous / Next person, or "Done" after last
- **Edit behavior**:
  - If editing existing person → Ask "Update [Name]'s default preferences?" or "Just for this meal"
  - If "Just for this meal" → Clone person node for this meal only
  - If "Update defaults" → Modify original PersonNode

### Step 5: Meal Time
**UI**: Time picker (reuse existing TimePickerView)
- Default: 6:30 PM same day
- Just the time - protein is per-person now

### Step 6: Review & Create
**UI**: Summary view
- Guest count
- Table name (if applicable)
- Meal time
- "17 tasks with assembly workflow"
- **Create** button

## Data Model Changes

### PersonNode Extensions
```swift
public struct PersonNode: NodeProtocol {
    // ... existing fields ...

    // NEW: Taco preferences
    public let proteinPreference: ProteinType?      // beef/chicken/veggie
    public let shellPreference: ShellType?          // soft/hard
    public let toppingPreferences: [String]         // ["cheese", "lettuce", "tomato"]

    // EXISTING (keep):
    public let defaultSpiceLevel: String?           // "mild"/"medium"/"hot"
    public let dietaryRestrictions: [String]        // ["vegetarian", "gluten-free"]
}
```

### New Enum: ShellType
```swift
@available(iOS 16.0, watchOS 9.0, *)
public enum ShellType: String, Codable, CaseIterable {
    case soft       // Flour tortilla
    case hard       // Crispy shell
}
```

### MealNode Simplification
```swift
public struct MealNode: NodeProtocol {
    // KEEP:
    public let date: Date
    public let mealType: MealType
    public let servings: Int

    // REMOVE (or make optional):
    // public let protein: ProteinType  // Now per-person

    // Access protein via: meal → table → persons → preferences
}
```

### Segment Configuration

**Table Segment** (new):
```swift
// When creating table + people
model.setSegmentConfig(
    rootNodeID: table.id,
    direction: .radial,          // People arranged around table
    strength: 2.0,               // Strong positioning
    nodeSpacing: 50.0            // Distance from table center
)
```

**Meal Segment** (existing, unchanged):
```swift
model.setSegmentConfig(
    rootNodeID: meal.id,
    direction: .horizontal,
    strength: 1.5,
    nodeSpacing: 35.0
)
```

## Implementation Phases

### Phase 1: Data Model Updates (Foundation)
**Files to modify:**
1. `PersonNode.swift` - Add protein/shell/topping preferences
2. `MealPlanningTypes.swift` - Add ShellType enum
3. `MealNode.swift` - Make protein optional or remove
4. `GraphModel+DecisionTree.swift` - Update addPerson() signature

**Validation:**
- Build succeeds
- Existing PersonNodes still decode (backward compatibility)

### Phase 2: Wizard UI (Core Flow)
**New file:** `TacoNightWizard.swift` (replace existing)
**Steps to implement:**
1. Step 1: Guest count with crown input
2. Step 2: Table selection (list existing + create new)
3. Step 3: Table creation (shape → dimensions → name)
4. Step 4: Guest details (per-person preferences)
5. Step 5: Meal time picker
6. Step 6: Review & create

**Dependencies:**
- Reuse `TimePickerView` for meal time
- Reuse `SimpleCrownNumberInput` for guest count
- Create new components for shape picker, preference selectors

### Phase 3: Graph Creation Logic
**File to modify:** `TacoNightWizard.swift` (createTacoNight method)

**Creation sequence:**
1. Create/select TableNode
2. Create PersonNodes with preferences
3. Assign persons to table seats
4. Set table segment config (radial layout)
5. Create MealNode (just time + servings)
6. Link meal → table via edge
7. Create task hierarchy (existing: createTacoNightTasks)
8. Set meal segment config (horizontal layout)

### Phase 4: Task Customization (Future Enhancement)
**Goal:** Use person preferences to customize task workflow
- Prep tasks based on protein distribution (3 beef, 2 chicken → prep both)
- Shopping list based on aggregate preferences
- Assembly tasks customized per person

**This is Week 2+ work** - foundation in Week 1 is sufficient

## Backward Compatibility Strategy

### Handling Existing Data
1. **PersonNode**: Make new fields optional with defaults
2. **MealNode**: Keep protein field but mark deprecated
3. **Migrations**: Not needed - optional fields handle gracefully

### Example Migration Path
```swift
// Old PersonNode (pre-wizard)
PersonNode(name: "Alice", defaultSpiceLevel: "medium", restrictions: [])

// New PersonNode (post-wizard)
PersonNode(
    name: "Alice",
    defaultSpiceLevel: "medium",
    restrictions: [],
    proteinPreference: .beef,      // NEW (optional)
    shellPreference: .hard,        // NEW (optional)
    toppingPreferences: ["cheese"] // NEW (empty default)
)
```

## File Structure

### New Files
- `TacoNightWizard.swift` (complete rewrite)
- `ShapePickerView.swift` (optional - can inline)

### Modified Files
- `PersonNode.swift` - Add preferences
- `MealPlanningTypes.swift` - Add ShellType
- `MealNode.swift` - Deprecate protein
- `GraphModel+DecisionTree.swift` - Update addPerson()
- `GraphsMenuView.swift` - Wire up new wizard

### Unchanged Files (reuse)
- `TableNode.swift` ✅
- `TaskNode.swift` ✅
- `GraphModel+TableManagement.swift` ✅
- `GraphModel+MealPlanning.swift` ✅
- `TacoTemplateBuilder.swift` ✅ (already updated in Week 1)

## Open Questions

### Q1: Table Storage
**Question:** Where do table segments persist?
**Options:**
A. Same graph as meal (current approach)
B. Special "furniture" graph (shared across meals)
C. User preference

**Recommendation:** Option A for MVP - tables in same graph as meal. Easy to visualize and manage.

### Q2: Person Reuse ✅ DECIDED
**Question:** Should persons be reusable across meals?
**Example:** Alice attends multiple taco nights with same preferences

**DECISION:** **Reuse by default, allow per-meal edits**
- Default: Show existing persons from graph, auto-select for reuse
- Allow: Add new guests for this meal ("+ Add Guest")
- Allow: Edit existing person preferences for this meal (creates override or new node)
- Philosophy: Fast reuse, but flexible for variations

**Implementation:**
1. Step 2: "Who's coming?" → List existing persons with checkboxes
2. Selected persons auto-populate their preferences
3. User can edit any preference (creates meal-specific override)
4. User can add temporary guests (new PersonNode)
5. Next meal: Same people pre-selected with their base preferences

### Q3: Preference UI Complexity ✅ DECIDED
**Question:** How detailed should per-person preferences be?

**DECISION:** **Full complexity from the start**
- Protein (beef/chicken/veggie)
- Spice (mild/medium/hot)
- Shell (soft/hard)
- Toppings (multi-select: cheese, lettuce, tomato, onion, cilantro, sour cream, guac)
- Dietary restrictions (vegetarian, gluten-free, dairy-free, etc.)

**Rationale:** The goal is to automate the full complexity of taco night. Simple, fast watch UI that captures complete preferences enables intelligent task generation and shopping lists.

### Q4: Bachelor Mode ✅ DECIDED
**Question:** For N=1 guest, do we skip table entirely or create a virtual table?

**DECISION:** Option A - Skip table for solo dining
- 1 guest: No table creation, just person + meal + tasks
- Simplified flow: Guest count → Who (self) → Preferences → Time → Create

## Success Criteria

### Week 1 (Foundation - COMPLETED ✅)
- [x] Extended TaskType with assembly subtasks
- [x] Created task hierarchy methods
- [x] Implemented createTacoNightTasks with 17 tasks
- [x] Tests passing

### Week 2 (Wizard MVP)
- [ ] PersonNode has protein + spice preferences
- [ ] Wizard flow: Guest count → Table → Preferences → Time → Create
- [ ] Creates table segment with radial layout
- [ ] Creates persons with preferences
- [ ] Creates meal linked to table
- [ ] Creates task hierarchy
- [ ] Build succeeds, basic flow works

### Week 3 (Polish)
- [ ] Table reuse works (select existing table)
- [ ] Crown input feels natural
- [ ] Per-person preference screens are clear
- [ ] Review screen shows complete summary
- [ ] Solo mode (N=1) works seamlessly

## Next Steps

1. **Approval**: Review this plan with user
2. **Phase 1**: Update data models (PersonNode, ShellType)
3. **Phase 2**: Implement wizard UI (step-by-step)
4. **Phase 3**: Wire up graph creation
5. **Test**: Manual testing on Watch simulator
6. **Iterate**: Based on UX feedback

## Notes

- **Reuse First**: Leverage existing SimpleCrownNumberInput, TimePickerView
- **One Screen Per Step**: No scrolling within wizard steps
- **Progressive Disclosure**: Only show relevant steps (skip table if N=1)
- **Segment-Based**: Table + persons = reusable segment
- **Preference-Aware**: Foundation for future task customization
