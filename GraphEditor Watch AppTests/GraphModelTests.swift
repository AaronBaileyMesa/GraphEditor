//
//  GraphModelTests.swift
//  GraphEditor
//
//  Created by handcart on 7/31/25.
//


import XCTest
@testable import GraphEditor_Watch_App 

class GraphModelTests: XCTestCase {
    func testSnapshotAndUndo() {
        let model = GraphModel()
        let initialNodes = model.nodes
        model.snapshot()
        model.nodes.append(Node(position: .zero))
        model.undo()
        XCTAssertEqual(model.nodes.count, initialNodes.count)
    }
    
    func testDeleteNode() {
        let model = GraphModel()
        let nodeID = model.nodes[0].id
        let initialEdgeCount = model.edges.count
        model.deleteNode(withID: nodeID)
        XCTAssertNil(model.nodes.first { $0.id == nodeID })
        XCTAssertLessThan(model.edges.count, initialEdgeCount)
    }
    
    func testSaveLoad() {
        let model = GraphModel()
        model.save()
        let newModel = GraphModel()
        newModel.load()
        XCTAssertEqual(model.nodes.count, newModel.nodes.count)
    }
}
