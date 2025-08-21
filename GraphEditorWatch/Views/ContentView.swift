//  ContentView.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.

import SwiftUI
import WatchKit
import GraphEditorShared
import Foundation
import CoreGraphics  // For CGRect in clampOffset

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
    let canvasFocus: FocusState<Bool>.Binding  // Use correct type for focus
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
        let newOffsetX = -(currentCenter.x - viewSize.width / (2 * newZoom)) * newZoom
        let newOffsetY = -(currentCenter.y - viewSize.height / (2 * newZoom)) * newZoom
        print("Adjusted offset to preserve center: (\(newOffsetX), \(newOffsetY))")
        return CGSize(width: newOffsetX, height: newOffsetY)
    }
    
    private func clampOffset(animate: Bool = true) {
        let oldOffset = offset
        let graphBounds = viewModel.model.physicsEngine.boundingBox(nodes: viewModel.model.nodes)
        let scaledWidth = (graphBounds.width * zoomScale).rounded(to: 2)
        let scaledHeight = (graphBounds.height * zoomScale).rounded(to: 2)
        let effectiveViewWidth = viewSize.width
        let effectiveViewHeight = viewSize.height
        let extraPadding: CGFloat = 200.0  // Large: Allow off-screen panning
        let panRoomX = max(0, (scaledWidth - effectiveViewWidth) / 2 + extraPadding)
        let panRoomY = max(0, (scaledHeight - effectiveViewHeight) / 2 + extraPadding)
        let threshold: CGFloat = 100.0  // Higher: Only clamp if far off
        
        var clampedX = offset.width
        var clampedY = offset.height
        
        // Skip clamp if zoomed out (allow free pan)
        if scaledWidth < effectiveViewWidth || scaledHeight < effectiveViewHeight {
            // Only force center if extremely off (e.g., graph invisible)
            if abs(offset.width) > effectiveViewWidth || abs(offset.height) > effectiveViewHeight {
                clampedX = 0
                clampedY = 0
            }
        } else if abs(offset.width) > panRoomX + threshold {
            clampedX = offset.width.clamped(to: -panRoomX...panRoomX).rounded(to: 2)
        } else if abs(offset.height) > panRoomY + threshold {
            clampedY = offset.height.clamped(to: -panRoomY...panRoomY).rounded(to: 2)
        }
        
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
    private func onUpdateZoomRanges() {
        let graphBounds = viewModel.model.physicsEngine.boundingBox(nodes: viewModel.model.nodes)
        let padding: CGFloat = 20.0
        let contentWidth = graphBounds.width + padding * 2
        let contentHeight = graphBounds.height + padding * 2
        maxZoom = 2.5
        zoomScale = zoomScale.clamped(to: minZoom...maxZoom)
        clampOffset()
    }
        
    var body: some View {
        GeometryReader { geo in
            InnerView(
                config: InnerViewConfig(
                    geo: geo,
                    viewModel: viewModel,
                    zoomScale: $zoomScale,
                    offset: $offset,
                    draggedNode: $draggedNode,
                    dragOffset: $dragOffset,
                    potentialEdgeTarget: $potentialEdgeTarget,
                    panStartOffset: $panStartOffset,
                    showMenu: $showMenu,
                    showOverlays: $showOverlays,
                    maxZoom: maxZoom,
                    crownPosition: $crownPosition,
                    updateZoomRangesHandler: onUpdateZoomRanges,
                    selectedNodeID: $viewModel.selectedNodeID,
                    selectedEdgeID: $viewModel.selectedEdgeID,
                    canvasFocus: $isCanvasFocused
                )
            )
        }
        .overlay(alignment: .bottom) {
            Button {
                showMenu.toggle()
            } label: {
                Image(systemName: showMenu ? "point.3.filled.connected.trianglepath.dotted" : "line.3.horizontal")
                    .font(.system(size: 24))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.1))  // Subtle fill; remove for full transparency
                    .clipShape(Circle())
                    .contentShape(Circle())  // Circular tappable area
            }
            .buttonStyle(.plain)  // Removes default padding/background
            .padding(.bottom, 8)  // Space from bottom edge
        }
        .onAppear {
            viewSize = WKInterfaceDevice.current().screenBounds.size
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                viewModel.resumeSimulationAfterDelay()
            } else if newPhase == .inactive {
                viewModel.pauseSimulation()
            }
        }
        .onChange(of: viewModel.model.nodes.count) { _ in
            onUpdateZoomRanges()
        }
        .onChange(of: viewModel.selectedNodeID) { _ in
            if let id = viewModel.selectedNodeID, let node = viewModel.model.nodes.first(where: { $0.id == id }) {
                recenterOn(position: node.position)
                clampOffset()
            }
        }
        .onChange(of: viewModel.selectedEdgeID) { _ in
            guard let id = viewModel.selectedEdgeID else { return }
            guard let edge = viewModel.model.edges.first(where: { $0.id == id }) else { return }
            guard let from = viewModel.model.nodes.first(where: { $0.id == edge.from }) else { return }
            guard let to = viewModel.model.nodes.first(where: { $0.id == edge.to }) else { return }
            
            let mid = CGPoint(x: (from.position.x + to.position.x) / 2, y: (from.position.y + to.position.y) / 2)
            recenterOn(position: mid)
            clampOffset()
        }
        .focusable()
        .digitalCrownRotation($crownPosition, from: 0.0, through: 1.0, sensitivity: .low, isContinuous: true, isHapticFeedbackEnabled: true)
        .ignoresSafeArea()
        .onAppear {
            viewSize = WKInterfaceDevice.current().screenBounds.size
            isCanvasFocused = true  // Force focus on load
        }
        .onChange(of: showMenu) { newValue in
            print("Show menu changed to \(newValue)")
            if !newValue {
                isCanvasFocused = true  // Refocus canvas when menu closes
            }
        }
        .onChange(of: crownPosition) { newValue in
            print("Crown event received: \(newValue)")
            if ignoreNextCrownChange {
                ignoreNextCrownChange = false
                return
            }
            print("Crown position changed to \(newValue). Updating zoom.")
            onUpdateZoomRanges()  // Ensure min/max are up-to-date
            
            // Quantize to discrete levels
            // Exponential mapping for natural zoom (small rotations = fine control, large = fast zoom)
            let zoomSensitivity: CGFloat = 2.0  // Adjust: higher = faster zoom per rotation
            let normalized = CGFloat(newValue)  // 0.0 to 1.0 from crown
            let newZoom = minZoom * pow(maxZoom / minZoom, normalized * zoomSensitivity)
            let clampedNewZoom = newZoom.clamped(to: minZoom...maxZoom).rounded(to: 3)
            
            // Pause simulation
            viewModel.model.isSimulating = false
            viewModel.model.stopSimulation()
            
            // Preserve center: Get model point at screen center before zoom
            let screenCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
            let preZoomModelCenter = CGPoint(
                x: ((screenCenter.x - offset.width) / zoomScale + viewModel.effectiveCentroid.x).rounded(to: 2),
                y: ((screenCenter.y - offset.height) / zoomScale + viewModel.effectiveCentroid.y).rounded(to: 2)
            )
            
            // Temporarily set new zoom
            let oldZoom = zoomScale
            zoomScale = clampedNewZoom
            
            // Adjust offset to keep preZoomModelCenter at screen center
            let newOffsetX = (screenCenter.x - (preZoomModelCenter.x - viewModel.effectiveCentroid.x) * newZoom).rounded(to: 2)
            let newOffsetY = (screenCenter.y - (preZoomModelCenter.y - viewModel.effectiveCentroid.y) * newZoom).rounded(to: 2)
            
            withAnimation(.easeInOut(duration: 0.25)) {
                offset = CGSize(width: newOffsetX, height: newOffsetY)
                zoomScale = newZoom
            }
            
            // Clamp only if significant change, after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let oldOffset = offset
                clampOffset()
                // Skip log/clamp if change is tiny (precision noise)
                if abs(offset.width - oldOffset.width) < 0.01 && abs(offset.height - oldOffset.height) < 0.01 {
                    offset = oldOffset  // Revert micro-adjustment
                }
            }
            
            isZooming = true
            zoomTimer?.invalidate()
            zoomTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in  // Longer debounce
                isZooming = false
                viewModel.model.isSimulating = true
                viewModel.model.startSimulation()
            }
        }        .onChange(of: isCanvasFocused) { newValue in
            print("Canvas focus changed to \(newValue)")  // Debug focus state
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
        
        let menuContent: some View = config.showMenu.wrappedValue ? AnyView(
            MenuView(
                viewModel: config.viewModel,
                showOverlays: config.showOverlays,
                showMenu: config.showMenu
            )
        ) : AnyView(EmptyView())
        

         if config.showMenu.wrappedValue {
             MenuView(
                 viewModel: config.viewModel,
                 showOverlays: config.showOverlays,
                 showMenu: config.showMenu
             )
             .navigationTitle("Menu")  // Optional: Improve navigation
         } else {
             canvasView
         }
    }
}
