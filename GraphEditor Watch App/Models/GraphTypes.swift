import SwiftUI
import Foundation

public typealias NodeID = UUID

// Represents a node in the graph with position, velocity, and permanent label.
public struct Node: Identifiable, Equatable, Codable {
    public let id: NodeID
    public let label: Int  // Permanent label, assigned on creation
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    
    enum CodingKeys: String, CodingKey {
        case id, label
        case positionX, positionY
        case velocityX, velocityY
    }
    
    public init(id: NodeID = NodeID(), label: Int, position: CGPoint, velocity: CGPoint = .zero) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        let posX = try container.decode(CGFloat.self, forKey: .positionX)
        let posY = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: posX, y: posY)
        let velX = try container.decode(CGFloat.self, forKey: .velocityX)
        let velY = try container.decode(CGFloat.self, forKey: .velocityY)
        velocity = CGPoint(x: velX, y: velY)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(velocity.x, forKey: .velocityX)
        try container.encode(velocity.y, forKey: .velocityY)
    }
}

// Represents an edge connecting two nodes.
public struct Edge: Identifiable, Equatable, Codable {
    public let id: NodeID
    public let from: NodeID
    public let to: NodeID
    
    enum CodingKeys: String, CodingKey {
        case id, from, to
    }
    
    public init(id: NodeID = NodeID(), from: NodeID, to: NodeID) {
        self.id = id
        self.from = from
        self.to = to
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        from = try container.decode(NodeID.self, forKey: .from)
        to = try container.decode(NodeID.self, forKey: .to)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
    }
}

// Snapshot of the graph state for undo/redo.
public struct GraphState: Codable {
    public let nodes: [Node]
    public let edges: [Edge]
}
