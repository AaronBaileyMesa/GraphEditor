//
//  ContentView.swift
//  GraphEditorWatch
//

import SwiftUI
import WatchKit
import GraphEditorShared
import os

struct ContentView: View {
    private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "contentview")
    
    @ObservedObject var viewModel: GraphViewModel
    
    // Local gesture/UI state only
    @State private var draggedNode: (any NodeProtocol)? 
    @State private var dragOffset: CGPoint = .zero
    @State private var currentDragLocation: CGPoint? // Live finger position during drag
    @State private var dragStartNode: (any NodeProtocol)?  // Starting node for edge preview
    @State private var potentialEdgeTarget: (any NodeProtocol)?
    @State private var selectedNodeID: NodeID?
    @State private var selectedEdgeID: UUID?
    @State private var panStartOffset: CGSize?
    @State private var showMenu: Bool = false
    @State private var showOverlays: Bool = false
    @FocusState private var canvasFocus: Bool
    @State private var wristSide: WKInterfaceDeviceWristLocation = .left
    @State private var showEditSheet: Bool = false
    @State private var isAddingEdge: Bool = false
    @State private var viewSize: CGSize = .zero
    @State private var isSimulating: Bool = false
    @State private var saturation: Double = 1.0
    
    // Crown binding comes straight from the environment
    @State private var crownAccumulator: Double = Double(AppConstants.crownZoomSteps) / 2.0   // ← NEW
    
    private var minZoom: CGFloat { AppConstants.defaultMinZoom }
    private var maxZoom: CGFloat { AppConstants.defaultMaxZoom }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                GraphCanvasView(
                    viewModel: viewModel,
                    draggedNode: Binding(get: { draggedNode }, set: { draggedNode = $0 }),
                    dragOffset: $dragOffset,
                    potentialEdgeTarget: Binding(get: { potentialEdgeTarget }, set: { potentialEdgeTarget = $0 }),
                    selectedNodeID: Binding(
                        get: { selectedNodeID },
                        set: { newValue in
                            selectedNodeID = newValue
                            viewModel.selectedNodeID = newValue
                        }
                    ),
                    selectedEdgeID: Binding(
                        get: { selectedEdgeID },
                        set: { newValue in
                            selectedEdgeID = newValue
                            viewModel.selectedEdgeID = newValue
                        }
                    ),
                    viewSize: $viewSize,
                    panStartOffset: $panStartOffset,
                    showMenu: $showMenu,
                    onUpdateZoomRanges: { },
                    isAddingEdge: $isAddingEdge,
                    isSimulating: $isSimulating,
                    saturation: $saturation,
                    crownPosition: $crownAccumulator,
                    currentDragLocation: $currentDragLocation,
                        dragStartNode: $dragStartNode
                )
            }
            .onAppear {
                viewSize = geo.size
                wristSide = WKInterfaceDevice.current().wristLocation
                canvasFocus = true
                Task { await viewModel.resumeSimulation() }
                viewModel.resetViewToFitGraph(viewSize: geo.size)
                let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: geo.size)
                    let normalized = (viewModel.zoomScale - minZoom) / (maxZoom - minZoom)
                    crownAccumulator = Double(AppConstants.crownZoomSteps) * normalized.clamped(to: 0...1)
                // Crown → zoom sync is now handled inside GraphCanvasView
            }
            .focused($canvasFocus)
        }
        .ignoresSafeArea(edges: [.leading, .trailing, .top, .bottom])
        .onChange(of: viewSize) { _, newSize in
            viewModel.resetViewToFitGraph(viewSize: newSize)
        }
        .digitalCrownRotation($crownAccumulator)   // ← OFFICIAL API
                .onChange(of: crownAccumulator) {_, newValue in handleCrownRotation(newValue) }
                .onChange(of: viewModel.zoomScale) {_, newZoom in
                    guard viewSize.width > 50 else { return } // Skip until we have real size
                    syncZoomToCrown(newZoom)
                }
        // Menu sheet
        .sheet(isPresented: $showMenu) {
            NavigationStack {
                MenuView(
                    viewModel: viewModel,
                    isSimulatingBinding: $isSimulating,
                    onCenterGraph: centerGraph,
                    showMenu: $showMenu,
                    showOverlays: $showOverlays,
                    selectedNodeID: Binding(
                        get: { selectedNodeID },
                        set: { selectedNodeID = $0; viewModel.selectedNodeID = $0 }
                    ),
                    selectedEdgeID: Binding(
                        get: { selectedEdgeID },
                        set: { selectedEdgeID = $0; viewModel.selectedEdgeID = $0 }
                    )
                )
                .navigationBarTitleDisplayMode(.inline)
            }
            .onDisappear {
                withAnimation(.easeInOut(duration: 0.2)) {
                    saturation = 1.0
                }
            }
        }
    }
    
    private func handleCrownRotation(_ value: Double) {
            let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
            let normalized = (value / Double(AppConstants.crownZoomSteps)).clamped(to: 0...1)
            let targetZoom = minZoom + (maxZoom - minZoom) * CGFloat(normalized)
            withAnimation(.easeOut(duration: 0.08)) { viewModel.zoomScale = targetZoom }
        }
        
        private func syncZoomToCrown(_ zoom: CGFloat) {
            let (minZoom, maxZoom) = viewModel.calculateZoomRanges(for: viewSize)
            let normalized = ((zoom - minZoom) / (maxZoom - minZoom)).clamped(to: 0...1)
            let target = Double(AppConstants.crownZoomSteps) * normalized
            if abs(target - crownAccumulator) > 0.5 {
                crownAccumulator = target
            }
        }
    
    private func centerGraph() {
        guard viewSize.width > 0 else { return }
        
        let oldCentroid = viewModel.effectiveCentroid
        viewModel.resetViewToFitGraph(viewSize: viewSize)
        let newCentroid = viewModel.effectiveCentroid
        
        let centroidShift = CGSize(
            width: (oldCentroid.x - newCentroid.x) * viewModel.zoomScale,
            height: (oldCentroid.y - newCentroid.y) * viewModel.zoomScale
        )
        
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.offset = CGSize(
                width: viewModel.offset.width  + centroidShift.width,
                height: viewModel.offset.height + centroidShift.height
            )
        }
        
        #if DEBUG
        logger.debug("Centering graph – oldCentroid: (\(oldCentroid.x), \(oldCentroid.y)), newCentroid: (\(newCentroid.x), \(newCentroid.y)), shift: (\(centroidShift.width), \(centroidShift.height))")
        #endif
    }
}

// Keep the clamped helper (used elsewhere too)
extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
