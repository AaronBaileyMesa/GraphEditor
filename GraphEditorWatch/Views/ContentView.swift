// ContentView.swift (Updated with Equatable fix via enhanced NodeWrapper and closure for onCenterGraph)

import SwiftUI
import WatchKit
import GraphEditorShared
import Foundation
import CoreGraphics

struct ViewSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct NodeWrapper: Equatable, Identifiable {
    let id: UUID?
    let node: (any NodeProtocol)?
    
    init(node: (any NodeProtocol)?) {
        self.node = node
        self.id = node?.id
    }
    
    static func == (lhs: NodeWrapper, rhs: NodeWrapper) -> Bool {
        lhs.id == rhs.id
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
    let updateZoomRangesHandler: (CGSize) -> Void
    let selectedNodeID: Binding<NodeID?>
    let selectedEdgeID: Binding<UUID?>
    let canvasFocus: FocusState<Bool>
    let onCenterGraph: () -> Void
    
    init(
        geo: GeometryProxy,
        viewModel: GraphViewModel,
        zoomScale: Binding<CGFloat>,
        offset: Binding<CGSize>,
        draggedNode: Binding<NodeWrapper>,
        dragOffset: Binding<CGPoint>,
        potentialEdgeTarget: Binding<NodeWrapper>,
        panStartOffset: Binding<CGSize?>,
        showMenu: Binding<Bool>,
        showOverlays: Binding<Bool>,
        maxZoom: CGFloat,
        crownPosition: Binding<Double>,
        updateZoomRangesHandler: @escaping (CGSize) -> Void,
        selectedNodeID: Binding<NodeID?>,
        selectedEdgeID: Binding<UUID?>,
        canvasFocus: FocusState<Bool>,
        onCenterGraph: @escaping () -> Void
    ) {
        self.geo = geo
        self.viewModel = viewModel
        self.zoomScale = zoomScale
        self.offset = offset
        self.draggedNode = draggedNode
        self.dragOffset = dragOffset
        self.potentialEdgeTarget = potentialEdgeTarget
        self.panStartOffset = panStartOffset
        self.showMenu = showMenu
        self.showOverlays = showOverlays
        self.maxZoom = maxZoom
        self.crownPosition = crownPosition
        self.updateZoomRangesHandler = updateZoomRangesHandler
        self.selectedNodeID = selectedNodeID
        self.selectedEdgeID = selectedEdgeID
        self.canvasFocus = canvasFocus
        self.onCenterGraph = onCenterGraph
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: GraphViewModel
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var draggedNode: NodeWrapper = NodeWrapper(node: nil)
    @State private var dragOffset: CGPoint = .zero
    @State private var potentialEdgeTarget: NodeWrapper = NodeWrapper(node: nil)
    @State private var selectedNodeID: NodeID? = nil
    @State private var selectedEdgeID: UUID? = nil
    @State private var panStartOffset: CGSize? = nil
    @State private var showMenu: Bool = false
    @State private var showOverlays: Bool = false
    @FocusState private var canvasFocus: Bool
    @State private var minZoom: CGFloat = AppConstants.defaultMinZoom
    @State private var maxZoom: CGFloat = AppConstants.defaultMaxZoom
    @State private var crownPosition: Double = Double(AppConstants.crownZoomSteps) / 2

    var body: some View {
        GeometryReader { geo in
            mainContent(in: geo)
                .onAppear {
                    viewModel.resumeSimulation()
                    updateZoomRanges(for: geo.size)
                }
                .onChange(of: viewModel.model.nodes) { _ in
                    updateZoomRanges(for: geo.size)
                }
                .onChange(of: viewModel.model.edges) { _ in
                    updateZoomRanges(for: geo.size)
                }
                .onChange(of: crownPosition) { newValue in
                    handleCrownRotation(newValue: newValue)
                }
                .onChange(of: canvasFocus) { newValue in
                    if !newValue { canvasFocus = true }
                }
        }
        .ignoresSafeArea()
        .digitalCrownRotation($crownPosition, from: 0, through: Double(AppConstants.crownZoomSteps), by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
        .focusable(true)
    }

    private func mainContent(in geo: GeometryProxy) -> some View {
        ZStack {
            innerViewConfig(in: geo)
            graphDescriptionOverlay
        }
    }

    private func innerViewConfig(in geo: GeometryProxy) -> some View {
        let config = InnerViewConfig(
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
            updateZoomRangesHandler: { size in updateZoomRanges(for: size) },
            selectedNodeID: $selectedNodeID,
            selectedEdgeID: $selectedEdgeID,
            canvasFocus: _canvasFocus,
            onCenterGraph: { viewModel.centerGraph() }  // Wrapped in closure to match () -> Void
        )
        return InnerView(config: config)
    }

    private var graphDescriptionOverlay: some View {
        Text(viewModel.model.graphDescription(selectedID: selectedNodeID, selectedEdgeID: selectedEdgeID))
            .accessibilityLabel(viewModel.model.graphDescription(selectedID: selectedNodeID, selectedEdgeID: selectedEdgeID))
            .hidden()
    }

    private func handleCrownRotation(newValue: Double) {
        let normalized = newValue.clamped(to: 0...Double(AppConstants.crownZoomSteps)) / Double(AppConstants.crownZoomSteps)
        zoomScale = minZoom + (maxZoom - minZoom) * CGFloat(normalized)
        viewModel.centerGraph()  // Direct call
    }

    private func updateZoomRanges(for viewSize: CGSize) {
        let ranges = viewModel.calculateZoomRanges(for: viewSize)
        minZoom = ranges.min
        maxZoom = ranges.max
        zoomScale = zoomScale.clamped(to: minZoom...maxZoom)
    }
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
        
        let canvasView = GraphCanvasView(
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
            onUpdateZoomRanges: { config.updateZoomRangesHandler(config.geo.size) },
            selectedEdgeID: config.selectedEdgeID,
            showOverlays: config.showOverlays
        )
        .accessibilityIdentifier("GraphCanvas")
        .focused(config.canvasFocus.projectedValue)
        
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

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
/*Old ContentView
 // Supporting struct for config (expand if needed)
struct InnerViewConfig {
    let viewModel: GraphViewModel
    let zoomScale: Binding<CGFloat>
    let offset: Binding<CGSize>
    let draggedNode: Binding<(any NodeProtocol)?>
    let dragOffset: Binding<CGPoint>
    let potentialEdgeTarget: Binding<(any NodeProtocol)?>
    let selectedNodeID: Binding<NodeID?>
    let selectedEdgeID: Binding<UUID?>
    let geo: GeometryProxy
    let panStartOffset: Binding<CGSize?>
    let showMenu: Binding<Bool>
    let maxZoom: CGFloat
    let crownPosition: Binding<Double>
    let updateZoomRangesHandler: () -> Void
    let showOverlays: Binding<Bool>
    let canvasFocus: FocusState<Bool>.Binding
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
    @State private var maxZoom: CGFloat = Constants.App.maxZoom // 2.5
    @State private var numZoomLevels: Double = Double(Constants.App.numZoomLevels) // 20.0
    @State private var crownPosition: Double = 0.0  // Temp default; we'll set properly in .onAppear
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
    @State private var lastDelta: Double = 0

    
    var body: some View {
        GeometryReader { geo in
                Group {  // New: Stable wrapper
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
                            crownPosition: $crownPosition,  // Already passed; ensure it's used if needed in InnerView
                            updateZoomRangesHandler: onUpdateZoomRanges,
                            selectedNodeID: $viewModel.selectedNodeID,
                            selectedEdgeID: $viewModel.selectedEdgeID,
                            canvasFocus: $isCanvasFocused,
                            onCenterGraph: { recenterOn(position: viewModel.effectiveCentroid) }
                        ))
                    }
                    .ignoresSafeArea()
                }
                .digitalCrownRotation($crownPosition, from: 0.0, through: numZoomLevels, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)  // Add isHaptic for feedback
                .focusable(true)  // Single here
                    .focusEffectDisabled(false)
            }
            .ignoresSafeArea()
            .onChange(of: crownPosition, initial: true) { oldValue, newValue in
                if oldValue == 0.0 && newValue == 0.0 {
                    print("Skipping initial onChange for crownPosition")
                    return
                }
                
                let clampedCrown = newValue.clamped(to: 0.0...numZoomLevels)
                if abs(clampedCrown - crownPosition) > 0.01 {
                    crownPosition = clampedCrown
                }
                
                let normalized = clampedCrown / numZoomLevels
                    let effectiveMin = max(minZoom, 0.1)  // Safety
                    let effectiveMax = max(maxZoom, effectiveMin + 1.0)
                    let targetZoom = effectiveMin + normalized * (effectiveMax - effectiveMin)
                    let clampedZoom = targetZoom.cÏlamped(to: effectiveMin...effectiveMax)
                
                
                if abs(clampedZoom - zoomScale) > 0.01 {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        let oldZoom = zoomScale
                        zoomScale = clampedZoom
                        
                        // Fixed focal (as before)
                        let focal = viewModel.effectiveCentroid
                        let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
                        let oldRelative = focal - viewCenter
                        let shift = oldRelative * (1 - zoomScale / oldZoom)
                        offset = CGSize(width: offset.width + shift.x, height: offset.height + shift.y)
                    }
                    print("Crown zoom applied: \(zoomScale), clamped? \(clampedZoom != targetZoom)")
                    viewModel.saveViewState()
                }
            }
            .onChange(of: viewModel.selectedNodeID) { _ in
                if let id = viewModel.selectedNodeID, let node = viewModel.model.nodes.first(where: { $0.id == id }) {
                    print("Selection change: Recentering on node \(id) at \(node.position)")
                    recenterOn(position: node.position)
                } else {
                    print("Selection cleared: Recentering on graph centroid \(viewModel.effectiveCentroid)")
                    recenterOn(position: viewModel.effectiveCentroid)
                }
                viewModel.saveViewState()  // Existing
            }
        
        .onChange(of: showMenu) { newValue in
            print("Show menu changed to \(newValue)")
            viewModel.focusState = newValue ? .menu : .graph
            if !newValue {
                isCanvasFocused = true
            }
        }

        .onAppear {
            do {
                if let state = try? viewModel.model.loadViewState() {
                    offset = CGSize(width: state.offset.x, height: state.offset.y)
                    zoomScale = state.zoomScale.clamped(to: 0.01...maxZoom)  // Clamp here before assigning
                    selectedNodeID = state.selectedNodeID
                    selectedEdgeID = state.selectedEdgeID
                }
            } catch {
                print("Failed to load view state: \(error)")
            }
            
            if crownPosition == 0.0 {
                    let normalized = (1.0 - minZoom) / (maxZoom - minZoom)
                    crownPosition = normalized * numZoomLevels
                    print("Initial crownPosition set to \(crownPosition) for zoom 1.0")
                }
                
                print("Direct initial zoom set to 1.0")  // Debug; remove later
            
            print("Loaded nodes count: \(viewModel.model.nodes.count)")  // Add this
            onUpdateZoomRanges()
            isLoaded = true
            recenterOn(position: viewModel.effectiveCentroid)
            onUpdateZoomRanges()
            viewModel.model.startSimulation()
            isCanvasFocused = true
        }
        
        // Existing .onAppear, .onChange(of: showMenu), etc...
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                isCanvasFocused = true  // Re-focus on activation
                print("App activated: Re-focusing crown view")
            }
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
        if graphBounds.width <= 0 || graphBounds.height <= 0 {
            minZoom = 0.1  // Default if bounds invalid (e.g., empty graph)
            maxZoom = Constants.App.maxZoom
            print("Defaulting zoom ranges due to invalid bounds")  // Debug; remove later
            return
        }
        
        let fitScaleWidth = viewSize.width / graphBounds.width
        let fitScaleHeight = viewSize.height / graphBounds.height
        minZoom = min(fitScaleWidth, fitScaleHeight) * 0.5
        maxZoom = max(fitScaleWidth, fitScaleHeight) * 3.0
        
        // Enforce sane limits
        minZoom = max(minZoom, 0.1)
        maxZoom = max(maxZoom, minZoom + 1.0)  // Ensure max > min
        print("Updated zoom ranges: min=\(minZoom), max=\(maxZoom)")  // Debug
    }
    
    // Add other private functions if needed
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
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
         //.focusable(true)

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

 */
// If in #Preview (update the entire preview):
#Preview {
    let mockViewModel = GraphViewModel(model: GraphModel(storage: PersistenceManager(), physicsEngine: PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))))
    ContentView(viewModel: mockViewModel)  // <-- If ContentView now takes viewModel, add it here too (see next fix)
}

