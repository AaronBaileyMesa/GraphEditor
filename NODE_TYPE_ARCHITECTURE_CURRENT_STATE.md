# Current Node Type Architecture - Pain Points Summary

**Generated:** 2026-02-13

This document summarizes the current state of the node type system and key pain points discovered during architecture analysis.

---

## Quick Stats

- **Node Types:** 13 different types (Node, MealNode, TaskNode, RecipeNode, IngredientNode, PersonNode, TableNode, DecisionNode, ChoiceNode, PreferenceNode, CategoryNode, TransactionNode, ControlNode)
- **Type-Cast Locations:** 50+ `as?` casts scattered across 10+ files
- **Specialized Menu Views:** 7 files (~64KB of duplicate code)
- **Physics Customizations:** 8 types with custom mass, 2 with fixed positioning
- **Rendering Systems:** 2 parallel systems (SwiftUI NodeView + GraphicsContext AccessibleCanvasRenderer)

---

## Critical Pain Points

### 1. Type Discrimination Explosion 💥

**Problem:** Type-checking (`as?`, `is`) scattered everywhere

**Locations:**
- NodeView.swift - 7 type casts
- MenuView.swift - 6 type checks
- AccessibleCanvasRenderer.swift - 3 type casts
- GraphGesturesModifier.swift - 2 type casts
- GraphSimulator.swift - 1 TableNode check
- PhysicsEngine.swift - 1 TableNode check
- AnyNode encoder/decoder - 12 switch cases

**Impact:** Adding new node type = 7+ file changes

---

### 2. Scattered Physics Logic 🌪️

**Example: TableNode Fixed Positioning**

Scattered across 4 files:

1. **GraphSimulator.swift:244-260** - Builds fixedIDs set
2. **PhysicsEngine.swift:343-356** - Has TableNode-specific centering skip
3. **GraphGesturesModifier.swift:144-165** - TableNode-specific drag behavior
4. **GraphModel+MealPlanning.swift** - Seating CRUD operations

**Missing:** Generic constraint/grouping system

---

### 3. Duplicate Rendering Systems 🎨

**Two parallel systems with same logic:**

**NodeView (SwiftUI):**
```swift
if let taskNode = node as? TaskNode {
    RoundedRectangle(...).fill(taskNode.fillColor).frame(width: taskNode.radius * 2.5 * zoomScale, ...)
} else if let mealNode = node as? MealNode {
    Circle().fill(mealNode.fillColor).frame(width: mealNode.radius * 2.6 * zoomScale, ...)
} else if ...
// 7 branches total
```

**AccessibleCanvasRenderer (GraphicsContext):**
```swift
if let table = node as? TableNode {
    // Draw rounded rectangle
} else {
    // Draw circle
}
```

**Problem:** Visual changes require updates to both systems

---

### 4. Menu System Explosion 📋

**7 Specialized Menu Views:**
- TaskNodeMenuView.swift (~6KB)
- MealNodeMenuView.swift (~14KB)
- DecisionNodeMenuView.swift (~15KB)
- PreferenceNodeMenuView.swift (~6KB)
- PersonNodeMenuView.swift (~9KB)
- TableNodeMenuView.swift (~14KB)
- NodeMenuView.swift (~9KB)

**Total:** ~64KB with 80% duplicate code

**Common patterns:**
- Node selection/deletion
- Edge creation
- Property editing
- Navigation/dismissal

**Type-specific:**
- TaskNode: Status, timing
- MealNode: Recipes, servings
- DecisionNode: Choice selection
- PersonNode: Dietary restrictions
- TableNode: Seating grid

---

### 5. No Animation Framework 🎬

**Current state:** Zero animation support

**Needed:**
- Selection pulse/highlight
- State change transitions
- Physics settling indicators
- Drag feedback
- Node appearance/removal

---

### 6. Minimal Haptics 📳

**Current usage:**
- `WKInterfaceDevice.current().play(.click)` for button taps
- No node-specific haptic feedback
- No custom haptic patterns

**Missing:**
- Selection haptics
- Drag haptics
- Physics event feedback
- Per-node-type patterns

---

## Adding a New Node Type Today

### Required Steps (4-9 file changes, 2-8 hours)

1. ✅ Create node struct (HomeEconomics/NewNode.swift)
2. ✅ Update AnyNode encoder/decoder (NodeProtocol.swift)
3. ✅ Update NodeView rendering (NodeView.swift)
4. ✅ Update AccessibleCanvasRenderer (AccessibleCanvasRenderer.swift)
5. ⚠️ Create specialized menu (NewNodeMenuView.swift) [optional]
6. ✅ Update MenuView routing (MenuView.swift)
7. ⚠️ Add physics customization [if needed]
8. ⚠️ Add drag handling [if needed]
9. ✅ Add factory methods (GraphModel+*.swift)

---

## Specific Examples

### Example 1: Mass Customization (8 different values)

```swift
// Default
public var mass: CGFloat { 1.0 }

// PersonNode
public var mass: CGFloat { 10.0 }

// TableNode
public var mass: CGFloat { 30.0 }

// DecisionNode
public var mass: CGFloat { 12.0 }

// ChoiceNode
public var mass: CGFloat { 8.0 }

// PreferenceNode
public var mass: CGFloat { 15.0 }
```

### Example 2: Visual Multipliers (7 different values)

| Node Type | Multiplier |
|-----------|------------|
| MealNode | 1.3x (via 2.6x frame) |
| TaskNode | 1.1x (via 2.5x frame) |
| RecipeNode | 1.4x |
| CategoryNode | 1.5x |
| IngredientNode | 0.9x |
| TransactionNode | 1.2x |
| PreferenceNode | 1.2x |

### Example 3: TableNode Seating (constraint system needed)

**Current implementation:**
- Fixed positioning in GraphSimulator (type-specific)
- Centering skip in PhysicsEngine (type-specific)
- Drag handling in GraphGesturesModifier (type-specific)
- Person position calculation in TableNode.seatPosition()
- Migration in GraphModel+MealPlanning

**Problem:** No generic "grouping" or "constraint" abstraction

---

## Key Files Reference

### Core
- `GraphEditorShared/Sources/GraphEditorShared/NodeProtocol.swift` - Protocol + AnyNode
- `GraphEditorShared/Sources/GraphEditorShared/GraphTypes.swift` - Base Node struct
- `GraphEditorShared/Sources/GraphEditorShared/PhysicsEngine.swift` - Physics
- `GraphEditorShared/Sources/GraphEditorShared/GraphSimulator.swift` - Simulation loop

### Rendering
- `GraphEditorWatch/Views/NodeView.swift` - SwiftUI rendering (7-branch if-else)
- `GraphEditorWatch/Views/AccessibleCanvasRenderer.swift` - GraphicsContext rendering

### Interaction
- `GraphEditorWatch/Views/GraphGesturesModifier.swift` - Tap, drag, long-press
- `GraphEditorWatch/Views/MenuView.swift` - Menu routing
- `GraphEditorWatch/Views/*NodeMenuView.swift` - 7 specialized menus

### Node Types
- `GraphEditorShared/Sources/GraphEditorShared/HomeEconomics/` - 11 node type implementations
- `GraphEditorShared/Sources/GraphEditorShared/ControlNode.swift` - Ephemeral controls

---

## Proposed Solution Summary

See **NODE_TYPE_REFACTOR_PLAN.md** for full details.

### Key Components

1. **NodeTypeDescriptor** - Declarative config for physics, rendering, interaction
2. **Constraint System** - Composable physics constraints (fixed, relative, grouping)
3. **Rendering Strategy** - Type-specific renderers without casting
4. **Menu Components** - Composable menu sections
5. **Animation Framework** - Node lifecycle and state animations
6. **Haptic System** - Context-aware haptic feedback

### Expected Results

- **Time to add new node type:** 2-8 hours → 30 minutes (94% reduction)
- **Type-cast locations:** 50+ → 0 (100% elimination)
- **Code reduction:** ~64KB menu duplication + scattered logic
- **New capabilities:** Animations, haptics, flexible constraints

---

## Next Steps

1. Review refactor plan
2. Prioritize phases
3. Create feature branch
4. Begin incremental implementation
5. Track metrics

**See:** NODE_TYPE_REFACTOR_PLAN.md for detailed implementation plan
