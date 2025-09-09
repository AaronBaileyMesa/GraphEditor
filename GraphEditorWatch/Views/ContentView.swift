// ContentView.swift (Fixed version: Removed .hidden() from mainContent to ensure rendering; preserved other improvements)

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
    let isAddingEdge: Binding<Bool>
    let isSimulatingBinding: Binding<Bool>
    
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
        onCenterGraph: @escaping () -> Void,
        isAddingEdge: Binding<Bool>,
        isSimulatingBinding: Binding<Bool>  // NEW: Add this param
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
        self.isAddingEdge = isAddingEdge
        self.isSimulatingBinding = isSimulatingBinding  // NEW: Assign it
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
    @State private var wristSide: WKInterfaceDeviceWristLocation = .left  // Default to left
    @State private var showEditSheet: Bool = false
    @State private var isAddingEdge: Bool = false
    @State private var viewSize: CGSize = .zero
    @State private var isSimulating: Bool = false
    
    // NEW: Custom Bindings to sync @State with ViewModel (two-way)
        private var selectedNodeIDBinding: Binding<NodeID?> {
            Binding(
                get: { selectedNodeID },
                set: { newValue in
                    selectedNodeID = newValue
                    viewModel.setSelectedNode(newValue)  // Sync to ViewModel
                }
            )
        }

        private var selectedEdgeIDBinding: Binding<UUID?> {
            Binding(
                get: { selectedEdgeID },
                set: { newValue in
                    selectedEdgeID = newValue
                    viewModel.setSelectedEdge(newValue)  // Sync to ViewModel
                }
            )
        }
    
    var body: some View {
        GeometryReader { geo in
            mainContent(in: geo)
                .onAppear {
                    Task { await viewModel.resumeSimulation() }
                    updateZoomRanges(for: geo.size)
                    wristSide = WKInterfaceDevice.current().wristLocation
                    print(geo.size)
                    canvasFocus = true
                    
                    let initialNormalized = crownPosition / Double(AppConstants.crownZoomSteps)
                    zoomScale = minZoom + (maxZoom - minZoom) * CGFloat(initialNormalized)
                    #if DEBUG
                    print("Initial sync: crownPosition \(crownPosition) -> zoomScale \(zoomScale)")
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
                    print("Crown position changed in ContentView: from \(oldValue) to \(newValue)")
                    handleCrownRotation(newValue: newValue)
                }
                .onChange(of: canvasFocus) { oldValue, newValue in
                    print("ContentView canvas focus changed: from \(oldValue) to \(newValue)")
                    if !newValue { canvasFocus = true }
                }
                // New: Bi-directional sync with threshold to avoid loops
                .onChange(of: zoomScale) { oldValue, newValue in
                    let normalized = (newValue - minZoom) / (maxZoom - minZoom)
                    let targetCrown = Double(AppConstants.crownZoomSteps) * Double(normalized).clamped(to: 0...1)
                    if abs(targetCrown - crownPosition) > 0.01 {
                        crownPosition = targetCrown
                        #if DEBUG
                        print("Zoom sync: zoomScale from \(oldValue) to \(newValue) -> crownPosition \(crownPosition)")
                        #endif
                    }
                }
                .onChange(of: viewModel.selectedNodeID) { oldValue, newValue in
                    print("ContentView: ViewModel selectedNodeID changed from \(oldValue?.uuidString.prefix(8) ?? "nil") to \(newValue?.uuidString.prefix(8) ?? "nil")")
                    selectedNodeID = newValue  // Sync to local @State
                    viewModel.objectWillChange.send()  // Force re-render if needed
                }
                .onChange(of: viewModel.selectedEdgeID) { oldValue, newValue in
                    print("ContentView: ViewModel selectedEdgeID changed from \(oldValue?.uuidString.prefix(8) ?? "nil") to \(newValue?.uuidString.prefix(8) ?? "nil")")
                    selectedEdgeID = newValue
                    viewModel.objectWillChange.send()
                }
                // New: Center on stable simulation
                .onReceive(viewModel.model.$isStable) { isStable in
                    if isStable {
                        print("Simulation stable: Centering nodes")
                        centerGraph()
                    }
                }
                // New: Log simulation errors
                .onReceive(viewModel.model.$simulationError) { error in
                    if let error = error {
                        print("Simulation error: \(error.localizedDescription)")
                    }
                }
                .sheet(isPresented: $showEditSheet) {
                    if let selectedID = selectedNodeID {
                        EditContentSheet(selectedID: selectedID, viewModel: viewModel, onSave: { newContent in
                            Task { await viewModel.updateNodeContent(withID: selectedID, newContent: newContent) }
                        })
                    }
                }
        }
        .ignoresSafeArea()
        .focusable(true)  // Make the whole view focusable for crown
        .focused($canvasFocus)  // Bind focus state
        .digitalCrownRotation(  // Restored: Put back here for root-level handling
            $crownPosition,
            from: 0,
            through: Double(AppConstants.crownZoomSteps),
            sensitivity: .medium
        )
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
                updateZoomRangesHandler: { size in updateZoomRanges(for: size) },
                selectedNodeID: $selectedNodeID,
                selectedEdgeID: $selectedEdgeID,
                canvasFocus: _canvasFocus,
                onCenterGraph: centerGraph,
                isAddingEdge: $isAddingEdge,
                isSimulatingBinding: $isSimulating,  // FIXED: Pass actual binding instance from @State
            ))
            
            addNodeButton(in: geo)
            menuButton(in: geo)
        }
        // Removed .hidden() to ensure the content renders
    }

    private func handleCrownRotation(newValue: Double) {
        #if DEBUG
        print("handleCrownRotation triggered with newValue: \(newValue)")
        #endif
        let normalized = newValue.clamped(to: 0...Double(AppConstants.crownZoomSteps)) / Double(AppConstants.crownZoomSteps)
        let targetZoom = minZoom + (maxZoom - minZoom) * CGFloat(normalized)
        
        // New: Animate the zoom change for smoothness
        withAnimation(.easeInOut(duration: 0.1)) {
            zoomScale = targetZoom
        }
        viewModel.centerGraph()  // Direct call
        #if DEBUG
        print("Updated zoomScale to: \(zoomScale)")
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
        print("Centering graph: Old centroid \(oldCentroid), Shift \(centroidShift), New target \(newCentroid)")
    }

    // Existing add node button (unchanged, but renamed for clarity)
    private func addNodeButton(in geo: GeometryProxy) -> some View {
        Button(action: {
            let randomPos = CGPoint(x: CGFloat.random(in: -100...100), y: CGFloat.random(in: -100...100))  // Random spread
            Task { await viewModel.addNode(at: randomPos) }  // Changed to addNode for regular nodes; use addToggleNode if desired
        }) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(.green)
        }
        .buttonStyle(.plain)
        .position(x: wristSide == .left ? 20 : geo.size.width - 20, y: geo.size.height - 20)
    }

    private func menuButton(in geo: GeometryProxy) -> some View {
        Button(action: {
            if showMenu {
                showMenu = false  // Back to graph
            } else {
                showMenu = true   // Open menu
            }
        }) {
            Image(systemName: showMenu ? "chart.xyaxis.line" : "ellipsis.circle.fill")  // NEW: Dynamic icon (graph for back, menu for open)
                .font(.system(size: 30))
                .foregroundColor(showMenu ? .green : .blue)  // NEW: Color change for state
        }
        .buttonStyle(.plain)
        .position(x: wristSide == .left ? 60 : geo.size.width - 60, y: geo.size.height - 20)  // Preserve adjacent positioning
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
            showOverlays: config.showOverlays,
            isAddingEdge: config.isAddingEdge
        )
            .accessibilityIdentifier("GraphCanvas")
            .focused(config.canvasFocus.projectedValue)
                .focusable()  // Add this to ensure view property for crown
        //        .digitalCrownRotation($crownPosition, from: 0, through: Double(AppConstants.crownZoomSteps), sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)  // Ensure sensitivity isn't too high to reduce jitter
        
        if config.showMenu.wrappedValue {
            MenuView(
                viewModel: config.viewModel,
                isSimulatingBinding: config.isSimulatingBinding,
                onCenterGraph: config.onCenterGraph,
                showMenu: config.showMenu,
                showOverlays: config.showOverlays,
                selectedNodeID: config.selectedNodeID,    // NEW: Pass binding
                selectedEdgeID: config.selectedEdgeID     // NEW: Pass binding
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

#Preview {
    let mockViewModel = GraphViewModel(model: GraphModel(storage: PersistenceManager(), physicsEngine: PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))))
    ContentView(viewModel: mockViewModel)
}

struct EditContentSheet: View {
    let selectedID: NodeID
    let viewModel: GraphViewModel
    let onSave: (NodeContent?) -> Void
    @State private var selectedType: String = "String"
    @State private var stringValue: String = ""
    @State private var dateValue: Date = Date()
    @State private var numberValue: Double = 0.0
    
    var body: some View {
        VStack {
            Picker("Type", selection: $selectedType) {
                Text("String").tag("String")
                Text("Date").tag("Date")
                Text("Number").tag("Number")
                Text("None").tag("None")
            }
            if selectedType == "String" {
                TextField("Enter text", text: $stringValue).frame(maxWidth: .infinity)
            } else if selectedType == "Date" {
                DatePicker("Select date", selection: $dateValue, displayedComponents: .date)
            } else if selectedType == "Number" {
                TextField("Enter number", value: $numberValue, format: .number)
            }
            Button("Save") {
                let newContent: NodeContent? = {
                    switch selectedType {
                    case "String": return stringValue.isEmpty ? nil : .string(stringValue)
                    case "Date": return .date(dateValue)
                    case "Number": return .number(numberValue)
                    default: return nil
                    }
                }()
                onSave(newContent)
            }
        }
        .onAppear {
            if let node = viewModel.model.nodes.first(where: { $0.id == selectedID }),
               let content = node.content {
                switch content {
                case .string(let str): selectedType = "String"; stringValue = str
                case .date(let date): selectedType = "Date"; dateValue = date
                case .number(let num): selectedType = "Number"; numberValue = num
                }
            }
        }
    }
}
