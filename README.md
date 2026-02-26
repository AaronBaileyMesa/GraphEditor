# GraphEditor

A graph-based progression tracking system for Apple Watch that transforms life goals into visual achievement trees.

**Current Focus**: Achievement Engine - Personal development tracking across multiple domains (physical, spiritual, strategic, social)

## Project Status

**Phase**: Achievement Engine Phase 1 Complete (Foundation)
**Branch**: `feature/achievement-engine-phase1`
**Last Updated**: 2026-02-25

### Recent Milestones
- ✅ Achievement engine foundation (AttemptNode, MilestoneNode)
- ✅ Taco Night milestone tree (5 milestones across 4 tiers)
- ✅ User graph system (Phases 1-4 complete)
- ✅ Meal planning workflow with table seating
- ✅ Multi-graph support with navigation

### Next Steps
1. Create Achievement Dashboard UI
2. Add celebration animations for milestone unlocks
3. Position attempt nodes intelligently
4. Add second domain (Gospel Reading)

## Quick Start

### Prerequisites
- Xcode 15+
- watchOS 10+ SDK
- Swift 5.9+

### Building
```bash
# Open workspace
open GraphEditor.xcworkspace

# Build and run on Watch simulator
# Select GraphEditorWatch scheme and press ⌘R
```

### Testing
```bash
# Run all tests
# Press ⌘U in Xcode

# Or via command line
xcodebuild test -scheme GraphEditorWatch
```

## Documentation

### Overview
- **[FEATURES.md](FEATURES.md)** - Complete feature list and status
- **[ACHIEVEMENT_ENGINE_VISION.md](ACHIEVEMENT_ENGINE_VISION.md)** - Strategic vision and roadmap

### Implementation Details
- **[ACHIEVEMENT_ENGINE_PHASE1_COMPLETE.md](ACHIEVEMENT_ENGINE_PHASE1_COMPLETE.md)** - Achievement engine implementation
- **[ACHIEVEMENT_ENGINE_NEXT_MOVES.md](ACHIEVEMENT_ENGINE_NEXT_MOVES.md)** - Recommended next steps
- **[USERGRAPH_IMPLEMENTATION.md](USERGRAPH_IMPLEMENTATION.md)** - User graph system reference

### Component Documentation
- **[GraphEditorWatch/README.md](GraphEditorWatch/README.md)** - Watch app overview
- **[GraphEditorShared/README.md](GraphEditorShared/README.md)** - Shared library docs
- **[GraphEditorWatchTests/TESTING_GUIDE.md](GraphEditorWatchTests/TESTING_GUIDE.md)** - Testing guide

### Archived
- **[docs/archive/](docs/archive/)** - Completed features and historical planning documents

## Architecture

### Core Components

**Graph Engine** (`GraphEditorShared`)
- Multi-graph support with independent node/edge spaces
- Physics-based layout with directional segments
- Constraint system (fixed position, relative, grouping)
- Undo/redo with operation history
- JSON persistence with auto-save

**Achievement System** (`HomeEconomics`)
- AttemptNode: Records completed sessions with metrics
- MilestoneNode: Unlockable achievements with tier progression
- Domain-specific milestone trees (Taco Night, Running, Chess, Gospel Reading)
- Unlock mechanics: prerequisites, attempt counts, metric thresholds

**User Interface** (`GraphEditorWatch`)
- Canvas-based graph visualization with zoom/pan
- Context-aware control nodes
- Multi-graph navigation with "Back to Home"
- Achievement dashboard (pending)
- Specialized node menus (Meal, Task, Person, Table, etc.)

### Node Types (13 Total)

**Core**: Node, ControlNode
**Home Economics**: MealNode, TaskNode, RecipeNode, IngredientNode, PersonNode, TableNode
**Decision Trees**: DecisionNode, ChoiceNode, PreferenceNode
**Achievements**: AttemptNode, MilestoneNode
**User Graph**: GraphNode

See [FEATURES.md](FEATURES.md) for detailed descriptions.

## Project Vision

GraphEditor is evolving into a **personal achievement engine** that tracks mastery and provides persistent coaching across life domains:

1. **Physical**: Running distance progression
2. **Spiritual**: Gospel reading completion
3. **Strategic**: Chess tactical mastery
4. **Social**: Hosting taco nights

**Not**: Four separate apps
**But**: One unified progression system with domain-specific UX

### The Achievement Model
- Every attempt creates a node in the graph
- Completing activities unlocks new milestones
- Visual skill trees show progression paths
- Apple Watch provides always-available coaching
- Data ownership with optional Kafka repository

See [ACHIEVEMENT_ENGINE_VISION.md](ACHIEVEMENT_ENGINE_VISION.md) for complete vision.

## Key Features

### Achievement Engine (Phase 1 Complete)
- Milestone trees with 4-tier progression
- Attempt tracking with domain-specific metrics
- Unlock mechanics (prerequisites, counts, thresholds)
- Taco Night domain complete (5 milestones)

### User Graph System
- Sub-graphs appear as draggable nodes
- Create edges between related graphs
- Pin important nodes for quick access
- Navigate from pins directly to source

### Meal Planning
- Taco night wizard with preferences
- Task workflow (plan → shop → prep → cook → serve)
- Table seating with spatial positioning
- Recipe/ingredient management

### Graph Editor Core
- Multi-graph support with switching
- Physics simulation with segments
- Zoom, pan, drag & drop
- Undo/redo throughout
- JSON persistence

## Testing

**Test Count**: 190+ tests
**Coverage**: Enabled in test plans
**Framework**: Swift Testing with async/await

### Running Tests
```bash
# All tests
⌘U in Xcode

# Specific test file
xcodebuild test -scheme GraphEditorWatch \
  -only-testing:GraphEditorWatchTests/UserGraphTests
```

See [TESTING_GUIDE.md](GraphEditorWatchTests/TESTING_GUIDE.md) for patterns and examples.

## Development Workflow

### Active Branch
```bash
git checkout feature/achievement-engine-phase1
```

### Making Changes
1. Read relevant documentation in [FEATURES.md](FEATURES.md)
2. Check [ACHIEVEMENT_ENGINE_NEXT_MOVES.md](ACHIEVEMENT_ENGINE_NEXT_MOVES.md) for priorities
3. Run tests before and after changes (⌘U)
4. Update documentation if adding features
5. Commit with descriptive messages

### Code Organization
```
GraphEditor/
├── GraphEditorWatch/          # Watch app (UI, ViewModels)
│   ├── ViewModels/           # GraphViewModel extensions
│   └── Views/                # SwiftUI views
├── GraphEditorShared/         # Shared library (submodule)
│   ├── Sources/              # Core graph engine
│   │   └── HomeEconomics/   # Domain-specific nodes
│   └── Tests/                # Unit tests
└── GraphEditorWatchTests/     # Watch app tests
```

## Known Issues

### Immediate
- Attempt nodes stack at (0,0) - need positioning
- No achievement dashboard UI yet
- Milestone celebrations not implemented
- Some menu actions incomplete

### Technical Debt
- Node type system has code duplication (~64KB in menus)
- Refactor proposed in `docs/archive/planning/NODE_TYPE_REFACTOR_PLAN.md`
- Console logging reduced but could be further optimized

See [FEATURES.md](FEATURES.md#known-issues--technical-debt) for complete list.

## Contributing

This is a personal project, but feedback and suggestions are welcome via:
- GitHub Issues: https://github.com/anthropics/claude-code/issues
- Architecture discussions in pull requests

## License

[Specify license here]

## Contact

[Your contact information]

---

**Last Updated**: 2026-02-25
**Project Started**: Early 2026
**Primary Goal**: Transform life goals into visual progression systems on Apple Watch
