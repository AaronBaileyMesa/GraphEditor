//
//  AccessibleCanvasRenderer+Labels.swift
//  GraphEditor
//
//  Label rendering helpers for AccessibleCanvasRenderer
//

import SwiftUI
import GraphEditorShared
import os

extension AccessibleCanvasRenderer {

    // MARK: - Node Label Rendering
    // swiftlint:disable:next function_parameter_count
    static func drawNodeLabels(
        context: GraphicsContext,
        node: any NodeProtocol,
        screenPos: CGPoint,
        zoomScale: CGFloat,
        tablePosition: CGPoint?,
        isInGrid: Bool = false,
        gridPosition: (row: Int, col: Int)? = nil,
        logger: Logger?
    ) {
        // NOTE: Label rendering still uses type-checking for now
        // swiftlint:disable:next todo
        // TODO: Move to NodeTypeDescriptor.labelRenderer in future phase
        if let control = node as? ControlNode {
            drawControlIcon(context: context, control: control, screenPos: screenPos, zoomScale: zoomScale, logger: logger)
        } else if let person = node as? PersonNode {
            drawPersonLabel(context: context, person: person, node: node, screenPos: screenPos, zoomScale: zoomScale, tablePosition: tablePosition, isInGrid: isInGrid, gridPosition: gridPosition)
        } else if let table = node as? TableNode {
            drawTableLabel(context: context, table: table, node: node, screenPos: screenPos, zoomScale: zoomScale)
        } else {
            drawRegularNodeLabels(context: context, node: node, screenPos: screenPos, zoomScale: zoomScale)
        }
    }

    static func drawControlIcon(
        context: GraphicsContext,
        control: ControlNode,
        screenPos: CGPoint,
        zoomScale: CGFloat,
        logger: Logger?
    ) {
        let iconSize = max(8.0, 12.0 * zoomScale)
        let iconRect = CGRect(
            x: screenPos.x - iconSize / 2,
            y: screenPos.y - iconSize / 2,
            width: iconSize,
            height: iconSize
        )

        let icon = Image(systemName: control.kind.systemImage)
        context.drawLayer { layer in
            layer.addFilter(.colorMultiply(.white))
            layer.draw(icon, in: iconRect)
        }

        #if DEBUG
        logger?.debug("Drew control node icon '\(control.kind.systemImage)' at (x: \(screenPos.x, privacy: .public), y: \(screenPos.y, privacy: .public))")
        #endif
    }

    // swiftlint:disable:next function_parameter_count
    static func drawPersonLabel(
        context: GraphicsContext,
        person: PersonNode,
        node: any NodeProtocol,
        screenPos: CGPoint,
        zoomScale: CGFloat,
        tablePosition: CGPoint?,
        isInGrid: Bool = false,
        gridPosition: (row: Int, col: Int)? = nil
    ) {
        guard !node.contents.isEmpty, zoomScale >= 0.5 else { return }

        let contentText = node.contents[0].displayText
        // Use larger font and higher contrast for grid labels
        let fontSize = isInGrid ? max(7, 11 * zoomScale) : max(6, 9 * zoomScale)
        let opacity = isInGrid ? 1.0 : 0.8
        
        let contentLabel = Text(contentText)
            .font(.system(size: fontSize))
            .foregroundColor(.white.opacity(opacity))

        let contentPos: CGPoint
        if let tablePos = tablePosition {
            // Seated at table: radial label positioning
            // swiftlint:disable:next identifier_name
            let dx = person.position.x - tablePos.x
            // swiftlint:disable:next identifier_name
            let dy = person.position.y - tablePos.y
            let distance = sqrt(dx * dx + dy * dy)

            #if DEBUG
            print("🧍 Person '\(contentText)' at model(\(person.position.x),\(person.position.y)) near table at model(\(tablePos.x),\(tablePos.y))")
            print("   Distance from table center: \(distance)pt, dx=\(dx), dy=\(dy)")
            print("   Screen position: (\(screenPos.x),\(screenPos.y)), zoom=\(zoomScale)")
            #endif
            if distance > 0.1 {
                let dirX = dx / distance
                let dirY = dy / distance
                let labelOffset = (node.radius + 10) * zoomScale
                contentPos = CGPoint(
                    x: screenPos.x + dirX * labelOffset,
                    y: screenPos.y + dirY * labelOffset
                )
            } else {
                contentPos = CGPoint(x: screenPos.x, y: screenPos.y + (node.radius + 10) * zoomScale)
            }
        } else if isInGrid {
            // In table: labels inline to the right of nodes
            let labelOffset = (node.radius + 10) * zoomScale
            contentPos = CGPoint(
                x: screenPos.x + labelOffset,
                y: screenPos.y
            )
        } else {
            // Standalone: vertical label positioning (below)
            contentPos = CGPoint(x: screenPos.x, y: screenPos.y + (node.radius + 10) * zoomScale)
        }
        
        // Anchor depends on position: table labels use .leading, others use .center
        let anchor: UnitPoint = isInGrid ? .leading : .center
        
        context.draw(contentLabel, at: contentPos, anchor: anchor)
    }

    static func drawTableLabel(
        context: GraphicsContext,
        table: TableNode,
        node: any NodeProtocol,
        screenPos: CGPoint,
        zoomScale: CGFloat
    ) {
        guard !node.contents.isEmpty, zoomScale >= 0.5 else { return }

        let contentText = node.contents[0].displayText
        let contentLabel = Text(contentText)
            .font(.system(size: max(6, 9 * zoomScale)))
            .foregroundColor(.white.opacity(0.8))
        let contentPos = CGPoint(x: screenPos.x, y: screenPos.y + (table.tableLength / 2 + 10) * zoomScale)
        context.draw(contentLabel, at: contentPos, anchor: .center)
    }

    static func drawRegularNodeLabels(
        context: GraphicsContext,
        node: any NodeProtocol,
        screenPos: CGPoint,
        zoomScale: CGFloat
    ) {
        let labelText = Text("\(node.label)")
            .font(.system(size: max(8, 12 * zoomScale), weight: .bold))
            .foregroundColor(.white)
        let labelPos = CGPoint(x: screenPos.x, y: screenPos.y - (node.radius + 12) * zoomScale)
        context.draw(labelText, at: labelPos, anchor: .center)

        if !node.contents.isEmpty, zoomScale >= 0.5 {
            let contentText = node.contents[0].displayText
            let contentLabel = Text(contentText)
                .font(.system(size: max(6, 9 * zoomScale)))
                .foregroundColor(.white.opacity(0.8))
            let contentPos = CGPoint(x: screenPos.x, y: screenPos.y + (node.radius + 10) * zoomScale)
            context.draw(contentLabel, at: contentPos, anchor: .center)
        }
    }
}
