//
//  PhysicConstants.swift
//  GraphEditor
//
//  Created by handcart on 8/4/25.
//


import CoreGraphics

public struct PhysicsConstants {
    public static let stiffness: CGFloat = 0.5
    public static let repulsion: CGFloat = 5000
    public static let damping: CGFloat = 0.85
    public static let idealLength: CGFloat = 100
    public static let centeringForce: CGFloat = 0.005
    public static let distanceEpsilon: CGFloat = 1e-3
    public static let timeStep: CGFloat = 0.05
    public static let velocityThreshold: CGFloat = 0.2
    public static let maxSimulationSteps = 500
    public static let minQuadSize: CGFloat = 1e-6
    public static let maxQuadtreeDepth = 64
    private let maxNodesForQuadtree = 75  // Adjust based on profiling; watchOS limit
}
