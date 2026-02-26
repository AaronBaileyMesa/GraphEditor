# GraphEditor Features

**Last Updated**: 2026-02-25

This document provides an overview of implemented features in the GraphEditor project.

## Table of Contents
- [Achievement Engine](#achievement-engine)
- [User Graph System](#user-graph-system)
- [Meal Planning & Taco Night](#meal-planning--taco-night)
- [Graph Editor Core](#graph-editor-core)
- [Node Types](#node-types)

---

## Achievement Engine

**Status**: Phase 1 Complete (Foundation), UI Layer Pending
**Documentation**: `ACHIEVEMENT_ENGINE_PHASE1_COMPLETE.md`, `ACHIEVEMENT_ENGINE_VISION.md`

### Implemented
- ✅ **AttemptNode**: Records each completed event with domain-specific metrics
- ✅ **MilestoneNode**: Unlockable achievements with 4-tier progression system
- ✅ **Taco Night Milestone Tree**: 5 milestones (First Event → Small Gathering → Dual Protein → Family Feast → Epic Feast)
- ✅ **Unlock Mechanics**: Previous milestones, attempt counts, metric thresholds
- ✅ **Graph Integration**: Initialization, attempt recording, progress queries
- ✅ **Stable UUIDs**: Persistent milestone identity across sessions
- ✅ **Physics Constraints**: Fixed positioning prevents achievement node drift

### Domains
- **Taco Night** (Complete): 5 milestones across 4 tiers
- **Running** (Planned): Distance progression system
- **Chess** (Planned): Game analysis and tactical patterns
- **Gospel Reading** (Planned): Sequential reading progression

### Next Steps
1. Create Achievement Dashboard UI to visualize milestone tree
2. Position attempt nodes intelligently (currently stack at 0,0)
3. Add celebration UI when milestones unlock
4. Hook up menu actions (Mark as Completed, View Linked Event)

---

## User Graph System

**Status**: Phases 1-4 Complete
**Documentation**: `USERGRAPH_IMPLEMENTATION.md`

### Implemented
- ✅ **GraphNode**: Sub-graphs appear as nodes on user graph canvas
- ✅ **User Graph State Persistence**: Positions, edges, pins saved to storage
- ✅ **Drag & Drop**: Reposition GraphNodes on canvas
- ✅ **User Edges**: Create relationships between graphs with labels
- ✅ **Pan & Zoom**: Canvas navigation with coordinate transformations
- ✅ **Pinned Nodes**: Pin important nodes from sub-graphs to user graph
- ✅ **Navigation**: Tap pinned node → jump to source graph and node
- ✅ **Context Awareness**: "Back to Home" button when viewing sub-graphs

### Architecture
- **UserGraphViewModel**: Manages canvas state and sync with storage
- **UserGraphState**: Persistent model (positions, edges, pins)
- **GraphNodeRenderer**: Custom rounded rectangle rendering
- **PinnedNodesView**: Displays pinned nodes on canvas with navigation

### Pending (Phase 5)
- Cross-graph query API (find all people, meals across graphs)
- AllPeopleView aggregation
- AllMealsView aggregation
- Global search functionality

---

## Meal Planning & Taco Night

**Status**: Complete with workflow controls
**Documentation**: Archived in `docs/archive/completed-features/`

### Core Features
- ✅ **Taco Template Builder**: Creates complete taco dinner workflow
  - 5 tasks: Plan → Shop → Prep → Cook → Serve
  - Backward scheduling from dinner time
  - Optimized positioning for Apple Watch
- ✅ **Workflow Management**: Start/stop workflow with auto-advance
- ✅ **Task Status Tracking**: pending → in progress → completed → skipped
- ✅ **Progress Visualization**: Progress bar showing completion percentage
- ✅ **Quick Actions**: "Complete: [Current Task]" one-tap advancement

### Node Types
- **MealNode**: Scheduled meals with date, guests, protein type
- **TaskNode**: Workflow tasks with status and timestamps
- **RecipeNode**: Recipe information with instructions and timing
- **IngredientNode**: Ingredients with quantity and measurement units

### Table Seating
- ✅ **TableNode**: Visual rectangle on graph representing physical table
- ✅ **Seating Assignments**: Assign PersonNodes to 7 seat positions
- ✅ **Spatial Positioning**: "Arrange All" positions persons around table
- ✅ **Meal Integration**: Link meals to tables via association edges

### Wizard Flow
- Guest count selection
- Table selection/creation
- Person preferences (protein, spice, shell, toppings)
- Meal time scheduling
- Review and creation

---

## Graph Editor Core

**Status**: Stable foundation with multi-graph support

### Graph Model
- ✅ **Multi-Graph Support**: Multiple independent graphs with switching
- ✅ **Physics Simulation**: Force-directed layout with configurable parameters
- ✅ **Segment System**: Directional layout (horizontal, vertical, radial)
- ✅ **Constraint System**: Fixed position, relative positioning, grouping
- ✅ **Undo/Redo**: Full operation history with snapshots
- ✅ **Persistence**: JSON-based graph storage with auto-save

### Rendering
- ✅ **Canvas-based Rendering**: GraphicsContext for efficient drawing
- ✅ **Zoom & Pan**: Multi-touch gestures with coordinate transformations
- ✅ **Node Selection**: Tap to select with visual feedback
- ✅ **Drag & Drop**: Reposition nodes with physics integration
- ✅ **Edge Rendering**: Visual connections with labels

### Control Nodes
- ✅ **Context-Aware Controls**: Adapt based on node type and state
- ✅ **Workflow Controls**: Start/stop workflow, complete task
- ✅ **Task Management**: Start, block, unblock, decline, reset
- ✅ **Construction Helpers**: Add child nodes, create edges
- ✅ **Generic Controls**: Edit, delete, duplicate, add edge

---

## Node Types

The project supports 13 distinct node types, each with specialized behavior:

### Core Types
- **Node**: Basic graph node with label and content
- **ControlNode**: Ephemeral context-aware action nodes

### Home Economics Types
- **MealNode**: Scheduled meal planning (orange/yellow/purple/pink by meal type)
- **TaskNode**: Workflow tasks (gray/yellow/green/red by status)
- **RecipeNode**: Recipe information (cyan)
- **IngredientNode**: Recipe ingredients (green, 0.9x size)
- **PersonNode**: People with dietary preferences (mass: 10.0)
- **TableNode**: Physical tables with seating (brown, mass: 30.0, fixed position)

### Decision Tree Types
- **DecisionNode**: Decision points (mass: 12.0)
- **ChoiceNode**: Choice options (mass: 8.0)
- **PreferenceNode**: User preferences (mass: 15.0)

### Achievement Types
- **AttemptNode**: Completed event sessions (domain emoji icon)
- **MilestoneNode**: Unlockable achievements (lock/star/checkmark icon)

### Financial Types (Foundation)
- **TransactionNode**: Income/expense tracking (green/red, 1.2x size)
- **CategoryNode**: Spending categories (custom colors, 1.5x size)

### User Graph Types
- **GraphNode**: Sub-graph references (rounded rectangle, 1.5x size)

---

## Testing

**Documentation**: `GraphEditorWatchTests/TESTING_GUIDE.md`

### Test Coverage
- **Core Functionality**: ~50 tests (ViewModels, GraphModel, operations)
- **UI & Integration**: ~25 tests (gestures, canvas, menus)
- **Home Economics**: 63 tests (meal planning, tasks, seating)
- **Performance**: ~22 tests (benchmarks, undo/redo)
- **User Graph**: Comprehensive integration tests
- **Total**: 190+ tests with code coverage enabled

### Test Patterns
- Swift Testing framework with async/await
- AAA pattern (Arrange, Act, Assert)
- Performance benchmarks with time limits
- Integration tests for end-to-end workflows

---

## Architecture Highlights

### NodeTypeDescriptor Pattern
- Declarative configuration for physics, rendering, interaction
- Zero type-casting in core systems
- Composable menu sections
- Status-based animations and haptics

### Graph-Based Progression
- Achievements modeled as graph relationships
- Milestone trees with hierarchical dependencies
- Attempt nodes linked to source events
- Natural progression mechanics through graph structure

### Multi-Graph Isolation
- Personal graph (_userGraph) for achievements
- Meal plan graphs for events
- User graph canvas for organization
- Clear separation prevents data coupling

### Performance Optimizations
- Reduced verbose logging (6000+ lines → ~100 lines)
- Bulk operations prevent physics interference
- Canvas-based rendering for efficiency
- Lazy loading of graph previews

---

## Documentation Structure

### Active Documentation
- `ACHIEVEMENT_ENGINE_VISION.md` - Strategic vision for progression system
- `ACHIEVEMENT_ENGINE_PHASE1_COMPLETE.md` - Implementation details
- `ACHIEVEMENT_ENGINE_NEXT_MOVES.md` - Next steps and recommendations
- `USERGRAPH_IMPLEMENTATION.md` - User graph feature reference
- `FEATURES.md` (this file) - Consolidated feature overview

### Archived Documentation
- `docs/archive/completed-features/` - Completed implementations
- `docs/archive/planning/` - Design documents and plans

### Component READMEs
- `GraphEditorWatch/README.md` - Watch app overview
- `GraphEditorShared/README.md` - Shared library documentation
- `GraphEditorWatchTests/TESTING_GUIDE.md` - Testing guide

---

## Known Issues & Technical Debt

### Immediate
- Attempt nodes stack at (0,0) - need positioning logic
- No achievement dashboard UI yet
- Milestone unlock celebrations not implemented
- Some menu actions not hooked up (Mark as Completed, View Linked Event)

### Architecture
- Node type system has duplication (64KB in specialized menus)
- `NODE_TYPE_REFACTOR_PLAN.md` proposes comprehensive refactor (6 weeks)
- Consider before adding more node types

### Future Enhancements
- Cross-graph aggregation queries
- Global search across all graphs
- Template system for custom goals
- Kafka integration for event streaming
- Leader dashboard for group analytics

---

## Getting Started

1. **Clone and Build**: Open `GraphEditor.xcworkspace` in Xcode
2. **Run Tests**: Press ⌘U to run the full test suite
3. **Launch on Watch**: Select Watch target and run
4. **Create Taco Night**: Use "New Taco Dinner" from graphs menu
5. **Explore User Graph**: Tap menu → navigate between graphs
6. **Try Achievements**: Complete taco nights to unlock milestones

For more details, see the individual documentation files linked throughout this document.
