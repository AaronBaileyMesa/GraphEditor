//
//  ContentView.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//

// Views/ContentView.swift
import SwiftUI
import WatchKit
import GraphEditorShared

struct ContentView: View {
    @StateObject var viewModel: GraphViewModel
    @State private var zoomScale: CGFloat = 1.0
    @State private var minZoom: CGFloat = 0.2
    @State private var maxZoom: CGFloat = 5.0
    @State private var crownPosition: Double = 2.5
    @State private var viewSize: CGSize = .zero
    @State private var offset: CGSize = .zero
    @State private var panStartOffset: CGSize?
    @State private var draggedNode: (any NodeProtocol)? = nil  // Updated to existential for polymorphism
    @State private var dragOffset: CGPoint = .zero
    @State private var potentialEdgeTarget: (any NodeProtocol)? = nil  // Updated to existential
    @State private var ignoreNextCrownChange: Bool = false
    @State private var selectedNodeID: NodeID? = nil
    @State private var showMenu = false
    @State private var previousCrownPosition: Double = 2.5  // Match initial crownPosition
    @State private var isZooming: Bool = false  // Track active zoom for pausing simulation
    @State private var selectedEdgeID: UUID? = nil  // New state
    @Environment(\.scenePhase) private var scenePhase
    
    init(storage: GraphStorage = PersistenceManager(),
         physicsEngine: PhysicsEngine = PhysicsEngine(simulationBounds: WKInterfaceDevice.current().screenBounds.size)) {
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        _viewModel = StateObject(wrappedValue: GraphViewModel(model: model))
    }
    
    // New: Define the shared closure here (incorporates your existing logic + offset clamping)
    private var onUpdateZoomRanges: () -> Void {
        return {
            // Directly use self (safe for struct)
            self.updateZoomRanges()
            
            // Add improved offset clamping (allows positive for zoom-out centering)
            let bbox = self.viewModel.model.physicsEngine.boundingBox(nodes: self.viewModel.model.visibleNodes())
            let scaledWidth = bbox.width * self.zoomScale
            let scaledHeight = bbox.height * self.zoomScale
            
            let minOffsetX = min(0.0, self.viewSize.width - scaledWidth)
            let maxOffsetX = max(0.0, self.viewSize.width - scaledWidth)
            let minOffsetY = min(0.0, self.viewSize.height - scaledHeight)
            let maxOffsetY = max(0.0, self.viewSize.height - scaledHeight)
            
            self.offset.width = max(min(self.offset.width, maxOffsetX), minOffsetX)
            self.offset.height = max(min(self.offset.height, maxOffsetY), minOffsetY)
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            graphCanvasView(geo: geo)
        }
        .ignoresSafeArea()  // New: Ignore safe area insets to fill screen top/bottom
        .sheet(isPresented: $showMenu) {
            menuView
        }
        .focusable()
        .digitalCrownRotation($crownPosition, from: 0.0, through: Double(AppConstants.numZoomLevels - 1), sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: false)
        .onChange(of: crownPosition) { oldValue, newValue in
            if ignoreNextCrownChange {
                ignoreNextCrownChange = false
                updateZoomScale(oldCrown: oldValue, adjustOffset: false)
                return
            }
            
            let maxCrown = Double(AppConstants.numZoomLevels - 1)
            let clampedValue = max(0, min(newValue, maxCrown))
            if clampedValue != newValue {
                crownPosition = clampedValue
                return
            }
            
            // Integrated updates here
            updateZoomScale(oldCrown: oldValue, adjustOffset: true)
            previousCrownPosition = newValue
            
            // Debounce simulation resume
            if isZooming {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isZooming = false
                    self.viewModel.model.startSimulation()
                }
            }
        }
    }
    
    private func graphCanvasView(geo: GeometryProxy) -> some View {
        GraphCanvasView(
            viewModel: viewModel,
            zoomScale: $zoomScale,
            offset: $offset,
            draggedNode: $draggedNode,
            dragOffset: $dragOffset,
            potentialEdgeTarget: $potentialEdgeTarget,
            selectedNodeID: $selectedNodeID,
            viewSize: geo.size,
            panStartOffset: $panStartOffset,
            showMenu: $showMenu,
            maxZoom: maxZoom,
            crownPosition: $crownPosition,
            onUpdateZoomRanges: onUpdateZoomRanges,
            selectedEdgeID: $selectedEdgeID
        )
        .onAppear {
            viewSize = geo.size
        }
    }
    
    // Assuming menuView is defined here or elsewhere; keep as is
    private var menuView: some View {
        VStack {
            // Your menu content...
            Button("Undo") { viewModel.undo() }.disabled(!viewModel.canUndo)
                    Button("Redo") { viewModel.redo() }.disabled(!viewModel.canRedo)
                    Button("Delete Selected Edge") {
                        viewModel.model.deleteSelectedEdge(id: selectedEdgeID)
                        selectedEdgeID = nil  // Clear selection
                        showMenu = false
                    }.disabled(selectedEdgeID == nil)
                    Button("Close") { showMenu = false }
                }
                .padding()
            }
    
    // Existing function (unchanged, but called in onUpdateZoomRanges)
    private func updateZoomRanges() {
        guard !viewModel.model.nodes.isEmpty else {
            minZoom = 0.2
            maxZoom = 5.0
            return
        }
        
        let bbox = viewModel.model.boundingBox()
        let graphWidth = max(bbox.width, CGFloat(20)) + CGFloat(20)
        let graphHeight = max(bbox.height, CGFloat(20)) + CGFloat(20)
        let graphDia = max(graphWidth, graphHeight)
        let targetDia = min(viewSize.width, viewSize.height) / CGFloat(3)
        let newMinZoom = targetDia / graphDia
        
        let nodeDia = 2 * AppConstants.nodeModelRadius
        let targetNodeDia = min(viewSize.width, viewSize.height) * (CGFloat(2) / CGFloat(3))
        let newMaxZoom = targetNodeDia / nodeDia
        
        minZoom = newMinZoom
        maxZoom = max(newMaxZoom, newMinZoom * CGFloat(2))
        
        let currentScale = zoomScale
        var progress: CGFloat = 0.5
        if minZoom < currentScale && currentScale < maxZoom && minZoom > 0 && maxZoom > minZoom {
            progress = CGFloat(log(Double(currentScale / minZoom)) / log(Double(maxZoom / minZoom)))
        } else if currentScale <= minZoom {
            progress = 0.0
        } else {
            progress = 1.0
        }
        progress = progress.clamped(to: 0.0...1.0)  // Explicit clamp to [0,1] with CGFloat range
        let newCrown = Double(progress * CGFloat(AppConstants.numZoomLevels - 1))
        if abs(newCrown - crownPosition) > 1e-6 {
            ignoreNextCrownChange = true
            crownPosition = newCrown
        }
    }
    
    // Updates the zoom scale and adjusts offset if needed.
    private func updateZoomScale(oldCrown: Double, adjustOffset: Bool) {
        let oldProgress = oldCrown / Double(AppConstants.numZoomLevels - 1)
        let oldScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), oldProgress))
        
        let newProgress = crownPosition / Double(AppConstants.numZoomLevels - 1)
        let newScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), newProgress))
        
        if adjustOffset && oldScale != newScale && viewSize != .zero {
            var focus: CGPoint  // Screen focus point (use view center for gray circle)
            var worldFocus: CGPoint  // Corresponding world point
            
            if let selectedID = selectedNodeID,
               let node = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
                worldFocus = node.position
                focus = CGPoint(
                    x: worldFocus.x * oldScale + offset.width,
                    y: worldFocus.y * oldScale + offset.height
                )
            } else {
                // Always focus on view center (gray circle)
                focus = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
                worldFocus = CGPoint(x: (focus.x - offset.width) / oldScale, y: (focus.y - offset.height) / oldScale)
            }
            
            offset = CGSize(width: focus.x - worldFocus.x * newScale, height: focus.y - worldFocus.y * newScale)
        }
        
        zoomScale = newScale
        
        // New: Recenter if no selection after zoom
        if selectedNodeID == nil {
            centerGraph()
        }
    }
    
    private func centerGraph() {
        guard !viewModel.model.nodes.isEmpty else { return }
        
        // Compute centroid
        let totalX = viewModel.model.nodes.reduce(0.0) { $0 + $1.position.x }
        let totalY = viewModel.model.nodes.reduce(0.0) { $0 + $1.position.y }
        let centroid = CGPoint(x: totalX / CGFloat(viewModel.model.nodes.count), y: totalY / CGFloat(viewModel.model.nodes.count))
        
        // Set offset to center centroid
        offset = CGSize(
            width: viewSize.width / 2 - centroid.x * zoomScale,
            height: viewSize.height / 2 - centroid.y * zoomScale
        )
        
        onUpdateZoomRanges()  // Clamp after centering
    }
    
}

#Preview {
    ContentView()
}
