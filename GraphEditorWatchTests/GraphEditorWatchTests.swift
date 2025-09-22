import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
@testable import GraphEditorShared
import XCTest
import SwiftUI

class MockGraphStorage: GraphStorage {
    var nodes: [any NodeProtocol] = []
    var edges: [GraphEdge] = []
    
    func save(nodes: [any NodeProtocol], edges: [GraphEdge]) throws {
        self.nodes = nodes
        self.edges = edges
    }
    
    func load() throws -> (nodes: [any NodeProtocol], edges: [GraphEdge]) {
        (nodes, edges)
    }
    
    func clear() throws {
        nodes = []
        edges = []
    }
}

func approximatelyEqual(_ lhs: CGPoint, _ rhs: CGPoint, accuracy: CGFloat) -> Bool {
    return hypot(lhs.x - rhs.x, lhs.y - rhs.y) < accuracy
}
