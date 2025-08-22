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
    @State private var previousZoomScale: CGFloat = 1.0
    @State private var selectedNodeID: NodeID?  // <-- Add this if missing
        @State private var selectedEdgeID: UUID?    // <-- Add this if missing
    @FocusState private var isCanvasFocused: Bool
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                InnerView(config: InnerViewConfig(
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
                    canvasFocus: $isCanvasFocused,
                    onCenterGraph: { recenterOn(position: viewModel.effectiveCentroid) }
                ))
            }
        }
        .digitalCrownRotation($crownPosition, from: 0.0, through: 1.0, sensitivity: .medium, isContinuous: true, isHapticFeedbackEnabled: true)
        .onChange(of: crownPosition) { newValue in
            let delta = (newValue - previousCrownPosition) * 2.0
            let newZoom = zoomScale * (1.0 + delta)
            zoomScale = newZoom.clamped(to: minZoom...maxZoom)
            
            switch viewModel.focusState {
            case .graph:
                break
            case .node(let id):
                if let node = viewModel.model.nodes.first(where: { $0.id == id }) {
                    recenterOn(position: node.position)
                }
            case .edge(let id):
                if let edge = viewModel.model.edges.first(where: { $0.id == id }),
                   let from = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                   let to = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                    let midpoint = CGPoint(x: (from.position.x + to.position.x) / 2, y: (from.position.y + to.position.y) / 2)
                    recenterOn(position: midpoint)
                }
            case .menu:
                break
            }
            previousCrownPosition = newValue
        }
        .onChange(of: viewModel.focusState) { newState in
            WKInterfaceDevice.current().play(.click)
        }
        .onChange(of: showMenu) { newValue in
            print("Show menu changed to \(newValue)")
            viewModel.focusState = newValue ? .menu : .graph
            if !newValue {
                isCanvasFocused = true
            }
        }
        // In ContentView.swift (.onAppear block)
        .onAppear {
            do {
                if let state = try? viewModel.model.loadViewState() {
                    offset = CGSize(width: state.offset.x, height: state.offset.y)  // <-- Convert CGPoint to CGSize
                    zoomScale = state.zoomScale
                    selectedNodeID = state.selectedNodeID
                    selectedEdgeID = state.selectedEdgeID
                }
            } catch {
                print("Failed to load view state: \(error)")
            }
            onUpdateZoomRanges()
            isLoaded = true
            recenterOn(position: viewModel.effectiveCentroid)
            viewModel.model.startSimulation()
            isCanvasFocused = true
        }
        .onChange(of: zoomScale) { newValue in
            if abs(newValue - previousZoomScale) > 0.01 {
                previousZoomScale = newValue
                viewModel.model.isSimulating = false
                viewModel.model.stopSimulation()
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
    
    private func recenterOn(position: CGPoint) {
        let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let newOffset = CGSize(width: viewCenter.x - position.x * zoomScale, height: viewCenter.y - position.y * zoomScale)
        offset = clampOffset(newOffset)
    }
    
    private func clampOffset(_ proposedOffset: CGSize) -> CGSize {
        let graphBounds = viewModel.model.physicsEngine.boundingBox(nodes: viewModel.model.nodes)
        let scaledWidth = graphBounds.width * zoomScale
        let scaledHeight = graphBounds.height * zoomScale
        let maxX = max(0, (scaledWidth - viewSize.width) / 2)
        let maxY = max(0, (scaledHeight - viewSize.height) / 2)
        return CGSize(width: proposedOffset.width.clamped(to: -maxX...maxX), height: proposedOffset.height.clamped(to: -maxY...maxY))
    }
    
    private func onUpdateZoomRanges() {
        let graphBounds = viewModel.model.physicsEngine.boundingBox(nodes: viewModel.model.nodes)
        let fitScaleWidth = viewSize.width / graphBounds.width
        let fitScaleHeight = viewSize.height / graphBounds.height
        minZoom = min(fitScaleWidth, fitScaleHeight) * 0.5
        maxZoom = max(fitScaleWidth, fitScaleHeight) * 3.0
    }
    
    // Add other private functions if needed
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}

// If in #Preview (update the entire preview):
#Preview {
    let mockViewModel = GraphViewModel(model: GraphModel(storage: PersistenceManager(), physicsEngine: PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))))
    ContentView(viewModel: mockViewModel)  // <-- If ContentView now takes viewModel, add it here too (see next fix)
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
            .navigationTitle("Menu")
        } else {
            canvasView
        }
    }
}
