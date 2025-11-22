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
    @State private var wristSide: WKInterfaceDeviceWristLocation = .left  // Default to left
    @State private var showEditSheet: Bool = false
    @State private var isAddingEdge: Bool = false
    @State private var viewSize: CGSize = .zero
    @State private var isSimulating: Bool = false
    @State private var saturation: Double = 1.0
    // MARK: - Crown from Environment (single source of truth)
    @Environment(\.crownPosition) private var crownPositionBinding: Binding<Double>
    
    private var crownPosition: Double {
        get { crownPositionBinding.wrappedValue }
        nonmutating set { crownPositionBinding.wrappedValue = newValue }
    }
    
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
        GeometryReader { geo in
            ZStack {
                mainContent(in: geo)
            }
            .onAppear {
                Task { await viewModel.resumeSimulation() }
                updateZoomRanges(for: geo.size)
                wristSide = WKInterfaceDevice.current().wristLocation
                canvasFocus = true
                viewModel.resetViewToFitGraph(viewSize: geo.size)
                viewSize = geo.size
                
#if DEBUG
                logger.debug("Geometry size: width=\(geo.size.width), height=\(geo.size.height)")
                logger.debug("Initial sync: crownPosition \(self.crownPosition) -> zoomScale \(self.zoomScale)")
#endif
            }
            .onChange(of: viewModel.model.nodes) { updateZoomRanges(for: viewSize) }
            .onChange(of: viewModel.model.edges) { updateZoomRanges(for: viewSize) }
            .onChange(of: canvasFocus) { _, newValue in
                if !newValue { canvasFocus = true }
            }
            
            // Keep all your existing .onChange and .onReceive handlers exactly as they were
            .onChange(of: viewModel.selectedNodeID) { _, newValue in
#if DEBUG
                logger.debug("ContentView: ViewModel selectedNodeID → \(newValue?.uuidString.prefix(8) ?? "nil")")
#endif
                selectedNodeID = newValue
            }
            .onChange(of: viewModel.selectedEdgeID) { _, newValue in
                selectedEdgeID = newValue
            }
            .onReceive(viewModel.model.$isStable) { isStable in
                if isStable { centerGraph() }
            }
            .onReceive(viewModel.model.$simulationError) { error in
                if let error = error {
                    logger.error("Simulation error: \(error.localizedDescription)")
                }
            }
        }
        .ignoresSafeArea()
        // THE ONE AND ONLY digitalCrownRotation in the entire app
        .digitalCrownRotation(
            crownPositionBinding,
            from: 0,
            through: Double(AppConstants.crownZoomSteps),
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .focusable()
        .focused($canvasFocus)
        .sheet(isPresented: $showMenu) {
            NavigationStack {
                MenuView(
                    viewModel: viewModel,
                    isSimulatingBinding: $isSimulating,
                    onCenterGraph: centerGraph,
                    showMenu: $showMenu,
                    showOverlays: $showOverlays,
                    selectedNodeID: selectedNodeIDBinding,
                    selectedEdgeID: selectedEdgeIDBinding
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
                minZoom: minZoom,
                maxZoom: maxZoom,
                crownPosition: crownPositionBinding,
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
        .sheet(isPresented: $showMenu) {
            NavigationStack {  // NEW: Wrap in NavigationStack for push navigation
                MenuView(
                    viewModel: viewModel,
                    isSimulatingBinding: $isSimulating,
                    onCenterGraph: centerGraph,
                    showMenu: $showMenu,
                    showOverlays: $showOverlays,
                    selectedNodeID: $selectedNodeID,
                    selectedEdgeID: $selectedEdgeID
                )
                .navigationBarTitleDisplayMode(.inline)  // Optional: Compact title
            }
            .onDisappear {
                print("Menu sheet dismissed")
                showMenu = false
                withAnimation(.easeInOut(duration: 0.2)) {
                    saturation = 1.0  // Ensure reset on dismiss
                }
            }
        }
    }
    
    private func updateZoomRanges(for viewSize: CGSize) {
        let ranges = viewModel.calculateZoomRanges(for: viewSize)
        minZoom = ranges.min
        maxZoom = ranges.max
        zoomScale = zoomScale.clamped(to: minZoom...maxZoom)
    }
    
    // New: Animated centering from new version (with corrected shift sign if needed; tested as-is)
    private func centerGraph() {
        guard viewSize.width > 0 else { return }
        
        let oldCentroid = viewModel.effectiveCentroid
        
        // ← NOW CORRECT: uses the stored real size
        viewModel.resetViewToFitGraph(viewSize: viewSize)
        
        let newCentroid = viewModel.effectiveCentroid
        
        let centroidShift = CGSize(
            width: (oldCentroid.x - newCentroid.x) * zoomScale,
            height: (oldCentroid.y - newCentroid.y) * zoomScale
        )
        
        withAnimation(.easeInOut(duration: 0.3)) {
            offset.width  += centroidShift.width
            offset.height += centroidShift.height
        }
        
#if DEBUG
        logger.debug("Centering graph – oldCentroid: (\(oldCentroid.x), \(oldCentroid.y)), newCentroid: (\(newCentroid.x), \(newCentroid.y)), shift: (\(centroidShift.width), \(centroidShift.height))")
#endif
    }}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}

#Preview {
    let mockViewModel = GraphViewModel(model: GraphModel(storage: PersistenceManager(), physicsEngine: PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))))
    ContentView(viewModel: mockViewModel)
}
