//
//  GraphEditorWatchTests.swift
//  GraphEditorWatchTests
//
//  Created by handcart on 8/2/25.
//

import Testing
@testable import GraphEditorWatchApp_Watch_App  // Replace with your actual app module name (check Build Settings > Product Module Name)
import GraphEditorShared

struct GraphModelTests {

    @Test func testSnapshotAndUndo() {
        let model = GraphModel()
        let initialNodes = model.nodes
        model.snapshot()
        model.nodes.append(Node(label: 4, position: .zero))  // Adjusted to match Node init
        model.undo()
        #expect(model.nodes.count == initialNodes.count)
    }
    
    @Test func testDeleteNode() {
        let model = GraphModel()
        #expect(!model.nodes.isEmpty, "Assumes default nodes exist")  // Guard for empty graph
        let nodeID = model.nodes[0].id
        let initialEdgeCount = model.edges.count
        model.deleteNode(withID: nodeID)
        #expect(model.nodes.first { $0.id == nodeID } == nil)
        #expect(model.edges.count < initialEdgeCount)
    }
}
