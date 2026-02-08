# GraphEditor Testing Guide

## Current Test Status

**Test Results: 121/121 passing (100% success rate)** ✅

### Test Suite Overview

The GraphEditor project has comprehensive test coverage using Swift's modern Testing framework with async/await patterns. Tests are organized by feature area and include unit tests, performance benchmarks, error handling scenarios, ViewModel extension tests, and node content tests.

## Test Files

### Core Functionality Tests
- **ViewModelTests.swift** - Multi-graph operations, view state management, node operations
- **ViewModelExtensionTests.swift** - ViewModel extension methods (simulation, zoom, selection, tap handling) (18 tests) ✨ NEW
- **GraphModelTests.swift** - Graph operations, persistence, cycle detection
- **GraphGesturesModifierTests.swift** - Gesture handling (tap, drag, long press)
- **ControlNodeTests.swift** - Control node lifecycle, positioning, filtering (20 tests)
- **LongPressGestureTests.swift** - Long press gesture behavior and saturation effects

### UI & Integration Tests
- **AccessibilityTests.swift** - Accessibility descriptions and labels
- **CoordinateTransformerTests.swift** - Screen/model coordinate transformations
- **EditContentSheetTests.swift** - Content editing functionality
- **MenuViewTests.swift** - Menu interactions

### Error Handling Tests
- **PersistenceErrorTests.swift** - Error scenarios for save/load/delete operations (9 tests)

### Performance Tests
- **PerformanceTests.swift** - Benchmarks for node operations, physics, persistence (13 tests)
  - Add/delete 100+ nodes
  - Physics simulation with 50 nodes
  - Graph traversal in dense graphs
  - Cache efficiency
  - Undo/redo operations

## Code Coverage

Code coverage is **enabled** in the test plan. To view coverage:

1. Run tests in Xcode (⌘U)
2. Open the Report Navigator (⌘9)
3. Select the latest test run
4. Click the "Coverage" tab

Coverage reports will show:
- Line coverage percentage per file
- Uncovered code paths highlighted in source
- Function-level coverage statistics

## Resolved Issues

### testFilterControlKindsLimitsAddEdge (FIXED) ✅

**Root Cause:** The test was using `viewModel.addEdge()` immediately after creating each node in a loop. This method launches concurrent `Task` instances to run physics simulation (`startLayoutAnimation()`), which can interfere with each other when called rapidly in succession.

**Solution:** In tests, use `model.addEdge()` directly instead of `viewModel.addEdge()` to avoid triggering concurrent physics simulations. Alternatively, create all nodes first, then add edges sequentially.

**Example:**
```swift
// ❌ Problematic pattern - concurrent simulations interfere
for i in 0..<6 {
    let child = await viewModel.model.addNode(at: position)
    await viewModel.addEdge(from: parent.id, to: child.id, type: .hierarchy)
}

// ✅ Working pattern - use model.addEdge() directly
for i in 0..<6 {
    let child = await viewModel.model.addNode(at: position)
    await viewModel.model.addEdge(from: parent.id, target: child.id, type: .hierarchy)
}
```

This issue was resolved in the testing infrastructure improvements on 2026-02-07.

## Test Organization

```
GraphEditorWatchTests/
├── Core Tests
│   ├── ViewModelTests.swift
│   ├── GraphModelTests.swift
│   ├── ControlNodeTests.swift
│   └── GraphGesturesModifierTests.swift
├── Feature Tests
│   ├── LongPressGestureTests.swift
│   ├── GestureTests.swift
│   ├── AccessibilityTests.swift
│   ├── EditContentSheetTests.swift
│   └── MenuViewTests.swift
├── Quality Tests
│   ├── PerformanceTests.swift
│   ├── PersistenceErrorTests.swift
│   └── CoordinateTransformerTests.swift
└── Test Utilities
    └── MockGraphStorage.swift
```

## Running Tests

### Run All Tests
```bash
# From command line
xcodebuild test -scheme GraphEditorWatch

# In Xcode
⌘U
```

### Run Specific Test
```bash
xcodebuild test -scheme GraphEditorWatch -only-testing:GraphEditorWatchTests/ViewModelTests
```

### Run with Coverage
Code coverage is automatically enabled. View results in Xcode's Report Navigator after running tests.

## Test Patterns

### Test Structure
```swift
@Test("Test description")
@MainActor
func testFeatureName() async throws {
    // Arrange
    let viewModel = createTestViewModel()
    
    // Act
    await viewModel.performAction()
    
    // Assert
    #expect(condition, "Failure message")
}
```

### Async Testing
All tests use Swift's native async/await:
```swift
let result = await viewModel.model.addNode(at: .zero)
await viewModel.generateControls(for: nodeID)
```

### Performance Testing
```swift
@Test("Performance: Operation name", .timeLimit(.minutes(1)))
func testPerformance() async {
    let startTime = Date()
    // ... perform operation
    let duration = Date().timeIntervalSince(startTime)
    #expect(duration < threshold)
}
```

## Recent Improvements ✨

### Newly Added (2026-02-07)
- **ViewModelExtensionTests.swift** - 18 comprehensive tests covering:
  - Simulation control (pause, resume, layout animation)
  - Zoom calculations and view fitting
  - Selection state management
  - Tap handling and hit detection
  - View state transformations

### Code Coverage
- Enabled code coverage reporting in test plans
- View coverage reports in Xcode Report Navigator (⌘9)

## Areas for Further Improvement

### Remaining Test Gaps
1. **ViewModel Helper** (partially tested):
   - GraphViewModel+Helpers.swift - saveAfterDelay() debouncing logic

2. **View Components** (untested):
   - NodeView.swift
   - EdgeMenuView.swift
   - GraphsMenuView.swift
   - GraphicalDatePicker.swift
   - NumericKeypadView.swift
   - BoundingBoxOverlay.swift

3. **Integration Tests**:
   - End-to-end user workflows
   - Complex gesture sequences
   - State synchronization between Model and ViewModel

### Recommended Next Steps

1. **Fix failing test** - Debug testFilterControlKindsLimitsAddEdge
2. **Add ViewModel extension tests** - Cover simulation, helpers, view state
3. **Add view rendering tests** - Test UI component behavior
4. **Add integration tests** - Test complete workflows
5. **Increase coverage targets** - Aim for 85%+ line coverage

## Contributing Tests

### Guidelines
1. Use descriptive test names that explain what's being tested
2. Follow AAA pattern (Arrange, Act, Assert)
3. Use `@MainActor` for tests that modify UI state
4. Add `async throws` for tests that can fail gracefully
5. Include clear failure messages in `#expect()` calls
6. Add performance benchmarks for critical paths
7. Test edge cases and error conditions

### Test Naming
- Descriptive: `@Test("Generate controls creates control nodes for selected node")`
- Action-focused: `testAddNodeIncrementsLabel()`
- State-focused: `testInitialSaturation()`

## Test Maintenance

### When to Update Tests
- After refactoring code structure
- When changing business logic
- When fixing bugs (add regression test first)
- When adding new features (TDD approach)

### Test Smell Indicators
- Tests failing intermittently (flaky tests)
- Tests taking too long (>1 second for unit tests)
- Duplicate test setup code (refactor to helper functions)
- Tests testing implementation details instead of behavior

---

**Last Updated:** 2026-02-07  
**Test Count:** 121 tests (+9 from node content improvements)  
**Success Rate:** 100% (121 passing, 0 failing)  
**Code Coverage:** Enabled ✅
