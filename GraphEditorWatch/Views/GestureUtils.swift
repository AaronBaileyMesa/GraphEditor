// GestureUtils.swift
// Extracted utilities for hit testing and distance calculations

import SwiftUI
import GraphEditorShared

struct GestureUtils {
    static func closestNode(at screenPos: CGPoint, visibleNodes: [any NodeProtocol], context: GraphEditorShared.HitTestContext) -> (any NodeProtocol)? {
        var closest: (any NodeProtocol)?
        var minDist: CGFloat = .infinity
        let adjustedRadius = AppConstants.hitScreenRadius / max(1.0, context.zoomScale) * 2.0  // Double boost at zoom >1; tune to 3.0 if needed
        #if os(watchOS)
        let boostedRadius = adjustedRadius * 2.0  // Extra for watch touch (fingers obscure)
        #endif
        for node in visibleNodes {
            let nodeScreen = CoordinateTransformer.modelToScreen(
                node.position,
                effectiveCentroid: context.effectiveCentroid,
                zoomScale: context.zoomScale,
                offset: context.offset,
                viewSize: context.viewSize
            )
            let dist = hypot(screenPos.x - nodeScreen.x, screenPos.y - nodeScreen.y)
            if dist < boostedRadius && dist < minDist {
                minDist = dist
                closest = node
            }
        }
        return closest
    }
    
    static func closestEdge(at screenPos: CGPoint, visibleEdges: [GraphEdge], visibleNodes: [any NodeProtocol], context: HitTestContext) -> GraphEdge? {
        var closestEdge: GraphEdge?
        var minDist: CGFloat = .infinity
        for edge in visibleEdges {
            guard let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
                  let targetNode = visibleNodes.first(where: { $0.id == edge.target }) else { continue }
            
            let fromScreen = CoordinateTransformer.modelToScreen(
                fromNode.position,
                effectiveCentroid: context.effectiveCentroid,
                zoomScale: context.zoomScale,
                offset: context.offset,
                viewSize: context.viewSize
            )
            let toScreen = CoordinateTransformer.modelToScreen(
                targetNode.position,
                effectiveCentroid: context.effectiveCentroid,
                zoomScale: context.zoomScale,
                offset: context.offset,
                viewSize: context.viewSize
            )
            
            let dist = pointToLineDistance(point: screenPos, from: fromScreen, to: toScreen)
            let hitThreshold: CGFloat = 20.0
            if dist < hitThreshold && dist < minDist {
                minDist = dist
                closestEdge = edge
            }
        }
        return closestEdge
    }
    
    static func pointToLineDistance(point: CGPoint, from startPoint: CGPoint, to endPoint: CGPoint) -> CGFloat {
        let pointX = Double(point.x), pointY = Double(point.y)
        let startX = Double(startPoint.x), startY = Double(startPoint.y)
        let endX = Double(endPoint.x), endY = Double(endPoint.y)
        
        let lineVecX = endX - startX
        let lineVecY = endY - startY
        let lineLen = hypot(lineVecX, lineVecY)
        
        if lineLen == 0 {
            return hypot(point.x - startPoint.x, point.y - startPoint.y)
        }
        
        let pointVecX = pointX - startX
        let pointVecY = pointY - startY
        let dot = pointVecX * lineVecX + pointVecY * lineVecY
        let denom = lineLen * lineLen
        let projectionParam = dot / denom
        let clampedParam = max(0.0, min(1.0, projectionParam))
        
        let projX = startX + lineVecX * clampedParam
        let projY = startY + lineVecY * clampedParam
        
        let proj = CGPoint(x: CGFloat(projX), y: CGFloat(projY))
        return hypot(point.x - proj.x, point.y - proj.y)
    }
    
    static func modelToScreen(_ modelPos: CGPoint, context: HitTestContext) -> CGPoint {
        return CoordinateTransformer.modelToScreen(
            modelPos,
            effectiveCentroid: context.effectiveCentroid,
            zoomScale: context.zoomScale,
            offset: context.offset,
            viewSize: context.viewSize
        )
    }
    
    // Add any other utility functions extracted from the original file here
}
