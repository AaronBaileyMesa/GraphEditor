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
            if let taskNode = node as? TaskNode {
                // TaskNode: RoundedRectangle with task type icon
                RoundedRectangle(cornerRadius: 6 * zoomScale)
                    .fill(taskNode.fillColor)
                    .frame(width: taskNode.radius * 2.5 * zoomScale, height: taskNode.radius * 2 * zoomScale)

                Image(systemName: taskTypeIcon(taskNode.taskType))
                    .font(.system(size: max(8.0, 12.0 * zoomScale), weight: .medium))
                    .foregroundColor(.white)

                Text("\(taskNode.label)")
                    .foregroundColor(.white)
                    .font(.system(size: max(6.0, 10.0 * zoomScale)))
                    .offset(y: -(taskNode.radius + 10) * zoomScale)
            } else if let mealNode = node as? MealNode {
                // MealNode: Larger circle with fork.knife icon
                Circle()
                    .fill(mealNode.fillColor)
                    .frame(width: mealNode.radius * 2.6 * zoomScale, height: mealNode.radius * 2.6 * zoomScale)

                Image(systemName: "fork.knife")
                    .font(.system(size: max(10.0, 14.0 * zoomScale), weight: .medium))
                    .foregroundColor(.white)

                Text("\(mealNode.label)")
                    .foregroundColor(.white)
                    .font(.system(size: max(8.0, 12.0 * zoomScale)))
                    .offset(y: -(mealNode.radius * 1.5 + 10) * zoomScale)

                if zoomScale >= 0.5, !mealNode.name.isEmpty {
                    Text(mealNode.name)
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: max(6.0, 9.0 * zoomScale)))
                        .offset(y: (mealNode.radius * 1.5 + 10) * zoomScale)
                }
            } else if let decisionNode = node as? DecisionNode {
                // DecisionNode: Diamond shape with question mark
                Circle()
                    .fill(decisionNode.fillColor)
                    .frame(width: decisionNode.radius * 2.2 * zoomScale, height: decisionNode.radius * 2.2 * zoomScale)

                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: max(10.0, 14.0 * zoomScale), weight: .medium))
                    .foregroundColor(.white)

                Text("\(decisionNode.label)")
                    .foregroundColor(.white)
                    .font(.system(size: max(6.0, 10.0 * zoomScale)))
                    .offset(y: -(decisionNode.radius * 1.3 + 10) * zoomScale)
            } else if let choiceNode = node as? ChoiceNode {
                // ChoiceNode: Small circle with checkmark if selected
                Circle()
                    .fill(choiceNode.fillColor)
                    .frame(width: choiceNode.radius * 2 * zoomScale, height: choiceNode.radius * 2 * zoomScale)

                if choiceNode.isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: max(6.0, 10.0 * zoomScale), weight: .bold))
                        .foregroundColor(.white)
                }

                Text("\(choiceNode.label)")
                    .foregroundColor(.white)
                    .font(.system(size: max(6.0, 9.0 * zoomScale)))
                    .offset(y: -(choiceNode.radius + 8) * zoomScale)
            } else if let preferenceNode = node as? PreferenceNode {
                // PreferenceNode: Larger circle with document icon
                Circle()
                    .fill(preferenceNode.fillColor)
                    .frame(width: preferenceNode.radius * 2.4 * zoomScale, height: preferenceNode.radius * 2.4 * zoomScale)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: max(10.0, 14.0 * zoomScale), weight: .medium))
                    .foregroundColor(.white)

                Text("\(preferenceNode.label)")
                    .foregroundColor(.white)
                    .font(.system(size: max(7.0, 11.0 * zoomScale)))
                    .offset(y: -(preferenceNode.radius * 1.4 + 10) * zoomScale)
            } else if let personNode = node as? PersonNode {
                // PersonNode: Circle with person icon
                Circle()
                    .fill(personNode.fillColor)
                    .frame(width: personNode.radius * 2 * zoomScale, height: personNode.radius * 2 * zoomScale)

                Image(systemName: "person.fill")
                    .font(.system(size: max(8.0, 12.0 * zoomScale), weight: .medium))
                    .foregroundColor(.white)

                Text("\(personNode.label)")
                    .foregroundColor(.white)
                    .font(.system(size: max(6.0, 10.0 * zoomScale)))
                    .offset(y: -(personNode.radius + 8) * zoomScale)
                
                if zoomScale >= 0.5, !personNode.name.isEmpty {
                    Text(personNode.name)
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: max(6.0, 9.0 * zoomScale)))
                        .offset(y: (personNode.radius + 8) * zoomScale)
                }
            } else if let control = node as? ControlNode {
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
                    .fill(node.fillColor)
                    .frame(width: node.radius * 2 * zoomScale, height: node.radius * 2 * zoomScale)
                
                Text("\(node.label)")
                    .foregroundColor(.white)
                    .font(.system(size: max(8.0, 12.0 * zoomScale)))
                    .offset(y: -(node.radius + 10) * zoomScale)  // Position above
                
                // Display first content if present (only at reasonable zoom levels)
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

    private func taskTypeIcon(_ taskType: TaskType) -> String {
        switch taskType {
        case .plan: return "list.clipboard"
        case .shop: return "cart.fill"
        case .prep: return "takeoutbag.and.cup.and.straw.fill"
        case .cook: return "flame.fill"
        case .serve: return "fork.knife"
        case .cleanup: return "paintbrush.fill"
        }
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
