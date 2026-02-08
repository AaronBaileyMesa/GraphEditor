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
                
                // Add icon/label for collapsible nodes
                if let concreteNode = node as? Node, concreteNode.isCollapsible {
                    Text(concreteNode.isExpanded ? "-" : "+")
                        .foregroundColor(.white)
                        .font(.system(size: max(8.0, 12.0 * zoomScale), weight: .bold))
                }
                
                Text("\(node.label)")
                    .foregroundColor(.white)
                    .font(.system(size: max(8.0, 12.0 * zoomScale)))
                    .offset(y: -(node.radius + 10) * zoomScale)  // Position above
                
                // NEW: Display first content if present (only at reasonable zoom levels)
                if !node.contents.isEmpty, zoomScale >= 0.5 {
                    Text(node.contents[0].displayText)
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: max(6.0, 9.0 * zoomScale)))
                        .offset(y: (node.radius + 10) * zoomScale)  // Position below
                }
            }
        }
        .accessibilityLabel(
            (node as? ControlNode)?.kind.rawValue ?? "Node \(node.label)" + (node.contents.isEmpty ? "" : ", \(node.contents[0].displayText)")
        )
    }
}

#Preview("Control Node Colors") {
    VStack(spacing: 15) {
        Text("Control Nodes (85% size)")
            .font(.headline)
        Text("With 1.5x hit testing area")
            .font(.caption)
            .foregroundColor(.gray)
        
        VStack(spacing: 10) {
            ForEach(ControlKind.allCases, id: \.self) { kind in
                HStack {
                    ZStack {
                        // Show hit testing area in preview
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            .frame(width: 60, height: 60)  // 1.5x visual size
                        
                        NodeView(
                            node: ControlNode(
                                position: .zero,
                                ownerID: nil,
                                kind: kind
                            ),
                            isSelected: false,
                            zoomScale: 3.0
                        )
                    }
                    .frame(width: 60, height: 60)
                    
                    Text(kind.rawValue)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    .padding()
    .background(Color.black)
}
