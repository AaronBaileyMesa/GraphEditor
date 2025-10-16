import SwiftUI
import WatchKit
import GraphEditorShared
import Foundation
import CoreGraphics
import os  // Added for logging

struct ContentView: View {
    private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "contentview")  // Added for consistent logging
    
    @ObservedObject var viewModel: GraphViewModel
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var draggedNode: NodeWrapper = NodeWrapper(node: nil)
    @State private var dragOffset: CGPoint = .zero
    @State private var potentialEdgeTarget: NodeWrapper = NodeWrapper(node: nil)
    @State private var selectedNodeID: NodeID?
    @State private var selectedEdgeID: UUID?
    @State private var panStartOffset: CGSize?
    @State private var showMenu: Bool = false
    @State private var showOverlays: Bool = false
    @FocusState private var canvasFocus: Bool
    @State private var minZoom: CGFloat = AppConstants.defaultMinZoom
    @State private var maxZoom: CGFloat = AppConstants.defaultMaxZoom
    @State private var crownPosition: Double = Double(AppConstants.crownZoomSteps) / 2
    @State private var wristSide: WKInterfaceDeviceWristLocation = .left  // Default to left
    @State private var showEditSheet: Bool = false
    @State private var isAddingEdge: Bool = false
    @State private var viewSize: CGSize = .zero
    @State private var isSimulating: Bool = false
    @State private var saturation: Double = 1.0
    
    // NEW: Custom Bindings to sync @State with ViewModel (two-way)
    private var selectedNodeIDBinding: Binding<NodeID?> {
        Binding(
            get: { selectedNodeID },
            set: { newValue in
                selectedNodeID = newValue
                viewModel.selectedNodeID = newValue  // Sync to ViewModel
            }
        )
    }
    
    private var selectedEdgeIDBinding: Binding<UUID?> {
        Binding(
            get: { selectedEdgeID },
            set: { newValue in
                selectedEdgeID = newValue
                viewModel.selectedEdgeID = newValue  // Sync to ViewModel
            }
        )
    }
    
    var body: some View {
        let geoView = GeometryReader { geo in
            let baseView = mainContent(in: geo)
                .onAppear {
                    Task { await viewModel.resumeSimulation() }
                    updateZoomRanges(for: geo.size)
                    wristSide = WKInterfaceDevice.current().wristLocation
                    
#if DEBUG
                    logger.debug("Geometry size: width=\(geo.size.width), height=\(geo.size.height)")
#endif
                    
                    canvasFocus = true
                    
                    let initialNormalized = crownPosition / Double(AppConstants.crownZoomSteps)
                    zoomScale = minZoom + (maxZoom - minZoom) * CGFloat(initialNormalized)
                    
#if DEBUG
                    logger.debug("Initial sync: crownPosition \(self.crownPosition) -> zoomScale \(self.zoomScale)")
#endif
                    
                    viewSize = geo.size  // New: Set viewSize here
                }
                .onChange(of: viewModel.model.nodes) { _, _ in
                    updateZoomRanges(for: viewSize)  // New: Use viewSize
                }
                .onChange(of: viewModel.model.edges) { _, _ in
                    updateZoomRanges(for: viewSize)  // New: Use viewSize
                }
                .onChange(of: crownPosition) { oldValue, newValue in
#if DEBUG
                    logger.debug("Crown position changed in ContentView: from \(oldValue) to \(newValue)")
#endif
                    
                    handleCrownRotation(newValue: newValue)
                }
                .onChange(of: canvasFocus) { oldValue, newValue in
#if DEBUG
                    logger.debug("ContentView canvas focus changed: from \(oldValue) to \(newValue)")
#endif
                    
                    if !newValue { canvasFocus = true }
                }
            
            let intermediateView = baseView
                .onChange(of: zoomScale) { oldValue, newValue in
                    let normalized = (newValue - minZoom) / (maxZoom - minZoom)
                    let targetCrown = Double(AppConstants.crownZoomSteps) * Double(normalized).clamped(to: 0...1)
                    if abs(targetCrown - crownPosition) > 0.01 {
                        crownPosition = targetCrown
                        
#if DEBUG
                        logger.debug("Zoom sync: zoomScale from \(oldValue) to \(newValue) -> crownPosition \(self.crownPosition)")
#endif
                    }
                }
                .onChange(of: viewModel.selectedNodeID) { oldValue, newValue in
#if DEBUG
                    logger.debug("ContentView: ViewModel selectedNodeID changed from \(oldValue?.uuidString.prefix(8) ?? "nil") to \(newValue?.uuidString.prefix(8) ?? "nil")")
#endif
                    
                    selectedNodeID = newValue  // Sync to local @State
                    viewModel.objectWillChange.send()  // Force re-render if needed
                }
                .onChange(of: viewModel.selectedEdgeID) { oldValue, newValue in
#if DEBUG
                    logger.debug("ContentView: ViewModel selectedEdgeID changed from \(oldValue?.uuidString.prefix(8) ?? "nil") to \(newValue?.uuidString.prefix(8) ?? "nil")")
#endif
                    
                    selectedEdgeID = newValue
                    viewModel.objectWillChange.send()
                }
                .onReceive(viewModel.model.$isStable) { isStable in
                    if isStable {
#if DEBUG
                        logger.debug("Simulation stable: Centering nodes")
#endif
                        
                        centerGraph()
                    }
                }
                .onReceive(viewModel.model.$simulationError) { error in
                    if let error = error {
#if DEBUG
                        logger.error("Simulation error: \(error.localizedDescription)")
#endif
                    }
                }
            
            intermediateView
        }
        
        let finalView = geoView
            .ignoresSafeArea()
            .focusable(true)  // Make the whole view focusable for crown
            .focused($canvasFocus)  // Bind focus state
            .digitalCrownRotation(  // Restored: Put back here for root-level handling
                $crownPosition,
                from: 0,
                through: Double(AppConstants.crownZoomSteps),
                sensitivity: .medium
            )
        
        finalView
    }
    
    private func mainContent(in geo: GeometryProxy) -> some View {
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
                updateZoomRangesHandler: { updateZoomRanges(for: $0) },
                selectedNodeID: selectedNodeIDBinding,  // Use your custom binding
                selectedEdgeID: selectedEdgeIDBinding,  // Use your custom binding
                canvasFocus: _canvasFocus,
                onCenterGraph: centerGraph,
                isAddingEdge: $isAddingEdge,
                isSimulating: $isSimulating,
                saturation: $saturation  // NEW: Pass the binding here
            ))
        }
        /*.overlay(alignment: .bottom) {
            HStack(spacing: 20) {
                if wristSide == .left {
                    addNodeButton(in: geo)
                    menuButton(in: geo)
                } else {
                    menuButton(in: geo)
                    addNodeButton(in: geo)
                }
            }
            .padding(.bottom, 1)
            .padding(.horizontal, 15)
            .transition(.move(edge: .bottom))
        }*/
        .sheet(isPresented: $showMenu) {
            MenuView(
                viewModel: viewModel,
                isSimulatingBinding: $isSimulating,  // Pass your bindings
                onCenterGraph: centerGraph,
                showMenu: $showMenu,  // For dismissal
                showOverlays: $showOverlays,
                selectedNodeID: $selectedNodeID,
                selectedEdgeID: $selectedEdgeID
            )
            .onDisappear {
                print("Menu sheet dismissed")
                showMenu = false
                withAnimation(.easeInOut(duration: 0.2)) {
                                saturation = 1.0  // Ensure reset on dismiss
                            }
            }
        }
    }
    
    private func handleCrownRotation(newValue: Double) {
#if DEBUG
        logger.debug("handleCrownRotation triggered with newValue: \(newValue)")
#endif
        
        let normalized = newValue.clamped(to: 0...Double(AppConstants.crownZoomSteps)) / Double(AppConstants.crownZoomSteps)
        let targetZoom = minZoom + (maxZoom - minZoom) * CGFloat(normalized)
        
        // New: Animate the zoom change for smoothness
        withAnimation(.easeInOut(duration: 0.1)) {
            zoomScale = targetZoom
        }
        viewModel.centerGraph()  // Direct call
        
#if DEBUG
        logger.debug("Updated zoomScale to: \(self.zoomScale)")
#endif
    }
    
    private func updateZoomRanges(for viewSize: CGSize) {
        let ranges = viewModel.calculateZoomRanges(for: viewSize)
        minZoom = ranges.min
        maxZoom = ranges.max
        zoomScale = zoomScale.clamped(to: minZoom...maxZoom)
    }
    
    // New: Animated centering from new version (with corrected shift sign if needed; tested as-is)
    private func centerGraph() {
        let oldCentroid = viewModel.effectiveCentroid
        viewModel.centerGraph()
        let newCentroid = viewModel.effectiveCentroid
        let centroidShift = CGSize(
            width: (oldCentroid.x - newCentroid.x) * zoomScale,
            height: (oldCentroid.y - newCentroid.y) * zoomScale
        )
        withAnimation(.easeInOut(duration: 0.3)) {
            offset.width += centroidShift.width
            offset.height += centroidShift.height
        }
        
#if DEBUG
        logger.debug("Centering graph: Old centroid x=\(oldCentroid.x), y=\(oldCentroid.y), Shift width=\(centroidShift.width), height=\(centroidShift.height), New target x=\(newCentroid.x), y=\(newCentroid.y)")
#endif
    }
    
    // Existing add node button (unchanged, but renamed for clarity)
    private func addNodeButton(in geo: GeometryProxy) -> some View {
        Button(action: {
            WKInterfaceDevice.current().play(.click)  // Haptic feedback
            
#if DEBUG
            logger.debug("Add Node button tapped!")
#endif
            
            let randomPos = CGPoint(x: CGFloat.random(in: -100...100), y: CGFloat.random(in: -100...100))
            Task { await viewModel.addNode(at: randomPos) }
        }, label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(.green)
        })
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .frame(minWidth: 44, minHeight: 44)
        .padding(10)
        .background(Color.blue.opacity(0.2))  // TEMP: Visualize tappable area; remove later
    }
    
    private func menuButton(in geo: GeometryProxy) -> some View {
        Button(action: {
            WKInterfaceDevice.current().play(.click)  // Haptic feedback
            
#if DEBUG
            logger.debug("Menu button tapped!")
#endif
            
            showMenu.toggle()
        }, label: {
            Image(systemName: showMenu ? "point.3.filled.connected.trianglepath.dotted" : "line.3.horizontal")
                .font(.system(size: 30))
                .foregroundColor(showMenu ? .green : .blue)
        })
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .frame(minWidth: 44, minHeight: 44)
        .padding(10)
        .background(Color.red.opacity(0.2))  // TEMP: Visualize; different color for distinction
        .accessibilityLabel("Menu")
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}

#Preview {
    let mockViewModel = GraphViewModel(model: GraphModel(storage: PersistenceManager(), physicsEngine: PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))))
    ContentView(viewModel: mockViewModel)
}
