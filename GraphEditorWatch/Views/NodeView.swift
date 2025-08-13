//
//  NodeView.swift
//  GraphEditor
//
//  Created by handcart on 8/13/25.
//

import SwiftUICore
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
            Circle()
                .fill(Color.blue)  // Or dynamic based on node type
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
}
