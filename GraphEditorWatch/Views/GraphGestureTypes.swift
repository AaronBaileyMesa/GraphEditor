//
// GraphGestureTypes.swift
//  GraphEditor
//
//  Created by handcart on 11/18/25.
//

import SwiftUI
import GraphEditorShared

enum HitType {
    case node
    case edge
}

struct NodeDistanceInfo {
    let label: Int
    let screenPos: CGPoint
    let dist: CGFloat
}
