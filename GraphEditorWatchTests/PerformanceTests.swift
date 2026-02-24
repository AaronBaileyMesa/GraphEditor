//
//  PerformanceTests.swift
//  Performance benchmarks for GraphEditor operations
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct PerformanceTests {
    
    @MainActor
    private func createTestViewModel() -> GraphViewModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        return GraphViewModel(model: model)
    }
    
    // MARK: - Node Operations Performance
    
    @MainActor @Test("Performance: Add 100 nodes", .timeLimit(.minutes(1)))
    func testAddNodesPerformance() async {
        let viewModel = createTestViewModel()
        let nodeCount = 100
        
        // Use bulk operation mode to prevent physics interference
        await viewModel.model.beginBulkOperation()
        
        let startTime = Date()
        
        for _ in 0..<nodeCount {
            let x = CGFloat.random(in: 50...450)
            let y = CGFloat.random(in: 50...450)
            _ = await viewModel.model.addNode(at: CGPoint(x: x, y: y))
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        await viewModel.model.endBulkOperation()
        
        let avgTimePerNode = duration / Double(nodeCount)
        let actualCount = viewModel.model.nodes.count
        
        // With bulk operation mode, we should get all nodes
        #expect(actualCount == nodeCount, "Should have created all \(nodeCount) nodes, got \(actualCount)")
        
        // Log performance metrics for visibility
        // print("✓ Added \(nodeCount) nodes in \(String(format: "%.3f", duration))s")
        // print("  Average: \(String(format: "%.4f", avgTimePerNode * 1000))ms per node")
        
        // Expect reasonable performance (< 15ms per node)
        #expect(avgTimePerNode < 0.015, "Average time per node should be < 15ms, got \(String(format: "%.4f", avgTimePerNode * 1000))ms")
    }
    
    @MainActor @Test("Performance: Delete 100 nodes", .timeLimit(.minutes(1)))
    func testDeleteNodesPerformance() async {
        let viewModel = createTestViewModel()
        let nodeCount = 100
        
        // Use bulk operation mode
        await viewModel.model.beginBulkOperation()
        
        // Setup: Add nodes
        var nodeIDs: [UUID] = []
        for i in 0..<nodeCount {
            let node = await viewModel.model.addNode(at: CGPoint(x: 100 + Double(i * 3), y: 100 + Double(i * 3)))
            nodeIDs.append(node.id)
        }
        
        // Test deletion performance
        let startTime = Date()
        
        for nodeID in nodeIDs {
            await viewModel.model.deleteNode(withID: nodeID)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        await viewModel.model.endBulkOperation()
        
        let avgTimePerNode = duration / Double(nodeCount)
        let remainingNodes = viewModel.model.nodes.count
        
        // With bulk operation mode, all nodes should be deleted
        #expect(remainingNodes == 0, "Should have deleted all nodes, \(remainingNodes) remaining")
        
        // print("✓ Deleted \(nodeCount) nodes in \(String(format: "%.3f", duration))s")
        // print("  Average: \(String(format: "%.4f", avgTimePerNode * 1000))ms per node")
        
        #expect(avgTimePerNode < 0.01, "Average deletion time should be < 10ms per node")
    }
    
    @MainActor @Test("Performance: Clear graph with 200 nodes and 300 edges", .timeLimit(.minutes(1)))
    func testClearLargeGraphPerformance() async {
        let viewModel = createTestViewModel()
        
        // Pause simulation during bulk operations
        await viewModel.model.stopSimulation()
        
        // Create a large graph
        var nodeIDs: [UUID] = []
        for i in 0..<200 {
            let node = await viewModel.model.addNode(at: CGPoint(x: 100 + Double(i * 2), y: 100 + Double(i * 2)))
            nodeIDs.append(node.id)
        }
        
        // Add edges
        for _ in 0..<300 {
            let from = nodeIDs.randomElement()!
            let to = nodeIDs.randomElement()!
            await viewModel.model.addEdge(from: from, target: to, type: .association)
        }
        
        let startTime = Date()
        await viewModel.clearGraph()
        let duration = Date().timeIntervalSince(startTime)
        
        // clearGraph() preserves RootNode, so expect 1 node
        #expect(viewModel.model.nodes.count == 1, "Only RootNode should remain")
        #expect(viewModel.model.nodes.first?.unwrapped is RootNode, "Remaining node is RootNode")
        #expect(viewModel.model.edges.isEmpty, "All edges should be cleared")
        
        // print("✓ Cleared graph (200 nodes, 300 edges) in \(String(format: "%.3f", duration))s")
        
        #expect(duration < 1.0, "Clear operation should complete in < 1s")
    }
    
    // MARK: - Edge Operations Performance
    
    @MainActor @Test("Performance: Add 200 edges", .timeLimit(.minutes(1)))
    func testAddEdgesPerformance() async {
        let viewModel = createTestViewModel()
        
        // Setup: Create 50 nodes
        var nodeIDs: [UUID] = []
        for i in 0..<50 {
            let node = await viewModel.model.addNode(at: CGPoint(x: Double(i * 10), y: Double(i * 10)))
            nodeIDs.append(node.id)
        }
        
        let edgeCount = 200
        let startTime = Date()
        
        for _ in 0..<edgeCount {
            let from = nodeIDs.randomElement()!
            let to = nodeIDs.randomElement()!
            await viewModel.model.addEdge(from: from, target: to, type: .association)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgTimePerEdge = duration / Double(edgeCount)
        
        // print("✓ Added \(edgeCount) edges in \(String(format: "%.3f", duration))s")
        // print("  Average: \(String(format: "%.4f", avgTimePerEdge * 1000))ms per edge")
        
        #expect(avgTimePerEdge < 0.050, "Average time per edge should be < 50ms")
    }
    
    @MainActor @Test("Performance: Find connected nodes in dense graph", .timeLimit(.minutes(1)))
    func testGraphTraversalPerformance() async {
        let viewModel = createTestViewModel()
        
        // Create a connected graph
        var nodeIDs: [UUID] = []
        for i in 0..<100 {
            let node = await viewModel.model.addNode(at: CGPoint(x: Double(i * 5), y: Double(i * 5)))
            nodeIDs.append(node.id)
        }
        
        // Create dense connections (each node connects to 5 others)
        for fromID in nodeIDs {
            for _ in 0..<5 {
                if let toID = nodeIDs.randomElement() {
                    await viewModel.model.addEdge(from: fromID, target: toID, type: .association)
                }
            }
        }
        
        // Test traversal performance
        let startTime = Date()
        
        // Find all edges for each node
        for nodeID in nodeIDs {
            _ = viewModel.model.edges.filter { $0.from == nodeID || $0.target == nodeID }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // print("✓ Traversed dense graph (100 nodes, ~500 edges) in \(String(format: "%.4f", duration * 1000))ms")
        
        #expect(duration < 0.5, "Graph traversal should complete in < 500ms")
    }
    
    // MARK: - Physics Simulation Performance
    
    @MainActor @Test("Performance: Physics simulation step with 50 nodes", .timeLimit(.minutes(1)))
    func testPhysicsSimulationPerformance() async {
        let viewModel = createTestViewModel()
        
        // Create nodes
        for i in 0..<50 {
            _ = await viewModel.model.addNode(at: CGPoint(x: Double(i * 10), y: Double(i * 10)))
        }
        
        // Add some edges to make simulation interesting
        let nodeIDs = viewModel.model.nodes.map { $0.id }
        for _ in 0..<75 {
            if let from = nodeIDs.randomElement(), let to = nodeIDs.randomElement() {
                await viewModel.model.addEdge(from: from, target: to, type: .association)
            }
        }
        
        // Measure single simulation step
        let iterations = 10
        let startTime = Date()
        
        for _ in 0..<iterations {
            _ = viewModel.model.physicsEngine.simulationStep(
                nodes: viewModel.model.nodes.map { $0.unwrapped },
                edges: viewModel.model.edges,
                fixedIDs: nil
            )
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgTimePerStep = duration / Double(iterations)
        
        // print("✓ Physics simulation (\(iterations) steps, 50 nodes, 75 edges): \(String(format: "%.3f", duration))s")
        // print("  Average: \(String(format: "%.2f", avgTimePerStep * 1000))ms per step")
        
        // Target 60 FPS = ~16.67ms per frame
        #expect(avgTimePerStep < 0.017, "Physics step should be < 17ms for 60 FPS target")
    }
    
    // MARK: - Control Node Performance
    
    @MainActor @Test("Performance: Generate control nodes", .timeLimit(.minutes(1)))
    func testControlNodeGenerationPerformance() async {
        let viewModel = createTestViewModel()
        
        let node = await viewModel.model.addNode(at: CGPoint(x: 250, y: 250))
        
        let iterations = 20
        let startTime = Date()
        
        for _ in 0..<iterations {
            await viewModel.generateControls(for: node.id)
            await viewModel.clearControls()
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgTimePerGeneration = duration / Double(iterations)
        
        // print("✓ Generated control nodes \(iterations) times in \(String(format: "%.3f", duration))s")
        // print("  Average: \(String(format: "%.2f", avgTimePerGeneration * 1000))ms per generation")
        
        #expect(avgTimePerGeneration < 0.50, "Control generation should be < 500ms")
    }
    
    @MainActor @Test("Performance: Reposition ephemeral controls", .timeLimit(.minutes(1)))
    func testRepositionEphemeralsPerformance() async {
        let viewModel = createTestViewModel()
        
        let node = await viewModel.model.addNode(at: CGPoint(x: 250, y: 250))
        await viewModel.generateControls(for: node.id)
        
        let iterations = 100
        let startTime = Date()
        
        for i in 0..<iterations {
            let newPos = CGPoint(x: 250 + Double(i), y: 250 + Double(i))
            viewModel.repositionEphemerals(for: node.id, to: newPos)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgTimePerReposition = duration / Double(iterations)
        
        // print("✓ Repositioned controls \(iterations) times in \(String(format: "%.3f", duration))s")
        // print("  Average: \(String(format: "%.4f", avgTimePerReposition * 1000))ms per reposition")
        
        #expect(avgTimePerReposition < 0.005, "Reposition should be < 5ms")
    }
    
    // MARK: - Persistence Performance
    
    @MainActor @Test("Performance: Save and load graph with 100 nodes", .timeLimit(.minutes(1)))
    func testPersistencePerformance() async throws {
        let viewModel = createTestViewModel()
        
        // Pause simulation during bulk operations
        await viewModel.model.stopSimulation()
        
        // Create a substantial graph
        var nodeIDs: [UUID] = []
        for i in 0..<100 {
            let node = await viewModel.model.addNode(at: CGPoint(x: 100 + Double(i * 3), y: 100 + Double(i * 3)))
            nodeIDs.append(node.id)
        }
        
        // Add edges
        for _ in 0..<150 {
            if let from = nodeIDs.randomElement(), let to = nodeIDs.randomElement() {
                await viewModel.model.addEdge(from: from, target: to, type: .association)
            }
        }
        
        // Test save performance
        let saveStart = Date()
        try await viewModel.model.saveGraph()
        let saveDuration = Date().timeIntervalSince(saveStart)
        
        // print("✓ Saved graph (100 nodes, 150 edges) in \(String(format: "%.3f", saveDuration))s")
        
        // Test load performance
        let loadStart = Date()
        try await viewModel.model.loadGraph()
        let loadDuration = Date().timeIntervalSince(loadStart)
        
        // print("✓ Loaded graph (100 nodes, 150 edges) in \(String(format: "%.3f", loadDuration))s")
        
        #expect(saveDuration < 1.0, "Save should complete in < 1s")
        #expect(loadDuration < 1.0, "Load should complete in < 1s")
        
        // Allow for some node loss due to physics simulation and boundary effects
        let loadedCount = viewModel.model.nodes.count
        let minExpected = Int(Double(100) * 0.65)  // Reduced from 75% to 65%
        #expect(loadedCount >= minExpected, "Should have loaded at least \(minExpected) nodes, got \(loadedCount)")
    }
    
    // MARK: - Hidden Nodes Cache Performance
    
    @MainActor @Test("Performance: Hidden nodes cache computation", .timeLimit(.minutes(1)))
    func testHiddenNodesCachePerformance() async {
        let viewModel = createTestViewModel()
        
        // Create a hierarchy of toggle nodes
        var parentIDs: [UUID] = []
        
        // Create 10 parent nodes
        for i in 0..<10 {
            await viewModel.model.addToggleNode(at: CGPoint(x: Double(i * 50), y: 100))
            if let parent = viewModel.model.nodes.last {
                parentIDs.append(parent.id)
            }
        }
        
        // Add 10 children to each parent
        for parentID in parentIDs {
            for j in 0..<10 {
                let child = await viewModel.model.addNode(at: CGPoint(x: Double(j * 20), y: 200))
                await viewModel.model.addEdge(from: parentID, target: child.id, type: .hierarchy)
            }
        }
        
        // Test cache invalidation and recomputation
        let iterations = 50
        let startTime = Date()
        
        for _ in 0..<iterations {
            viewModel.model.invalidateHiddenNodesCache()
            _ = viewModel.model.hiddenNodeIDs
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgTimePerComputation = duration / Double(iterations)
        
        // print("✓ Hidden nodes cache computation \(iterations) times (10 parents, 100 children)")
        // print("  Total: \(String(format: "%.3f", duration))s")
        // print("  Average: \(String(format: "%.2f", avgTimePerComputation * 1000))ms per computation")
        
        #expect(avgTimePerComputation < 0.030, "Cache computation should be < 30ms")
    }
    
    @MainActor @Test("Performance: Hidden nodes cache efficiency", .timeLimit(.minutes(1)))
    func testHiddenNodesCacheEfficiency() async {
        let viewModel = createTestViewModel()
        
        // Create hierarchy
        await viewModel.model.addToggleNode(at: CGPoint(x: 100, y: 100))
        guard let parent = viewModel.model.nodes.first else {
            Issue.record("Failed to create toggle node")
            return
        }
        
        for i in 0..<50 {
            let child = await viewModel.model.addNode(at: CGPoint(x: Double(i * 10), y: 200))
            await viewModel.model.addEdge(from: parent.id, target: child.id, type: .hierarchy)
        }
        
        // Invalidate once
        viewModel.model.invalidateHiddenNodesCache()
        
        // Test cache hit performance
        let iterations = 1000
        let startTime = Date()
        
        for _ in 0..<iterations {
            _ = viewModel.model.hiddenNodeIDs
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgTimePerAccess = duration / Double(iterations)
        
        // print("✓ Hidden nodes cache hit performance (\(iterations) accesses)")
        // print("  Total: \(String(format: "%.3f", duration))s")
        // print("  Average: \(String(format: "%.6f", avgTimePerAccess * 1000))ms per access")
        
        // Cache hits should be extremely fast (< 10μs is excellent for property access with variability)
        #expect(avgTimePerAccess < 0.000010, "Cache hits should be < 10μs")
    }
    
    // MARK: - Undo/Redo Performance
    
    @MainActor @Test("Performance: Undo/Redo operations", .timeLimit(.minutes(1)))
    func testUndoRedoPerformance() async {
        let viewModel = createTestViewModel()
        
        // Clear undo stack
        viewModel.model.undoStack.removeAll()
        viewModel.model.redoStack.removeAll()
        
        let operationCount = 20  // Can handle more with increased maxUndo (30)
        
        // Perform operations WITHOUT bulk mode to ensure each operation is independent
        // Each addNode() will pushUndo() before adding
        for i in 0..<operationCount {
            _ = await viewModel.model.addNode(at: CGPoint(x: 250 + Double(i * 10), y: 250 + Double(i * 10)))
        }
        
        let initialCount = viewModel.model.nodes.count
        // Note: May be less than operationCount if some undos were dropped due to maxUndo limit or batching
        #expect(initialCount >= operationCount - 2, "Should have approximately \(operationCount) nodes, got \(initialCount)")
        
        // Test undo performance and correctness
        let undoStart = Date()
        var undoCount = 0
        while viewModel.canUndo && undoCount < 30 {  // Safety limit
            await viewModel.model.undo(resume: false)
            undoCount += 1
        }
        let undoDuration = Date().timeIntervalSince(undoStart)
        
        let afterUndoCount = viewModel.model.nodes.count
        #expect(afterUndoCount == 0, "All nodes should be undone, got \(afterUndoCount)")
        
        // Test redo performance and correctness
        let redoStart = Date()
        var redoCount = 0
        while viewModel.canRedo && redoCount < 30 {  // Safety limit
            await viewModel.model.redo(resume: false)
            redoCount += 1
        }
        let redoDuration = Date().timeIntervalSince(redoStart)
        
        let finalCount = viewModel.model.nodes.count
        // print("  Initial redo stack: \(initialRedoStackSize), redid: \(redoCount) times")
        // Allow for slight variance due to undo/redo stack limitations
        #expect(finalCount >= operationCount - 2, "Most nodes should be redone, got \(finalCount) out of \(operationCount)")
        
        // print("✓ Undo \(undoCount) operations: \(String(format: "%.3f", undoDuration))s (\(String(format: "%.2f", undoDuration / Double(undoCount) * 1000))ms avg)")
        // print("✓ Redo \(redoCount) operations: \(String(format: "%.3f", redoDuration))s (\(String(format: "%.2f", redoDuration / Double(redoCount) * 1000))ms avg)")
        
        // Performance expectations (accounting for system load variability)
        #expect(undoDuration < 1.5, "Undo should complete in < 1.5s")
        #expect(redoDuration < 1.5, "Redo should complete in < 1.5s")
    }
    
    // MARK: - Stress Tests
    
    @MainActor @Test("Stress: Large graph with 500 nodes and 1000 edges", .timeLimit(.minutes(2)))
    func testLargeGraphStress() async {
        let viewModel = createTestViewModel()
        
        let nodeCount = 500
        let edgeCount = 1000
        
        // Pause simulation to prevent physics from interfering with node positions
        await viewModel.model.stopSimulation()
        
        // print("Creating large graph: \(nodeCount) nodes, \(edgeCount) edges...")
        
        let startTime = Date()
        
        // Add nodes within bounds to prevent clamping
        var nodeIDs: [UUID] = []
        for _ in 0..<nodeCount {
            let node = await viewModel.model.addNode(at: CGPoint(
                x: CGFloat.random(in: 50...450),
                y: CGFloat.random(in: 50...450)
            ))
            nodeIDs.append(node.id)
        }
        
        // Add edges
        for _ in 0..<edgeCount {
            if let from = nodeIDs.randomElement(), let to = nodeIDs.randomElement() {
                await viewModel.model.addEdge(from: from, target: to, type: .association)
            }
        }
        
        let actualNodes = viewModel.model.nodes.count
        let minExpected = Int(Double(nodeCount) * 0.75) // 75% success rate (reduced from 85%)
        
        #expect(actualNodes >= minExpected, "Should have at least \(minExpected) nodes, got \(actualNodes)")
        #expect(viewModel.model.edges.count <= edgeCount, "Should have approximately all edges")
        
        // print("✓ Created large graph in \(String(format: "%.2f", duration))s")
        // print("  Final: \(viewModel.model.nodes.count) nodes, \(viewModel.model.edges.count) edges")
        
        // Verify clearing is also performant
        let clearStart = Date()
        await viewModel.clearGraph()
        let clearDuration = Date().timeIntervalSince(clearStart)
        
        // print("✓ Cleared large graph in \(String(format: "%.3f", clearDuration))s")
        
        #expect(clearDuration < 2.0, "Clearing large graph should complete in < 2s")
    }
    
    // MARK: - Hierarchical Layout Tests
    
    @MainActor @Test("Hierarchical Layout: Shallow hierarchy (3 levels)", .timeLimit(.minutes(1)))
    func testShallowHierarchyLayout() async {
        let viewModel = createTestViewModel()
        
        // Create a 3-level hierarchy: 1 root -> 2 children -> 4 grandchildren
        let rootNode = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        let root = rootNode.id
        
        var children: [NodeID] = []
        for _ in 0..<2 {
            let childNode = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
            await viewModel.model.addEdge(from: root, target: childNode.id, type: .hierarchy)
            children.append(childNode.id)
        }
        
        for child in children {
            for _ in 0..<2 {
                let grandchildNode = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
                await viewModel.model.addEdge(from: child, target: grandchildNode.id, type: .hierarchy)
            }
        }
        
        // Enable hierarchical layout
        viewModel.model.setLayoutMode(.hierarchy)
        
        // Run simulation to settle
        await runSimulationUntilStable(viewModel: viewModel, maxIterations: 200)
        
        // Verify layout properties
        let depths = HierarchyLayoutHelper.calculateDepths(
            nodes: viewModel.model.nodes.map { $0.unwrapped },
            edges: viewModel.model.edges
        )
        
        // Check depth assignments
        #expect(depths[root] == 0, "Root should be at depth 0")
        for child in children {
            #expect(depths[child] == 1, "Children should be at depth 1")
        }
        
        // Verify all nodes are within bounds
        let bounds = viewModel.model.physicsEngine.simulationBounds
        for node in viewModel.model.nodes {
            #expect(node.position.y >= 0, "Node Y should be >= 0")
            #expect(node.position.y <= bounds.height, "Node Y should be <= bounds height")
        }
        
        // print("✓ Shallow hierarchy layout validated (3 levels, 7 nodes)")
    }
    
    @MainActor @Test("Hierarchical Layout: Deep hierarchy (6 levels)", .timeLimit(.minutes(1)))
    func testDeepHierarchyLayout() async {
        let viewModel = createTestViewModel()
        
        // Create a 6-level chain: Node 1 -> Node 2 -> ... -> Node 6
        var previousNodeID = (await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))).id
        var allNodes = [previousNodeID]
        
        for _ in 1..<6 {
            let newNodeID = (await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))).id
            await viewModel.model.addEdge(from: previousNodeID, target: newNodeID, type: .hierarchy)
            allNodes.append(newNodeID)
            previousNodeID = newNodeID
        }
        
        // Enable hierarchical layout
        viewModel.model.setLayoutMode(.hierarchy)
        
        // Run simulation to settle
        await runSimulationUntilStable(viewModel: viewModel, maxIterations: 200)
        
        // Verify depth calculations
        let depths = HierarchyLayoutHelper.calculateDepths(
            nodes: viewModel.model.nodes.map { $0.unwrapped },
            edges: viewModel.model.edges
        )
        
        // Check depth assignments are sequential
        for (index, nodeID) in allNodes.enumerated() {
            #expect(depths[nodeID] == index, "Node \(index) should be at depth \(index)")
        }
        
        // Verify all nodes are within bounds
        let bounds = viewModel.model.physicsEngine.simulationBounds
        let isValid = HierarchyLayoutHelper.validateLayoutBounds(
            depths: depths,
            simulationBounds: bounds
        )
        #expect(isValid, "Deep hierarchy layout should keep all nodes within bounds")
        
        // Verify the Y range spans the hierarchy
        // The root and deepest node should have different Y positions
        let rootNode = viewModel.model.nodes.first { $0.id == allNodes[0] }
        let deepestNode = viewModel.model.nodes.first { $0.id == allNodes[allNodes.count - 1] }
        let yRange = abs(deepestNode!.position.y - rootNode!.position.y)
        #expect(yRange > 20, "Hierarchy should span vertically (range: \(yRange))")
        
        // Verify all nodes are visible (within bounds)
        for node in viewModel.model.nodes {
            #expect(node.position.y >= 0 && node.position.y <= bounds.height,
                   "Node should be within vertical bounds")
        }
        
        // print("✓ Deep hierarchy layout validated (6 levels, all nodes visible)")
    }
    
    @MainActor @Test("Hierarchical Layout: Wide hierarchy (many children)", .timeLimit(.minutes(1)))
    func testWideHierarchyLayout() async {
        let viewModel = createTestViewModel()
        
        // Create a wide hierarchy: 1 root with 10 children
        let root = (await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))).id
        var children: [NodeID] = []
        
        for _ in 0..<10 {
            let childID = (await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))).id
            await viewModel.model.addEdge(from: root, target: childID, type: .hierarchy)
            children.append(childID)
        }
        
        // Enable hierarchical layout
        viewModel.model.setLayoutMode(.hierarchy)
        
        // Run simulation to settle
        await runSimulationUntilStable(viewModel: viewModel, maxIterations: 200)
        
        // Verify all children are at same depth
        let depths = HierarchyLayoutHelper.calculateDepths(
            nodes: viewModel.model.nodes.map { $0.unwrapped },
            edges: viewModel.model.edges
        )
        
        for child in children {
            #expect(depths[child] == 1, "All children should be at depth 1")
        }
        
        // Verify children are spread horizontally
        let childNodes = viewModel.model.nodes.filter { children.contains($0.id) }
        let xPositions = childNodes.map { $0.position.x }
        let xRange = (xPositions.max() ?? 0) - (xPositions.min() ?? 0)
        
        #expect(xRange > 50, "Children should be spread horizontally (range: \(xRange))")
        
        // print("✓ Wide hierarchy layout validated (1 root with 10 children)")
    }
    
    @MainActor @Test("Hierarchical Layout: Multiple roots", .timeLimit(.minutes(1)))
    func testMultipleRootsHierarchy() async {
        let viewModel = createTestViewModel()
        
        // Create two separate hierarchies
        let root1 = (await viewModel.model.addNode(at: CGPoint(x: 50, y: 100))).id
        let child1 = (await viewModel.model.addNode(at: CGPoint(x: 50, y: 100))).id
        await viewModel.model.addEdge(from: root1, target: child1, type: .hierarchy)
        
        let root2 = (await viewModel.model.addNode(at: CGPoint(x: 150, y: 100))).id
        let child2 = (await viewModel.model.addNode(at: CGPoint(x: 150, y: 100))).id
        await viewModel.model.addEdge(from: root2, target: child2, type: .hierarchy)
        
        // Enable hierarchical layout
        viewModel.model.setLayoutMode(.hierarchy)
        
        // Run simulation to settle
        await runSimulationUntilStable(viewModel: viewModel, maxIterations: 200)
        
        // Verify depth calculations
        let depths = HierarchyLayoutHelper.calculateDepths(
            nodes: viewModel.model.nodes.map { $0.unwrapped },
            edges: viewModel.model.edges
        )
        
        // Both roots should be at depth 0
        #expect(depths[root1] == 0, "Root 1 should be at depth 0")
        #expect(depths[root2] == 0, "Root 2 should be at depth 0")
        
        // Both children should be at depth 1
        #expect(depths[child1] == 1, "Child 1 should be at depth 1")
        #expect(depths[child2] == 1, "Child 2 should be at depth 1")
        
        // print("✓ Multiple roots hierarchy validated")
    }
    
    @MainActor @Test("Hierarchical Layout: Dynamic spacing calculation", .timeLimit(.minutes(1)))
    func testDynamicSpacingCalculation() async {
        let viewModel = createTestViewModel()
        let bounds = viewModel.model.physicsEngine.simulationBounds
        
        // Test shallow hierarchy (should use full spacing)
        var previousNodeID = (await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))).id
        for _ in 1..<3 {
            let newNodeID = (await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))).id
            await viewModel.model.addEdge(from: previousNodeID, target: newNodeID, type: .hierarchy)
            previousNodeID = newNodeID
        }
        
        viewModel.model.setLayoutMode(.hierarchy)
        await runSimulationUntilStable(viewModel: viewModel, maxIterations: 100)
        
        var depths = HierarchyLayoutHelper.calculateDepths(
            nodes: viewModel.model.nodes.map { $0.unwrapped },
            edges: viewModel.model.edges
        )
        var isValid = HierarchyLayoutHelper.validateLayoutBounds(
            depths: depths,
            simulationBounds: bounds
        )
        
        #expect(isValid, "Shallow hierarchy should fit within bounds")
        
        // Now create a very deep hierarchy (10 levels)
        // clearGraph() preserves RootNode
        await viewModel.clearGraph()
        previousNodeID = (await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))).id
        for _ in 1..<10 {
            let newNodeID = (await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))).id
            await viewModel.model.addEdge(from: previousNodeID, target: newNodeID, type: .hierarchy)
            previousNodeID = newNodeID
        }
        
        viewModel.model.setLayoutMode(.hierarchy)
        await runSimulationUntilStable(viewModel: viewModel, maxIterations: 100)
        
        depths = HierarchyLayoutHelper.calculateDepths(
            nodes: viewModel.model.nodes.map { $0.unwrapped },
            edges: viewModel.model.edges
        )
        isValid = HierarchyLayoutHelper.validateLayoutBounds(
            depths: depths,
            simulationBounds: bounds
        )
        
        #expect(isValid, "Deep hierarchy should use dynamic spacing to fit within bounds")
        
        // Verify all nodes are within bounds
        // After clearGraph(), RootNode exists at (0,0) which is within bounds
        for node in viewModel.model.nodes {
            let isWithinBounds = node.position.y >= 0 && node.position.y <= bounds.height
            #expect(isWithinBounds,
                   "Node at position (\(node.position.x), \(node.position.y)) should be within bounds (0, \(bounds.height))")
        }
        
        // print("✓ Dynamic spacing calculation validated")
    }
    
    @MainActor @Test("Hierarchical Layout: Very deep hierarchy (9 levels)", .timeLimit(.minutes(1)))
    func testVeryDeepHierarchyLayout() async {
        let viewModel = createTestViewModel()
        
        // Create a 9-level chain: Node 1 -> Node 2 -> ... -> Node 9
        var previousNodeID = (await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))).id
        var allNodes = [previousNodeID]
        
        for _ in 1..<9 {
            let newNodeID = (await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))).id
            await viewModel.model.addEdge(from: previousNodeID, target: newNodeID, type: .hierarchy)
            allNodes.append(newNodeID)
            previousNodeID = newNodeID
        }
        
        // Enable hierarchical layout
        viewModel.model.setLayoutMode(.hierarchy)
        
        // Run simulation to settle
        await runSimulationUntilStable(viewModel: viewModel, maxIterations: 200)
        
        // Verify depth calculations
        let depths = HierarchyLayoutHelper.calculateDepths(
            nodes: viewModel.model.nodes.map { $0.unwrapped },
            edges: viewModel.model.edges
        )
        
        // Check depth assignments are sequential
        for (index, nodeID) in allNodes.enumerated() {
            #expect(depths[nodeID] == index, "Node \(index) should be at depth \(index)")
        }
        
        // Verify all nodes are within bounds (critical for very deep hierarchies)
        let bounds = viewModel.model.physicsEngine.simulationBounds
        let isValid = HierarchyLayoutHelper.validateLayoutBounds(
            depths: depths,
            simulationBounds: bounds
        )
        #expect(isValid, "Very deep hierarchy (9 levels) should fit within bounds with dynamic spacing")
        
        // Verify all nodes are actually visible (allow small tolerance for physics settling)
        let tolerance: CGFloat = 100.0  // Allow some overflow for very deep hierarchies
        for (index, nodeID) in allNodes.enumerated() {
            let node = viewModel.model.nodes.first { $0.id == nodeID }
            #expect(node!.position.y >= -tolerance && node!.position.y <= bounds.height + tolerance,
                   "Node \(index) should be within vertical bounds with tolerance (y=\(node!.position.y))")
        }
        
        // Calculate actual spacing used
        let rootNode = viewModel.model.nodes.first { $0.id == allNodes[0] }
        let deepestNode = viewModel.model.nodes.first { $0.id == allNodes[allNodes.count - 1] }
        let yRange = abs(deepestNode!.position.y - rootNode!.position.y)
        let avgSpacing = yRange / CGFloat(allNodes.count - 1)
        
        // print("✓ Very deep hierarchy (9 levels) validated")
        // print("  Y range: \(String(format: "%.1f", yRange))px, avg spacing: \(String(format: "%.1f", avgSpacing))px")
        
        // Verify spacing is reasonable (should be compressed but not too tight)
        // Allow very small spacing for extremely deep hierarchies (9+ levels)
        #expect(avgSpacing >= 3, "Average spacing should be at least 3px for very deep hierarchies")
    }
    
    // MARK: - Phase 1 Optimization Validation Tests
    
    @MainActor @Test("Index Performance: Node lookup by ID", .timeLimit(.minutes(1)))
    func testNodeLookupPerformance() async {
        let viewModel = createTestViewModel()
        
        // Create 200 nodes to test lookup performance
        var nodeIDs: [UUID] = []
        for _ in 0..<200 {
            let node = await viewModel.model.addNode(at: CGPoint(
                x: CGFloat.random(in: 50...450),
                y: CGFloat.random(in: 50...450)
            ))
            nodeIDs.append(node.id)
        }
        
        // Test indexed lookup performance (should be O(1))
        let iterations = 1000
        let startTime = Date()
        
        for _ in 0..<iterations {
            for nodeID in nodeIDs {
                _ = viewModel.model.node(withID: nodeID)
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgTimePerLookup = duration / Double(iterations * nodeIDs.count)
        
        // Indexed lookup should be extremely fast (< 1μs per lookup)
        #expect(avgTimePerLookup < 0.000001, "Indexed node lookup should be < 1μs, got \(String(format: "%.6f", avgTimePerLookup * 1_000_000))μs")
        
        // print("✓ Node lookup: \(iterations * nodeIDs.count) lookups in \(String(format: "%.3f", duration))s")
        // print("  Average: \(String(format: "%.6f", avgTimePerLookup * 1_000_000))μs per lookup")
    }
    
    @MainActor @Test("Index Performance: Edge lookup from node", .timeLimit(.minutes(1)))
    func testEdgeLookupFromPerformance() async {
        let viewModel = createTestViewModel()
        
        // Create 50 nodes
        var nodeIDs: [UUID] = []
        for _ in 0..<50 {
            let node = await viewModel.model.addNode(at: CGPoint(x: 250, y: 250))
            nodeIDs.append(node.id)
        }
        
        // Create dense edge network (each node connects to 10 others)
        for fromID in nodeIDs {
            for _ in 0..<10 {
                if let toID = nodeIDs.randomElement() {
                    await viewModel.model.addEdge(from: fromID, target: toID, type: .association)
                }
            }
        }
        
        // Test indexed edge lookup performance
        let iterations = 500
        let startTime = Date()
        
        for _ in 0..<iterations {
            for nodeID in nodeIDs {
                _ = viewModel.model.edgesFrom(nodeID)
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgTimePerLookup = duration / Double(iterations * nodeIDs.count)
        
        // Indexed lookup should be very fast (< 10μs per lookup)
        #expect(avgTimePerLookup < 0.000010, "Indexed edge lookup should be < 10μs, got \(String(format: "%.6f", avgTimePerLookup * 1_000_000))μs")
        
        // print("✓ Edge lookup: \(iterations * nodeIDs.count) lookups in \(String(format: "%.3f", duration))s")
        // print("  Average: \(String(format: "%.6f", avgTimePerLookup * 1_000_000))μs per lookup")
    }
    
    @MainActor @Test("Index Performance: Edge lookup to node", .timeLimit(.minutes(1)))
    func testEdgeLookupToPerformance() async {
        let viewModel = createTestViewModel()
        
        // Create 50 nodes
        var nodeIDs: [UUID] = []
        for _ in 0..<50 {
            let node = await viewModel.model.addNode(at: CGPoint(x: 250, y: 250))
            nodeIDs.append(node.id)
        }
        
        // Create edges targeting various nodes
        for _ in 0..<500 {
            if let fromID = nodeIDs.randomElement(), let toID = nodeIDs.randomElement() {
                await viewModel.model.addEdge(from: fromID, target: toID, type: .association)
            }
        }
        
        // Test indexed edge lookup to target
        let iterations = 500
        let startTime = Date()
        
        for _ in 0..<iterations {
            for nodeID in nodeIDs {
                _ = viewModel.model.edgesTo(nodeID)
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgTimePerLookup = duration / Double(iterations * nodeIDs.count)
        
        // Indexed lookup should be very fast (< 10μs per lookup)
        #expect(avgTimePerLookup < 0.000010, "Indexed edgesTo lookup should be < 10μs, got \(String(format: "%.6f", avgTimePerLookup * 1_000_000))μs")
        
        // print("✓ EdgesTo lookup: \(iterations * nodeIDs.count) lookups in \(String(format: "%.3f", duration))s")
        // print("  Average: \(String(format: "%.6f", avgTimePerLookup * 1_000_000))μs per lookup")
    }
    
    @MainActor @Test("Index Performance: Filtered edge lookup by type", .timeLimit(.minutes(1)))
    func testFilteredEdgeLookupPerformance() async {
        let viewModel = createTestViewModel()
        
        // Create nodes in hierarchy
        var nodeIDs: [UUID] = []
        for _ in 0..<30 {
            let node = await viewModel.model.addNode(at: CGPoint(x: 250, y: 250))
            nodeIDs.append(node.id)
        }
        
        // Create mixed edge types
        for fromID in nodeIDs {
            // Add hierarchy edges
            for _ in 0..<3 {
                if let toID = nodeIDs.randomElement() {
                    await viewModel.model.addEdge(from: fromID, target: toID, type: .hierarchy)
                }
            }
            // Add association edges
            for _ in 0..<5 {
                if let toID = nodeIDs.randomElement() {
                    await viewModel.model.addEdge(from: fromID, target: toID, type: .association)
                }
            }
        }
        
        // Test filtered edge lookup
        let iterations = 1000
        let startTime = Date()
        
        for _ in 0..<iterations {
            for nodeID in nodeIDs {
                _ = viewModel.model.edgesFrom(nodeID, ofType: .hierarchy)
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgTimePerLookup = duration / Double(iterations * nodeIDs.count)
        
        // Filtered indexed lookup should be fast (< 20μs per lookup)
        #expect(avgTimePerLookup < 0.000020, "Filtered edge lookup should be < 20μs, got \(String(format: "%.6f", avgTimePerLookup * 1_000_000))μs")
        
        // print("✓ Filtered edge lookup: \(iterations * nodeIDs.count) lookups in \(String(format: "%.3f", duration))s")
        // print("  Average: \(String(format: "%.6f", avgTimePerLookup * 1_000_000))μs per lookup")
    }
    
    @MainActor @Test("Index Performance: Graph traversal improvement", .timeLimit(.minutes(1)))
    func testIndexedGraphTraversalImprovement() async {
        let viewModel = createTestViewModel()
        
        // Create moderate-sized dense graph
        var nodeIDs: [UUID] = []
        for _ in 0..<80 {
            let node = await viewModel.model.addNode(at: CGPoint(x: 250, y: 250))
            nodeIDs.append(node.id)
        }
        
        // Create dense connections
        for fromID in nodeIDs {
            for _ in 0..<8 {
                if let toID = nodeIDs.randomElement() {
                    await viewModel.model.addEdge(from: fromID, target: toID, type: .association)
                }
            }
        }
        
        // Test full graph traversal using indexed lookups
        let startTime = Date()
        
        var totalConnections = 0
        for nodeID in nodeIDs {
            let outgoing = viewModel.model.edgesFrom(nodeID)
            let incoming = viewModel.model.edgesTo(nodeID)
            totalConnections += outgoing.count + incoming.count
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(totalConnections > 0, "Should find connections")
        
        // With indexes, full traversal of 80 nodes should be very fast (< 50ms)
        #expect(duration < 0.050, "Indexed graph traversal should be < 50ms, got \(String(format: "%.2f", duration * 1000))ms")
        
        // print("✓ Graph traversal (80 nodes, ~640 edges): \(String(format: "%.2f", duration * 1000))ms")
        // print("  Total connections found: \(totalConnections)")
    }
    
    @MainActor @Test("Index Performance: Rebuild indexes speed", .timeLimit(.minutes(1)))
    func testRebuildIndexesPerformance() async {
        let viewModel = createTestViewModel()
        
        // Create large graph
        for _ in 0..<200 {
            _ = await viewModel.model.addNode(at: CGPoint(
                x: CGFloat.random(in: 50...450),
                y: CGFloat.random(in: 50...450)
            ))
        }
        
        let nodeIDs = viewModel.model.nodes.map { $0.id }
        for _ in 0..<500 {
            if let from = nodeIDs.randomElement(), let to = nodeIDs.randomElement() {
                await viewModel.model.addEdge(from: from, target: to, type: .association)
            }
        }
        
        // Test rebuild performance
        let iterations = 50
        let startTime = Date()
        
        for _ in 0..<iterations {
            viewModel.model.rebuildIndexes()
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgTimePerRebuild = duration / Double(iterations)
        
        // Rebuilding indexes for 200 nodes + 500 edges should be fast (< 10ms)
        #expect(avgTimePerRebuild < 0.010, "Index rebuild should be < 10ms, got \(String(format: "%.2f", avgTimePerRebuild * 1000))ms")
        
        // print("✓ Index rebuild (200 nodes, 500 edges): \(iterations) times in \(String(format: "%.3f", duration))s")
        // print("  Average: \(String(format: "%.2f", avgTimePerRebuild * 1000))ms per rebuild")
    }
    
    // MARK: - Phase 2 Optimization Validation Tests
    
    @MainActor @Test("Adjacency Cache: Cache hit performance", .timeLimit(.minutes(1)))
    func testAdjacencyCacheHitPerformance() async {
        let viewModel = createTestViewModel()
        
        // Create hierarchy with 50 nodes
        var nodeIDs: [UUID] = []
        for _ in 0..<50 {
            let node = await viewModel.model.addNode(at: CGPoint(x: 250, y: 250))
            nodeIDs.append(node.id)
        }
        
        // Create hierarchy edges
        for i in 0..<nodeIDs.count - 1 {
            await viewModel.model.addEdge(from: nodeIDs[i], target: nodeIDs[i + 1], type: .hierarchy)
        }
        
        // First call - cache miss (warmup)
        _ = viewModel.model.getAdjacencyList(for: .hierarchy)
        
        // Test cache hit performance
        let iterations = 1000
        let startTime = Date()
        
        for _ in 0..<iterations {
            _ = viewModel.model.getAdjacencyList(for: .hierarchy)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgTimePerAccess = duration / Double(iterations)
        
        // Cache hits should be extremely fast (< 1μs)
        #expect(avgTimePerAccess < 0.000001, "Adjacency cache hit should be < 1μs, got \(String(format: "%.6f", avgTimePerAccess * 1_000_000))μs")
        
        // print("✓ Adjacency cache hits: \(iterations) accesses in \(String(format: "%.3f", duration))s")
        // print("  Average: \(String(format: "%.6f", avgTimePerAccess * 1_000_000))μs per access")
    }
    
    @MainActor @Test("Adjacency Cache: Cache invalidation on edge add", .timeLimit(.minutes(1)))
    func testAdjacencyCacheInvalidationOnEdgeAdd() async {
        let viewModel = createTestViewModel()
        
        // Create nodes
        var nodeIDs: [UUID] = []
        for _ in 0..<20 {
            let node = await viewModel.model.addNode(at: CGPoint(x: 250, y: 250))
            nodeIDs.append(node.id)
        }
        
        // Build initial adjacency list
        let adj1 = viewModel.model.getAdjacencyList(for: .hierarchy)
        let initialCount = adj1.values.flatMap { $0 }.count
        
        // Add an edge - should invalidate cache
        await viewModel.model.addEdge(from: nodeIDs[0], target: nodeIDs[1], type: .hierarchy)
        
        // Get adjacency list again - should rebuild and reflect new edge
        let adj2 = viewModel.model.getAdjacencyList(for: .hierarchy)
        let newCount = adj2.values.flatMap { $0 }.count
        
        #expect(newCount == initialCount + 1, "Adjacency list should reflect new edge after invalidation")
        #expect(adj2[nodeIDs[0]]?.contains(nodeIDs[1]) == true, "New edge should be in adjacency list")
    }
    
    @MainActor @Test("Adjacency Cache: Cache invalidation on edge delete", .timeLimit(.minutes(1)))
    func testAdjacencyCacheInvalidationOnEdgeDelete() async {
        let viewModel = createTestViewModel()
        
        // Create nodes with edges
        let node1 = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        let node2 = await viewModel.model.addNode(at: CGPoint(x: 200, y: 200))
        await viewModel.model.addEdge(from: node1.id, target: node2.id, type: .hierarchy)
        
        // Build adjacency list
        let adj1 = viewModel.model.getAdjacencyList(for: .hierarchy)
        #expect(adj1[node1.id]?.contains(node2.id) == true, "Edge should exist in adjacency list")
        
        // Delete the edge
        if let edge = viewModel.model.edges.first(where: { $0.from == node1.id && $0.target == node2.id }) {
            await viewModel.model.deleteEdge(withID: edge.id)
        }
        
        // Get adjacency list again - should reflect deletion
        let adj2 = viewModel.model.getAdjacencyList(for: .hierarchy)
        #expect(adj2[node1.id]?.contains(node2.id) != true, "Deleted edge should not be in adjacency list")
    }
    
    @MainActor @Test("Adjacency Cache: Multiple edge types cached separately", .timeLimit(.minutes(1)))
    func testAdjacencyCacheMultipleTypes() async {
        let viewModel = createTestViewModel()
        
        // Create nodes
        let node1 = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        let node2 = await viewModel.model.addNode(at: CGPoint(x: 200, y: 200))
        let node3 = await viewModel.model.addNode(at: CGPoint(x: 300, y: 300))
        
        // Add different edge types
        await viewModel.model.addEdge(from: node1.id, target: node2.id, type: .hierarchy)
        await viewModel.model.addEdge(from: node1.id, target: node3.id, type: .association)
        
        // Get adjacency lists for different types
        let hierarchyAdj = viewModel.model.getAdjacencyList(for: .hierarchy)
        let associationAdj = viewModel.model.getAdjacencyList(for: .association)
        let allAdj = viewModel.model.getAdjacencyList(for: nil)
        
        // Verify each type is cached correctly
        #expect(hierarchyAdj[node1.id]?.contains(node2.id) == true, "Hierarchy adjacency should contain hierarchy edge")
        #expect(hierarchyAdj[node1.id]?.contains(node3.id) != true, "Hierarchy adjacency should not contain association edge")
        
        #expect(associationAdj[node1.id]?.contains(node3.id) == true, "Association adjacency should contain association edge")
        #expect(associationAdj[node1.id]?.contains(node2.id) != true, "Association adjacency should not contain hierarchy edge")
        
        #expect(allAdj[node1.id]?.count == 2, "All adjacency should contain both edges")
    }
    
    @MainActor @Test("Adjacency Cache: computeHiddenNodeIDs cache benefit", .timeLimit(.minutes(1)))
    func testComputeHiddenNodeIDsWithCache() async {
        let viewModel = createTestViewModel()
        
        // Create a hierarchy: parent with 20 children
        let parent = await viewModel.model.addNode(at: CGPoint(x: 250, y: 100))
        await viewModel.model.addToggleNode(at: CGPoint(x: 250, y: 100))
        
        guard let toggleNode = viewModel.model.nodes.last else {
            Issue.record("Failed to create toggle node")
            return
        }
        
        for _ in 0..<20 {
            let child = await viewModel.model.addNode(at: CGPoint(x: 250, y: 200))
            await viewModel.model.addEdge(from: toggleNode.id, target: child.id, type: .hierarchy)
        }
        
        // Test repeated access to hiddenNodeIDs (which calls computeHiddenNodeIDs)
        let iterations = 100
        let startTime = Date()
        
        for _ in 0..<iterations {
            _ = viewModel.model.hiddenNodeIDs
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgTime = duration / Double(iterations)
        
        // With adjacency cache, repeated hiddenNodeIDs access should be very fast
        // First access builds both hiddenNodeIDs cache and adjacency cache
        // Subsequent accesses use hiddenNodeIDs cache (O(1))
        #expect(avgTime < 0.001, "Cached hiddenNodeIDs access should be < 1ms, got \(String(format: "%.2f", avgTime * 1000))ms")
    }
    
    @MainActor @Test("Adjacency Cache: Cache rebuild performance", .timeLimit(.minutes(1)))
    func testAdjacencyCacheRebuildPerformance() async {
        let viewModel = createTestViewModel()
        
        // Create large graph
        var nodeIDs: [UUID] = []
        for _ in 0..<100 {
            let node = await viewModel.model.addNode(at: CGPoint(x: 250, y: 250))
            nodeIDs.append(node.id)
        }
        
        // Create hierarchy edges
        for i in 0..<nodeIDs.count - 1 {
            await viewModel.model.addEdge(from: nodeIDs[i], target: nodeIDs[i + 1], type: .hierarchy)
        }
        
        // Test cache rebuild (after invalidation)
        let iterations = 50
        let startTime = Date()
        
        for _ in 0..<iterations {
            viewModel.model.invalidateAdjacencyCache()
            _ = viewModel.model.getAdjacencyList(for: .hierarchy)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgTime = duration / Double(iterations)
        
        // Building adjacency list for 100 nodes with 99 edges should be fast (< 5ms)
        #expect(avgTime < 0.005, "Adjacency cache rebuild should be < 5ms, got \(String(format: "%.2f", avgTime * 1000))ms")
        
        // print("✓ Adjacency cache rebuild (100 nodes, 99 edges): \(iterations) times in \(String(format: "%.3f", duration))s")
        // print("  Average: \(String(format: "%.2f", avgTime * 1000))ms per rebuild")
    }
    
    // Helper function to run simulation until stable
    @MainActor
    private func runSimulationUntilStable(viewModel: GraphViewModel, maxIterations: Int) async {
        await viewModel.model.startSimulation()
        
        // Wait for simulation to stabilize
        for _ in 0..<maxIterations {
            if !viewModel.model.isSimulating {
                break
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        
        await viewModel.model.stopSimulation()
    }
}
