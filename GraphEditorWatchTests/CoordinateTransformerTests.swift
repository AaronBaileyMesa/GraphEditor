//
//  CoordinateTransformerTests.swift
//  GraphEditor
//
//  Created by handcart on 9/22/25.
//
import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
@testable import GraphEditorShared
import XCTest
import SwiftUI

struct CoordinateTransformerTests {
    @Test func testCoordinateRoundTrip() {
        let viewSize = CGSize(width: 205, height: 251)
        let centroid = CGPoint(x: 150, y: 150)
        let modelPos = CGPoint(x: 167.78, y: 165.66)
        let zoom: CGFloat = 1.0
        let offset = CGSize.zero
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Round-trip should match original model position")
    }
    
    @Test func testCoordinateRoundTripWithZoomAndOffset() {
        let viewSize = CGSize(width: 205, height: 251)
        let centroid = CGPoint(x: 56.73, y: 161.10)
        let modelPos = CGPoint(x: -40.27, y: 52.60)
        let zoom: CGFloat = 1.0
        let offset = CGSize(width: 81, height: 111.5)
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Round-trip with zoom and offset should match")
    }
}
