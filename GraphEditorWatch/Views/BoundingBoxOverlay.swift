//
//  BoundingBoxOverlay.swift
//  GraphEditor
//
//  Created by handcart on 11/6/25.
//

import SwiftUI
import GraphEditorShared

struct BoundingBoxOverlay: View {
    let viewModel: GraphViewModel
    let zoomScale: CGFloat
    let offset: CGSize
    let viewSize: CGSize
    
    var body: some View {
        let graphBounds = viewModel.model.physicsEngine.boundingBox(nodes: viewModel.model.nodes)
        let minScreen = CoordinateTransformer.modelToScreen(
            CGPoint(x: graphBounds.minX, y: graphBounds.minY),
            effectiveCentroid: viewModel.effectiveCentroid,
            zoomScale: zoomScale,
            offset: offset,
            viewSize: viewSize
        )
        let maxScreen = CoordinateTransformer.modelToScreen(
            CGPoint(x: graphBounds.maxX, y: graphBounds.maxY),
            effectiveCentroid: viewModel.effectiveCentroid,
            zoomScale: zoomScale,
            offset: offset,
            viewSize: viewSize
        )
        let scaledBounds = CGRect(x: minScreen.x, y: minScreen.y, width: maxScreen.x - minScreen.x, height: maxScreen.y - minScreen.y)
        Rectangle()
            .stroke(Color.blue, lineWidth: 2)
            .frame(width: scaledBounds.width, height: scaledBounds.height)
            .position(x: scaledBounds.midX, y: scaledBounds.midY)
            .opacity(0.5)
    }
}
