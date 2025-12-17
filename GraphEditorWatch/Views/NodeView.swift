//
//  NodeView.swift
//  GraphEditor
//
//  Created by handcart on 8/13/25.
//

import SwiftUI
import GraphEditorShared

struct NodeView: View {
    let node: any NodeProtocol
    let isSelected: Bool
    let zoomScale: CGFloat
    
    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .stroke(Color.yellow, lineWidth: 4 * zoomScale)
                    .frame(width: node.radius * 2 * zoomScale + 4 * zoomScale, height: node.radius * 2 * zoomScale + 4 * zoomScale)
            }
            if let control = node as? ControlNode {
                // Distinct rendering for controls: smaller, with icon
                Circle()
                    .fill(control.fillColor.opacity(0.9))
                    .frame(width: control.radius * zoomScale, height: control.radius * zoomScale)  // Smaller: *0.5 implicit via control.radius
                    .shadow(color: .black.opacity(0.3), radius: 2 * zoomScale, x: 0, y: 0)  // Subtle distinction
                
                Image(systemName: control.kind.systemImage)
                    .font(.system(size: max(6.0, 10.0 * zoomScale), weight: .medium))
                    .foregroundColor(.white)
            } else {
                Circle()
                    .fill(node.fillColor)  // Or dynamic based on node type
                    .frame(width: node.radius * 2 * zoomScale, height: node.radius * 2 * zoomScale)
                
                // Add icon/label as in ToggleNode.draw
                if let toggleNode = node as? ToggleNode {
                    Text(toggleNode.isExpanded ? "-" : "+")
                        .foregroundColor(.white)
                        .font(.system(size: max(8.0, 12.0 * zoomScale), weight: .bold))
                }
                
                Text("\(node.label)")
                    .foregroundColor(.white)
                    .font(.system(size: max(8.0, 12.0 * zoomScale)))
                    .offset(y: -(node.radius + 10) * zoomScale)  // Position above
            }
        }
        .focusable()  // For Digital Crown on watchOS
        .accessibilityLabel(
            (node as? ControlNode)?.kind.rawValue ?? "Node \(node.label)"
        )
    }
}
