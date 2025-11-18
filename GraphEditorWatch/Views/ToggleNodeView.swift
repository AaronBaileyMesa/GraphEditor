//
//  ToggleNodeView.swift
//  GraphEditor
//
//  Created by handcart on 11/16/25.
//

import SwiftUI
import GraphEditorShared

struct ToggleNodeView: View {
    let node: ToggleNode  // Pass the ToggleNode instance
    let zoomScale: CGFloat  // For scaling icon with zoom (from your GraphCanvasView)
    let onTap: () -> Void  // Optional: Handle tap to toggle (if not using gestures)

    var body: some View {
        ZStack {
            // Existing node circle (adapt from your code; e.g., from AccessibleCanvas drawSingleNode)
            Circle()
                .fill(node.fillColor)  // e.g., .green for expanded, .red for collapsed
                .frame(width: node.radius * 2 * zoomScale, height: node.radius * 2 * zoomScale)
            
            // Chevron icon with rotation animation
            Image(systemName: "chevron.right")
                .font(.system(size: node.radius * zoomScale * 0.8))  // Scale to ~80% of node radius
                .foregroundColor(.white)  // High contrast; adjust as needed
                .rotationEffect(.degrees(node.isExpanded ? 90 : 0))  // 90° for down-facing when expanded
                .animation(.easeInOut(duration: 0.2), value: node.isExpanded)  // Smooth transition
        }
        .onTapGesture(perform: onTap)  // If tapping the node should toggle
    }
}
