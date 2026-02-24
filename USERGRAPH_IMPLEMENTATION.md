# User Graph Feature Implementation

## Overview
The User Graph feature provides a unified canvas that displays all user graphs as nodes, enabling organization, cross-graph relationships, and quick access to pinned nodes.

## Implementation Status: Phases 1-4 Complete ✅

### Phase 1: Foundation (GraphEditorShared)
**Status**: ✅ Complete

**Created Files**:
- `GraphEditorShared/Sources/GraphEditorShared/HomeEconomics/GraphNode.swift`
  - New node type representing sub-graphs on the user graph canvas
  - Properties: graphName, displayName, nodeCount, lastModified, thumbnailColor
  - Conforms to NodeProtocol with Codable support

- `GraphEditorShared/Sources/GraphEditorShared/HomeEconomics/GraphNodeDescriptor.swift`
  - Type descriptor for GraphNode configuration
  - Physics: mass=2.0, visualMultiplier=1.5
  - Icon: square.stack.3d.up
  - Menu sections: Open, Rename, Set Color, Delete

- `GraphEditorShared/Sources/GraphEditorShared/Rendering/GraphNodeRenderer.swift`
  - Custom renderer with rounded rectangle shape (distinct from circular nodes)
  - Displays stack icon and node label
  - Selection glow effect

- `GraphEditorShared/Sources/GraphEditorShared/UserGraphState.swift`
  - Persistent state model for user graph
  - Stores: graphPositions, userEdges, pinnedNodes, viewState, graphOrder
  - Includes UserGraphEdge and PinnedNodeReference types

**Modified Files**:
- `GraphEditorShared/Sources/GraphEditorShared/NodeProtocol.swift`
  - Registered GraphNode in AnyNode encode/decode (cases added at lines ~322 and ~383)

- `GraphEditorShared/Sources/GraphEditorShared/Protocols.swift`
  - Extended GraphStorage protocol with:
    - `saveUserGraphState(_ state: UserGraphState) async throws`
    - `loadUserGraphState() async throws -> UserGraphState?`

- `GraphEditorShared/Sources/GraphEditorShared/PersistenceManager.swift`
  - Implemented UserGraphState storage at `Documents/graphs/_userGraphState.json`
  - Save/load methods with error handling and logging

- `GraphEditorShared/Sources/GraphEditorShared/MockGraphStorage.swift`
  - Added test implementation for UserGraphState storage
  - In-memory storage for unit tests

---

### Phase 2: User Graph Canvas (GraphEditorWatch)
**Status**: ✅ Complete

**Created Files**:
- `GraphEditorWatch/ViewModels/UserGraphViewModel.swift`
  - Main view model for user graph canvas
  - Key methods:
    - `syncFromStorage()` - Rebuilds GraphNodes from available graphs
    - `saveState()` - Persists positions/edges/pins
    - `updateGraphNodePosition()` - Updates and saves node positions
    - `addGraphNode()` / `removeGraphNode()` - Graph management
  - Auto-layout: Radial positioning for new GraphNodes

- `GraphEditorWatch/Views/UserGraphView.swift`
  - Main canvas view displaying GraphNodes
  - Components: UserGraphView, GraphNodeView, UserGraphMenuView
  - Features:
    - Tap GraphNode → navigate to sub-graph
    - New graph creation sheet
    - Menu with New Graph, Refresh options

**Modified Files**:
- `GraphEditorWatch/ViewModels/GraphViewModel.swift`
  - Added `@Published public var isInSubGraph: Bool = false` (line 42)
  - Tracks whether user is viewing a sub-graph vs. user graph

- `GraphEditorWatch/ViewModels/GraphViewModel+MultiGraph.swift`
  - Modified `loadGraph()` to set `isInSubGraph = true` (line 41)
  - Added `returnToUserGraph()` method (lines 63-67)

- `GraphEditorWatch/Views/GraphsMenuView.swift`
  - Added context-aware "Back to Home" button (lines 28-40)
  - Only visible when `isInSubGraph == true`
  - Calls `viewModel.returnToUserGraph()`

---

### Phase 3: Interactions
**Status**: ✅ Complete

**Features Implemented**:

1. **Drag Positioning for GraphNodes**
   - Added drag gesture handling to UserGraphView
   - GraphNodes can be dragged to reposition on canvas
   - Positions automatically saved to storage on drag end
   - Threshold-based detection (5.0pt) to distinguish taps from drags
   - Proper coordinate transformation between screen and model space

2. **User Edges Between Graphs**
   - Created `UserEdgesView` component
   - Renders blue lines connecting GraphNodes
   - Optional edge labels displayed at midpoint
   - Canvas rendering with proper zoom scaling
   - "Create Edge" menu option with graph pickers

3. **Pan and Zoom Support**
   - Canvas panning when dragging empty space
   - Zoom scale support (infrastructure ready)
   - Coordinate transformations handle all interactions

4. **Sync on Graph Changes**
   - New graph creation → adds GraphNode automatically
   - Graph deletion → removes GraphNode + cleans up pins/edges
   - All changes persist via UserGraphViewModel

**Modified Files**:
- `GraphEditorWatch/Views/UserGraphView.swift`
  - Added drag gesture handlers: `handleDragChanged()`, `handleDragEnded()`
  - Added `UserEdgesView` component for edge rendering
  - Helper methods: `graphNodeAt()`, `screenToModel()`
  - Enhanced `UserGraphMenuView` with edge creation and graph deletion

---

### Phase 4: Pinning
**Status**: ✅ Complete

**Created Files**:
- `GraphEditorWatch/ViewModels/GraphViewModel+Pinning.swift`
  - `pinNodeToUserGraph(nodeID:)` - Pins a node to user graph
  - `unpinNodeFromUserGraph(pinID:)` - Removes a pin
  - Stores pins in UserGraphState via storage layer
  - Caches node label and type for display
  - Prevents duplicate pins

**Features Implemented**:

1. **Pin Controls in Node Menus**
   - Added "Pin to Home" button to PersonNodeMenuView (line 62-67)
   - Added "Pin to Home" button to MealNodeMenuView (line 143-148)
   - Context-aware: only visible when `isInSubGraph = true`
   - Yellow pin icon for visual consistency

2. **Pinned Node Rendering**
   - Created `PinnedNodesView` component
   - Created `PinnedNodePreview` with:
     - Yellow pin icon at top
     - Blue circular node preview
     - Cached label below
     - Scales with zoom level
   - Renders on UserGraphView canvas

3. **Navigation from Pinned Nodes**
   - Tap pinned node → loads source graph + selects node
   - Implemented in `handlePinnedNodeTap()` (lines 87-96)
   - Provides instant navigation to exact node

4. **Pin Management UI**
   - "Manage Pins" menu option (only visible when pins exist)
   - Management sheet showing:
     - List of all pinned nodes
     - Source graph name for each pin
     - Delete button for each pin
   - Calls `userGraphViewModel.unpinNode()` to remove

**Modified Files**:
- `GraphEditorWatch/Views/PersonNodeMenuView.swift`
  - Added pin control and `pinToUserGraph()` method

- `GraphEditorWatch/Views/MealNodeMenuView.swift`
  - Added pin control and `pinToUserGraph()` method

- `GraphEditorWatch/Views/UserGraphView.swift`
  - Added `PinnedNodesView`, `PinnedNodePreview` components
  - Added pin management UI

---

## Testing

**Created Files**:
- `GraphEditorWatchTests/UserGraphTests.swift`
  - Comprehensive test suite covering all 4 phases
  - Tests include:
    - GraphNode creation and Codable conformance
    - UserGraphState persistence
    - UserGraphViewModel initialization and sync
    - Graph node addition/removal
    - Position updates
    - User edge creation/removal
    - Pin/unpin operations
    - Integration workflows
    - State recovery after reset

---

## Architecture Decisions

### Node Identity
- **Separate instances** - Each graph owns its nodes completely
- No shared node references between graphs
- Cloning creates full independent copies

### Persistence
- **Hybrid approach**
  - Auto-generated structure (GraphNodes from listGraphNames())
  - Persistent user preferences (positions, edges, pins)
- UserGraphState stored at `Documents/graphs/_userGraphState.json`

### Cross-Graph Features
- **View-only aggregation** - Read-only summaries
- User edges are visual relationships only
- No data coupling between graphs

### Default View
- User Graph is the app launch screen
- Context-aware "Back to Home" button in sub-graphs
- Navigation tracked via `isInSubGraph` flag

---

## Key Files Summary

### Core Data Models
- `GraphNode.swift` - Node type for sub-graphs
- `UserGraphState.swift` - Persistent state (positions, edges, pins)
- `GraphNodeDescriptor.swift` - Type descriptor for GraphNode
- `GraphNodeRenderer.swift` - Custom rendering

### View Models
- `UserGraphViewModel.swift` - User graph canvas state management
- `GraphViewModel+MultiGraph.swift` - Graph switching and navigation
- `GraphViewModel+Pinning.swift` - Pin/unpin operations

### Views
- `UserGraphView.swift` - Main canvas view (includes UserEdgesView, PinnedNodesView)
- `PersonNodeMenuView.swift` - PersonNode menu with pin control
- `MealNodeMenuView.swift` - MealNode menu with pin control
- `GraphsMenuView.swift` - "Back to Home" button

### Storage
- `PersistenceManager.swift` - UserGraphState file I/O
- `MockGraphStorage.swift` - Test implementation
- `Protocols.swift` - GraphStorage protocol extensions

---

## Next Steps (Phase 5: Aggregation - Pending)

### Planned Features:
1. **Cross-Graph Query API**
   - `findAllPersonNodes()` - Search across all graphs
   - `findAllMealNodes()` - Aggregate meal data
   - Implement in `GraphModel+Aggregation.swift`

2. **AllPeopleView**
   - List all people across graphs
   - Tap to navigate to source graph + node
   - Group by graph or alphabetically

3. **AllMealsView**
   - Aggregate meal information
   - Show upcoming taco nights
   - Navigate to source

4. **Search Functionality**
   - Global search across all graphs
   - Filter by node type
   - Quick navigation to results

5. **Menu Integration**
   - Add "All People" to user graph menu
   - Add "All Meals" option
   - Add "Search" option

---

## Usage Example

### Creating and Organizing Graphs
1. Launch app → User Graph canvas appears
2. Tap menu → "New Graph"
3. Create multiple graphs (e.g., "Taco Night 1", "Taco Night 2")
4. Drag GraphNodes to organize layout
5. Create edges between related graphs

### Pinning Important Nodes
1. Tap GraphNode → navigate to sub-graph
2. Tap a PersonNode or MealNode
3. Menu → "Pin to Home"
4. Return to User Graph → see pinned node
5. Tap pinned node → jump back to source

### Managing the User Graph
1. Tap menu → "Create Edge" to link graphs
2. Tap menu → "Manage Pins" to remove pins
3. Tap menu → "Delete Graph" to remove a graph
4. All changes automatically persist

---

## Performance Characteristics

- **Scale**: Designed for 10-20 graphs without cache
- **Auto-layout**: Radial positioning (configurable)
- **Persistence**: Async save with debouncing
- **Memory**: Lazy loading of graph previews
- **Rendering**: Canvas-based for efficient edge drawing

---

## Build Status

✅ All phases build successfully
✅ No compilation errors
✅ Only SwiftLint warnings (unrelated to this feature)
✅ Comprehensive test coverage

---

## Documentation

This implementation follows the detailed plan from:
`/Users/handcart/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/plans/composed-cooking-turtle.md`

All design decisions, architectural choices, and critical files are documented in the plan.
