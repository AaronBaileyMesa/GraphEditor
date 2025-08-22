//  ContentView.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.

import SwiftUI
import WatchKit
import GraphEditorShared
import Foundation
import CoreGraphics  // For CGRect in clampOffset

struct ViewSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct NodeWrapper: Equatable {
    var node: (any NodeProtocol)?
    static func == (lhs: NodeWrapper, rhs: NodeWrapper) -> Bool {
        lhs.node?.id == rhs.node?.id
    }
}

struct InnerViewConfig {
    let geo: GeometryProxy
    let viewModel: GraphViewModel
    let zoomScale: Binding<CGFloat>
    let offset: Binding<CGSize>
    let draggedNode: Binding<NodeWrapper>
    let dragOffset: Binding<CGPoint>
    let potentialEdgeTarget: Binding<NodeWrapper>
    let panStartOffset: Binding<CGSize?>
    let showMenu: Binding<Bool>
    let showOverlays: Binding<Bool>
    let maxZoom: CGFloat
    let crownPosition: Binding<Double>
    let updateZoomRangesHandler: () -> Void
    let selectedNodeID: Binding<NodeID?>
    let selectedEdgeID: Binding<UUID?>
    let canvasFocus: FocusState<Bool>.Binding  // Non-optional
    let onCenterGraph: () -> Void
}

struct ContentView: View {
    @StateObject var viewModel: GraphViewModel
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var draggedNode: NodeWrapper = NodeWrapper(node: nil)
    @State private var dragOffset: CGPoint = .zero
    @State private var potentialEdgeTarget: NodeWrapper = NodeWrapper(node: nil)
    @State private var panStartOffset: CGSize? = nil
    @State private var showMenu: Bool = false
    @State private var showOverlays = false
    @State private var minZoom: CGFloat = 0.1
    @State private var maxZoom: CGFloat = 2.5
    @State private var crownPosition: Double = 0.5
    @State private var ignoreNextCrownChange: Bool = false
    @State private var isZooming: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var previousCrownPosition: Double = 0.5
    @State private var clampTimer: Timer?
    @State private var resumeTimer: Timer? = nil
    @State private var logOffsetChanges = true
    @State private var isPanning: Bool = false
    @State private var zoomTimer: Timer? = nil
    @State private var isLoaded: Bool = false
    @State private var previousSelection: (NodeID?, UUID?) = (nil, nil)
    @State private var viewSize: CGSize = .zero
    @FocusState private var isCanvasFocused: Bool
    
    init(storage: GraphStorage = PersistenceManager(),
         physicsEngine: PhysicsEngine = PhysicsEngine(simulationBounds: WKInterfaceDevice.current().screenBounds.size)) {
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        _viewModel = StateObject(wrappedValue: GraphViewModel(model: model))
    }
    
    private func recenterOn(position: CGPoint) {
        let centroid = viewModel.effectiveCentroid
        let targetOffsetX = -(position.x - centroid.x) * zoomScale
        let targetOffsetY = -(position.y - centroid.y) * zoomScale
        withAnimation {
            offset = CGSize(width: targetOffsetX, height: targetOffsetY)
        }
    }
    
    private func adjustedOffset(for newZoom: CGFloat, currentCenter: CGPoint) -> CGSize {
        let newOffsetX = -(currentCenter.x * newZoom - viewSize.width / 2)
        let newOffsetY = -(currentCenter.y * newZoom - viewSize.height / 2)
        return CGSize(width: newOffsetX, height: newOffsetY)
    }
    
    private func onUpdateZoomRanges() {
        let graphBounds = viewModel.model.physicsEngine.boundingBox(nodes: viewModel.model.nodes)
        let contentWidth = graphBounds.width + 2 * Constants.App.contentPadding  // Add padding for margins
        let contentHeight = graphBounds.height + 2 * Constants.App.contentPadding
        minZoom = min(viewSize.width / contentWidth, viewSize.height / contentHeight)
        maxZoom = Constants.App.maxZoom
        
        // New: Auto-fit if not loaded or zoom is default (integrates with saved state)
        if !isLoaded || zoomScale == 1.0 {
            zoomScale = min(minZoom * 1.1, maxZoom)  // Slight buffer to avoid over-tight fit
            clampOffset(animate: false)  // Center without animation on init
        }
    }
    
    private func clampOffset(animate: Bool = true) {
        let oldOffset = offset
        let graphBounds = viewModel.model.physicsEngine.boundingBox(nodes: viewModel.model.nodes)
        let scaledWidth = (graphBounds.width * zoomScale).rounded(to: 2)
        let scaledHeight = (graphBounds.height * zoomScale).rounded(to: 2)
        let effectiveViewWidth = viewSize.width
        let effectiveViewHeight = viewSize.height
        let extraPadding: CGFloat = 50.0
        let panRoomX = max(0, (scaledWidth - effectiveViewWidth) / 2 + extraPadding)
        let panRoomY = max(0, (scaledHeight - effectiveViewHeight) / 2 + extraPadding)
        let threshold: CGFloat = 50.0  // Only clamp if exceeding by this much
        
        var clampedX = offset.width
        var clampedY = offset.height
        
        if abs(offset.width) > panRoomX + threshold {
            clampedX = offset.width.clamped(to: -panRoomX...panRoomX).rounded(to: 2)
        }
        if abs(offset.height) > panRoomY + threshold {
            clampedY = offset.height.clamped(to: -panRoomY...panRoomY).rounded(to: 2)
        }
        if scaledWidth <= effectiveViewWidth { clampedX = 0 }
        if scaledHeight <= effectiveViewHeight { clampedY = 0 }
        
        let newOffset = CGSize(width: clampedX, height: clampedY)
        if animate {
            withAnimation(.easeOut(duration: 0.2)) {
                offset = newOffset
            }
        } else {
            offset = newOffset
        }
        if logOffsetChanges && (abs(offset.width - oldOffset.width) > 0.01 || abs(offset.height - oldOffset.height) > 0.01) {
            print("ClampOffset adjusted from width \(oldOffset.width), height \(oldOffset.height) to width \(offset.width), height \(offset.height). Triggered by deselection? \(viewModel.selectedNodeID == nil && viewModel.selectedEdgeID == nil)")
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            // Remove: let _ = { self.viewSize = geo.size }()
            let g1 = (geo: geo, viewModel: viewModel)
            let g2 = (zoomScale: $zoomScale, offset: $offset)
            let g3 = (draggedNode: $draggedNode, dragOffset: $dragOffset)
            let g4 = (potentialEdgeTarget: $potentialEdgeTarget, panStartOffset: $panStartOffset)
            let g5 = (showMenu: $showMenu, showOverlays: $showOverlays)
            let g6 = (maxZoom: maxZoom, crownPosition: $crownPosition)
            let g7 = (updateZoomRangesHandler: { onUpdateZoomRanges() }, selectedNodeID: $viewModel.selectedNodeID)
            let g8 = (selectedEdgeID: $viewModel.selectedEdgeID, canvasFocus: $isCanvasFocused)
            let g9 = {
                recenterOn(position: viewModel.effectiveCentroid)
                clampOffset()
            }
            
            let config = InnerViewConfig(
                geo: g1.geo,
                viewModel: g1.viewModel,
                zoomScale: g2.zoomScale,
                offset: g2.offset,
                draggedNode: g3.draggedNode,
                dragOffset: g3.dragOffset,
                potentialEdgeTarget: g4.potentialEdgeTarget,
                panStartOffset: g4.panStartOffset,
                showMenu: g5.showMenu,
                showOverlays: g5.showOverlays,
                maxZoom: g6.maxZoom,
                crownPosition: g6.crownPosition,
                updateZoomRangesHandler: g7.updateZoomRangesHandler,
                selectedNodeID: g7.selectedNodeID,
                selectedEdgeID: g8.selectedEdgeID,
                canvasFocus: g8.canvasFocus,
                onCenterGraph: g9
            )
            
            InnerView(config: config)
                .preference(key: ViewSizeKey.self, value: geo.size)  // Pass size via preference
        }
        .ignoresSafeArea(.all, edges: .all)
        .onPreferenceChange(ViewSizeKey.self) { newSize in
            viewSize = newSize  // Safe: Runs after view commit
        }
        .onAppear {
            viewModel.loadViewState()
            onUpdateZoomRanges()
            isLoaded = true
            recenterOn(position: viewModel.effectiveCentroid)
            viewModel.model.startSimulation()  // Ensure simulation runs on load
        }
        .focusable(true)
        .digitalCrownRotation($crownPosition, from: 0.0, through: 1.0, sensitivity: .medium, isContinuous: true, isHapticFeedbackEnabled: true)
        .onChange(of: crownPosition) { newValue in
            zoomTimer?.invalidate()
            zoomTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: false) { _ in
                onUpdateZoomRanges()
                let zoomSensitivity: CGFloat = 2.0
                let normalized = CGFloat(newValue)
                let newZoom = minZoom * pow(maxZoom / minZoom, normalized * zoomSensitivity)
                let clampedNewZoom = newZoom.clamped(to: minZoom...maxZoom).rounded(to: 3)
                
                guard clampedNewZoom > 0.001 else {
                    zoomScale = minZoom
                    return
                }
                
                let screenCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
                let safeZoom = max(zoomScale, 0.001)
                let preZoomModelCenter = CGPoint(
                    x: (screenCenter.x - offset.width) / safeZoom + viewModel.effectiveCentroid.x,
                    y: (screenCenter.y - offset.height) / safeZoom + viewModel.effectiveCentroid.y
                )
                
                zoomScale = clampedNewZoom
                
                let postZoomOffsetX = screenCenter.x - preZoomModelCenter.x * clampedNewZoom + viewModel.effectiveCentroid.x * clampedNewZoom
                let postZoomOffsetY = screenCenter.y - preZoomModelCenter.y * clampedNewZoom + viewModel.effectiveCentroid.y * clampedNewZoom
                offset = CGSize(width: postZoomOffsetX.isFinite ? postZoomOffsetX : 0,
                               height: postZoomOffsetY.isFinite ? postZoomOffsetY : 0)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    clampOffset(animate: true)
                }
                
                isZooming = true
                zoomTimer?.invalidate()
                zoomTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                    isZooming = false
                    viewModel.model.isSimulating = true
                    viewModel.model.startSimulation()
                }
            }
        }
        .onChange(of: showMenu) { newValue in
            print("Show menu changed to \(newValue)")
            if !newValue {
                isCanvasFocused = true
            }
        }
        .onChange(of: isCanvasFocused) { newValue in
            print("Canvas focus changed to \(newValue)")
        }
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}

#Preview {
    ContentView()
}

struct InnerView: View {
    let config: InnerViewConfig
    
    var body: some View {
        let draggedNodeBinding = Binding<(any NodeProtocol)?>(
            get: { config.draggedNode.wrappedValue.node },
            set: { config.draggedNode.wrappedValue = NodeWrapper(node: $0) }
        )
        let potentialEdgeTargetBinding = Binding<(any NodeProtocol)?>(
            get: { config.potentialEdgeTarget.wrappedValue.node },
            set: { config.potentialEdgeTarget.wrappedValue = NodeWrapper(node: $0) }
        )
        let isSimulatingBinding = Binding.constant(config.viewModel.model.isSimulating)
        
        let canvasView: some View = GraphCanvasView(
            viewModel: config.viewModel,
            zoomScale: config.zoomScale,
            offset: config.offset,
            draggedNode: draggedNodeBinding,
            dragOffset: config.dragOffset,
            potentialEdgeTarget: potentialEdgeTargetBinding,
            selectedNodeID: config.selectedNodeID,
            viewSize: config.geo.size,
            panStartOffset: config.panStartOffset,
            showMenu: config.showMenu,
            maxZoom: config.maxZoom,
            crownPosition: config.crownPosition,
            onUpdateZoomRanges: config.updateZoomRangesHandler,
            selectedEdgeID: config.selectedEdgeID,
            showOverlays: config.showOverlays
        )
        .accessibilityIdentifier("GraphCanvas")
        .focused(config.canvasFocus)
        .focusable(true)

         if config.showMenu.wrappedValue {
             MenuView(
                 viewModel: config.viewModel,
                 showOverlays: config.showOverlays,
                 showMenu: config.showMenu,
                 onCenterGraph: config.onCenterGraph
             )
             .navigationTitle("Menu")  // Optional: Improve navigation
         } else {
             canvasView
         }
    }
}
