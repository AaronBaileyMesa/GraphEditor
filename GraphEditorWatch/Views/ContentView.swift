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
    let isAddingEdge: Binding<Bool>  // Add
    
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
        isAddingEdge: Binding<Bool>
    
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

    var body: some View {
        GeometryReader { geo in
            mainContent(in: geo)
                .onAppear {
                    Task { await viewModel.resumeSimulation() }
                    updateZoomRanges(for: geo.size)
                    wristSide = WKInterfaceDevice.current().wristLocation  // Property is wristLocation
                    print(geo.size)
                    canvasFocus = true  // Force focus on appear
                    
                    // New: Sync initial zoomScale to match starting crownPosition
                    let initialNormalized = crownPosition / Double(AppConstants.crownZoomSteps)
                    zoomScale = minZoom + (maxZoom - minZoom) * CGFloat(initialNormalized)
                    #if DEBUG
                    print("Initial sync: crownPosition \(crownPosition) -> zoomScale \(zoomScale)")
                    #endif
                }
                .onChange(of: viewModel.model.nodes) { _, _ in
                    updateZoomRanges(for: geo.size)
                }
                .onChange(of: viewModel.model.edges) { _, _ in
                    updateZoomRanges(for: geo.size)
                }
                .onChange(of: crownPosition) { oldValue, newValue in
                    print("Crown position changed in ContentView: from \(oldValue) to \(newValue)")
                    handleCrownRotation(newValue: newValue)
                }
                .onChange(of: canvasFocus) { oldValue, newValue in
                    print("ContentView canvas focus changed: from \(oldValue) to \(newValue)")
                    if !newValue { canvasFocus = true }
                }
                // New: Bi-directional sync—update crownPosition if zoomScale changes (e.g., via gestures)
                .onChange(of: zoomScale) { oldValue, newValue in
                    let normalized = (newValue - minZoom) / (maxZoom - minZoom)
                    crownPosition = Double(AppConstants.crownZoomSteps) * Double(normalized).clamped(to: 0...1)
                    #if DEBUG
                    print("Zoom sync: zoomScale from \(oldValue) to \(newValue) -> crownPosition \(crownPosition)")
                    #endif
                }
        }
        .ignoresSafeArea()
        .focusable(true)  // Make the whole view focusable for crown
        .focused($canvasFocus)  // Bind focus state
        .digitalCrownRotation(  // Restored: Put back here for root-level handling
            $crownPosition,
            from: 0,
            through: Double(AppConstants.crownZoomSteps),
            by: 1,
            sensitivity: .high,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
    }

    private func mainContent(in geo: GeometryProxy) -> some View {
        ZStack {
            innerViewConfig(in: geo)
            graphDescriptionOverlay
                        // Persistent + button
                        let isLeftWrist = wristSide == .left
                        Button(action: {
                            let centroid = viewModel.effectiveCentroid
                            Task { await viewModel.model.addNode(at: centroid) }
                            WKInterfaceDevice.current().play(.success)
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                        .position(x: isLeftWrist ? geo.size.width - 20 : 20, y: geo.size.height - 20)  // Bottom-right for left, bottom-left for right
            
                        // Contextual buttons for node
                        if let selectedID = viewModel.selectedNodeID {
                            HStack(spacing: 10) {
                                Button(action: { showEditSheet = true }) {
                                    Image(systemName: "pencil.circle.fill").font(.system(size: 24))
                                }.buttonStyle(.plain)
                                Button(action: {
                                    Task { await viewModel.model.deleteNode(withID: selectedID) }
                                    viewModel.selectedNodeID = nil
                                    WKInterfaceDevice.current().play(.success)
                                }) {
                                    Image(systemName: "trash.circle.fill").font(.system(size: 24))
                                }.buttonStyle(.plain)
                                Button(action: { isAddingEdge = true }) {
                                    Image(systemName: "plus.circle.fill").font(.system(size: 24))
                                }.buttonStyle(.plain)
                            }
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .position(x: isLeftWrist ? geo.size.width / 2 + 50 : geo.size.width / 2 - 50, y: geo.size.height - 30)
                        } else if let selectedEdgeID = viewModel.selectedEdgeID {
                            HStack(spacing: 10) {
                                Button(action: {
                                    Task { await viewModel.model.deleteEdge(withID: selectedEdgeID) }
                                    viewModel.selectedEdgeID = nil
                                    WKInterfaceDevice.current().play(.success)
                                }) {
                                    Image(systemName: "trash.circle.fill").font(.system(size: 24))
                                }.buttonStyle(.plain)
                                Button(action: {
                                    if let edgeIndex = viewModel.model.edges.firstIndex(where: { $0.id == selectedEdgeID }) {
                                        let edge = viewModel.model.edges[edgeIndex]
                                        viewModel.model.edges[edgeIndex] = GraphEdge(id: edge.id, from: edge.to, to: edge.from)
                                        Task { await viewModel.model.startSimulation() }
                                    }
                                    WKInterfaceDevice.current().play(.success)
                                }) {
                                    Image(systemName: "arrow.left.arrow.right.circle.fill").font(.system(size: 24))
                                }.buttonStyle(.plain)
                            }
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .position(x: isLeftWrist ? geo.size.width / 2 + 50 : geo.size.width / 2 - 50, y: geo.size.height - 30)
                        }
                    }
                    .onAppear {
                        wristSide = WKInterfaceDevice.current().wristLocation
                    }
                    .sheet(isPresented: $showEditSheet) {
                        if let selectedID = viewModel.selectedNodeID {
                            EditContentSheet(selectedID: selectedID, viewModel: viewModel, onSave: { newContent in
                                Task { await viewModel.model.updateNodeContent(withID: selectedID, newContent: newContent) }
                                showEditSheet = false
                            })
                        }
                    
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
            onCenterGraph: { viewModel.centerGraph() },
            isAddingEdge: $isAddingEdge
            // Wrapped in closure to match () -> Void
        )
        return InnerView(config: config)
    }

    private var graphDescriptionOverlay: some View {
        Text(viewModel.model.graphDescription(selectedID: selectedNodeID, selectedEdgeID: selectedEdgeID))
            .accessibilityLabel(viewModel.model.graphDescription(selectedID: selectedNodeID, selectedEdgeID: selectedEdgeID))
            .hidden()
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
            isAddingEdge: config.isAddingEdge  // Add this param (update init below too)
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

#Preview {
    let mockViewModel = GraphViewModel(model: GraphModel(storage: PersistenceManager(), physicsEngine: PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))))
    ContentView(viewModel: mockViewModel)  // <-- If ContentView now takes viewModel, add it here too (see next fix)
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
