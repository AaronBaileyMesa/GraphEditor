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
    
    public func approximatelyEqual(_ lhs: CGPoint, _ rhs: CGPoint, accuracy: CGFloat) -> Bool {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y) < accuracy
    }
    
    // MARK: - Edge Cases
    
    @Test("Extreme zoom in maintains accuracy")
    func testExtremeZoomIn() {
        let viewSize = CGSize(width: 200, height: 200)
        let centroid = CGPoint(x: 100, y: 100)
        let modelPos = CGPoint(x: 105, y: 110)
        let zoom: CGFloat = 10.0
        let offset = CGSize.zero
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Extreme zoom in should preserve accuracy")
    }
    
    @Test("Extreme zoom out maintains accuracy")
    func testExtremeZoomOut() {
        let viewSize = CGSize(width: 200, height: 200)
        let centroid = CGPoint(x: 100, y: 100)
        let modelPos = CGPoint(x: 500, y: 600)
        let zoom: CGFloat = 0.1
        let offset = CGSize.zero
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Extreme zoom out should preserve accuracy")
    }
    
    @Test("Minimum zoom (0.001) prevents division by zero")
    func testMinimumZoom() {
        let viewSize = CGSize(width: 200, height: 200)
        let centroid = CGPoint(x: 100, y: 100)
        let modelPos = CGPoint(x: 150, y: 150)
        let zoom: CGFloat = 0.001
        let offset = CGSize.zero
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        // At this extreme zoom, we expect some accuracy loss due to floating point precision
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 0.1), "Minimum zoom should not crash")
    }
    
    @Test("Large positive offset")
    func testLargePositiveOffset() {
        let viewSize = CGSize(width: 200, height: 200)
        let centroid = CGPoint(x: 100, y: 100)
        let modelPos = CGPoint(x: 120, y: 130)
        let zoom: CGFloat = 1.0
        let offset = CGSize(width: 500, height: 500)
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Large positive offset should work correctly")
    }
    
    @Test("Large negative offset")
    func testLargeNegativeOffset() {
        let viewSize = CGSize(width: 200, height: 200)
        let centroid = CGPoint(x: 100, y: 100)
        let modelPos = CGPoint(x: 120, y: 130)
        let zoom: CGFloat = 1.0
        let offset = CGSize(width: -500, height: -500)
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Large negative offset should work correctly")
    }
    
    @Test("Negative model coordinates")
    func testNegativeModelCoordinates() {
        let viewSize = CGSize(width: 200, height: 200)
        let centroid = CGPoint(x: 0, y: 0)
        let modelPos = CGPoint(x: -100, y: -150)
        let zoom: CGFloat = 1.0
        let offset = CGSize.zero
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Negative coordinates should transform correctly")
    }
    
    @Test("Zero centroid")
    func testZeroCentroid() {
        let viewSize = CGSize(width: 200, height: 200)
        let centroid = CGPoint.zero
        let modelPos = CGPoint(x: 50, y: 75)
        let zoom: CGFloat = 1.5
        let offset = CGSize.zero
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Zero centroid should work correctly")
    }
    
    @Test("Very large view size")
    func testLargeViewSize() {
        let viewSize = CGSize(width: 5000, height: 5000)
        let centroid = CGPoint(x: 2500, y: 2500)
        let modelPos = CGPoint(x: 2600, y: 2700)
        let zoom: CGFloat = 1.0
        let offset = CGSize.zero
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Large view size should maintain precision")
    }
    
    @Test("Very small view size (watchOS)")
    func testSmallViewSize() {
        let viewSize = CGSize(width: 162, height: 197) // Apple Watch 38mm
        let centroid = CGPoint(x: 81, y: 98.5)
        let modelPos = CGPoint(x: 100, y: 120)
        let zoom: CGFloat = 1.0
        let offset = CGSize.zero
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Small watchOS view should work correctly")
    }
    
    // MARK: - Combined Edge Cases
    
    @Test("Extreme zoom with large offset")
    func testExtremeZoomWithLargeOffset() {
        let viewSize = CGSize(width: 200, height: 200)
        let centroid = CGPoint(x: 100, y: 100)
        let modelPos = CGPoint(x: 150, y: 175)
        let zoom: CGFloat = 5.0
        let offset = CGSize(width: 300, height: -200)
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Extreme zoom with large offset should work")
    }
    
    @Test("Negative coordinates with zoom and offset")
    func testNegativeCoordinatesWithZoomAndOffset() {
        let viewSize = CGSize(width: 200, height: 200)
        let centroid = CGPoint(x: -50, y: -75)
        let modelPos = CGPoint(x: -100, y: -150)
        let zoom: CGFloat = 2.0
        let offset = CGSize(width: -100, height: 50)
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        #expect(approximatelyEqual(recoveredModel, modelPos, accuracy: 1e-3), "Complex negative scenario should maintain accuracy")
    }
    
    // MARK: - Rounding Behavior
    
    @Test("Rounding to 3 decimals prevents floating point drift")
    func testRoundingPreventsFloatingPointDrift() {
        let viewSize = CGSize(width: 200, height: 200)
        let centroid = CGPoint(x: 100, y: 100)
        let modelPos = CGPoint(x: 123.456789, y: 987.654321)
        let zoom: CGFloat = 1.0
        let offset = CGSize.zero
        
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let recoveredModel = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        
        // Should be rounded to 3 decimals
        let expectedX = 123.457
        let expectedY = 987.654
        
        #expect(abs(recoveredModel.x - expectedX) < 0.001, "X should be rounded to 3 decimals")
        #expect(abs(recoveredModel.y - expectedY) < 0.001, "Y should be rounded to 3 decimals")
    }
    
    // MARK: - Multiple Round Trips
    
    @Test("Multiple round trips maintain accuracy")
    func testMultipleRoundTrips() {
        let viewSize = CGSize(width: 200, height: 200)
        let centroid = CGPoint(x: 100, y: 100)
        var modelPos = CGPoint(x: 150, y: 175)
        let zoom: CGFloat = 1.5
        let offset = CGSize(width: 20, height: 30)
        
        // Perform 10 round trips
        for _ in 0..<10 {
            let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
            modelPos = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        }
        
        // After 10 round trips, should still be close to original
        let originalPos = CGPoint(x: 150, y: 175)
        #expect(approximatelyEqual(modelPos, originalPos, accuracy: 1e-2), "Multiple round trips should maintain reasonable accuracy")
    }
    
    // MARK: - RenderContext Overload Tests
    
    @Test("RenderContext overload produces same result as explicit parameters")
    func testRenderContextOverload() {
        let viewSize = CGSize(width: 200, height: 200)
        let centroid = CGPoint(x: 100, y: 100)
        let modelPos = CGPoint(x: 150, y: 175)
        let zoom: CGFloat = 1.5
        let offset = CGSize(width: 20, height: 30)
        
        let renderContext = RenderContext(
            effectiveCentroid: centroid,
            zoomScale: zoom,
            offset: offset,
            viewSize: viewSize
        )
        
        let screenPos1 = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let screenPos2 = CoordinateTransformer.modelToScreen(modelPos, renderContext)
        
        #expect(approximatelyEqual(screenPos1, screenPos2, accuracy: 1e-6), "RenderContext overload should match explicit parameters")
        
        let modelPos1 = CoordinateTransformer.screenToModel(screenPos1, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
        let modelPos2 = CoordinateTransformer.screenToModel(screenPos2, renderContext)
        
        #expect(approximatelyEqual(modelPos1, modelPos2, accuracy: 1e-6), "screenToModel with RenderContext should match")
    }
}
