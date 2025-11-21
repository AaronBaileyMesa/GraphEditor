//
//  at.swift
//  GraphEditor
//
//  Created by handcart on 11/19/25.
//

import GraphEditorShared
import os  // Added for optimized logging
import SwiftUI

extension CoordinateTransformer {
    static func modelToScreen(_ modelPos: CGPoint, in renderContext: RenderContext) -> CGPoint {
        return modelToScreen(
            modelPos,
            effectiveCentroid: renderContext.effectiveCentroid,
            zoomScale: renderContext.zoomScale,
            offset: renderContext.offset,
            viewSize: renderContext.viewSize
        )
    }
}
