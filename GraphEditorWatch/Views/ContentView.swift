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
    @StateObject var viewModel = GraphViewModel(model: GraphModel())
    @State private var zoomScale: CGFloat = 1.0
    @State private var minZoom: CGFloat = 0.2
    @State private var maxZoom: CGFloat = 5.0
    @State private var crownPosition: Double = 2.5
    @State private var viewSize: CGSize = .zero
    @State private var offset: CGSize = .zero
    @State private var panStartOffset: CGSize?
    @State private var draggedNode: Node? = nil
    @State private var dragOffset: CGPoint = .zero
    @State private var potentialEdgeTarget: Node? = nil
    @State private var ignoreNextCrownChange: Bool = false
    @State private var selectedNodeID: NodeID? = nil
    @State private var showMenu = false
    @Environment(\.scenePhase) private var scenePhase
    
    let numZoomLevels = 6
    let nodeModelRadius: CGFloat = 10.0
    let hitScreenRadius: CGFloat = 30.0
    let tapThreshold: CGFloat = 10.0
    
    var body: some View {
        GeometryReader { geo in
            graphCanvasView(geo: geo)
        }
        .sheet(isPresented: $showMenu) {
            menuView
        }
        .focusable()
        .digitalCrownRotation($crownPosition, from: 0.0, through: Double(numZoomLevels - 1), sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: false)
        .onChange(of: crownPosition) { oldValue, newValue in
            if ignoreNextCrownChange {
                ignoreNextCrownChange = false
                updateZoomScale(oldCrown: oldValue, adjustOffset: false)
                return
            }
            
            let maxCrown = Double(numZoomLevels - 1)
            let clampedValue = max(0, min(newValue, maxCrown))
            if clampedValue != newValue {
                ignoreNextCrownChange = true
                crownPosition = clampedValue
                return
            }
            
            if floor(newValue) != floor(oldValue) {
                WKInterfaceDevice.current().play(.click)
            }
            updateZoomScale(oldCrown: oldValue, adjustOffset: true)
        }
        .ignoresSafeArea()
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                viewModel.model.startSimulation()
            } else {
                viewModel.model.stopSimulation()
            }
        }
        .onDisappear {
            viewModel.model.stopSimulation()
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
            hitScreenRadius: hitScreenRadius,
            tapThreshold: tapThreshold,
            maxZoom: maxZoom,
            numZoomLevels: numZoomLevels,
            crownPosition: $crownPosition,
            onUpdateZoomRanges: updateZoomRanges,
            nodeModelRadius: nodeModelRadius
        )
        .onAppear {
            viewSize = geo.size
            updateZoomRanges()
            viewModel.model.startSimulation()
        }
    }
    
    private var menuView: some View {
        VStack {
            Button("New Graph") {
                viewModel.snapshot()
                viewModel.model.nodes = []
                viewModel.model.edges = []
                showMenu = false
                viewModel.model.startSimulation()
            }
            if let selected = selectedNodeID {
                Button("Delete Selected") {
                    viewModel.deleteNode(withID: selected)
                    selectedNodeID = nil
                    showMenu = false
                    viewModel.model.startSimulation()
                }
            }
            Button("Undo") {
                viewModel.undo()
                showMenu = false
                viewModel.model.startSimulation()
            }
            .disabled(!viewModel.canUndo)
            Button("Redo") {
                viewModel.redo()
                showMenu = false
                viewModel.model.startSimulation()
            }
            .disabled(!viewModel.canRedo)
        }
    }
    
    // Provides a textual description of the graph for accessibility.
    private func graphDescription() -> String {
        var desc = "Graph with \(viewModel.model.nodes.count) nodes and \(viewModel.model.edges.count) edges."
        if let selectedID = selectedNodeID,
           let selectedNode = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
            let connections = viewModel.model.edges.filter { $0.from == selectedID || $0.to == selectedID }.count
            desc += " Node \(selectedNode.label) selected with \(connections) connections."
        } else {
            desc += " No node selected."
        }
        return desc
    }
    
    // Updates the zoom range based on current graph and view size.
    private func updateZoomRanges() {
        guard viewSize != .zero else { return }
        
        if viewModel.model.nodes.isEmpty {
            minZoom = 0.5
            maxZoom = 2.0
            let midCrown = Double(numZoomLevels - 1) / 2.0
            if midCrown != crownPosition {
                ignoreNextCrownChange = true
                crownPosition = midCrown
            }
            return
        }
        
        let bbox = viewModel.model.boundingBox()
        let graphWidth = max(bbox.width, CGFloat(20)) + CGFloat(20)
        let graphHeight = max(bbox.height, CGFloat(20)) + CGFloat(20)
        let graphDia = max(graphWidth, graphHeight)
        let targetDia = min(viewSize.width, viewSize.height) / CGFloat(3)
        let newMinZoom = targetDia / graphDia
        
        let nodeDia = 2 * nodeModelRadius
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
        progress = progress.clamped(to: 0...1)  // Explicit clamp to [0,1]
        let newCrown = Double(progress * CGFloat(numZoomLevels - 1))
        if abs(newCrown - crownPosition) > 1e-6 {
            ignoreNextCrownChange = true
            crownPosition = newCrown
        }
    }
    
    // Updates the zoom scale and adjusts offset if needed.
    private func updateZoomScale(oldCrown: Double, adjustOffset: Bool) {
        let oldProgress = oldCrown / Double(numZoomLevels - 1)
        let oldScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), oldProgress))
        
        let newProgress = crownPosition / Double(numZoomLevels - 1)
        let newScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), newProgress))
        
        if adjustOffset && oldScale != newScale && viewSize != .zero {
            let focus = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
            let worldFocus = CGPoint(x: (focus.x - offset.width) / oldScale, y: (focus.y - offset.height) / oldScale)
            offset = CGSize(width: focus.x - worldFocus.x * newScale, height: focus.y - worldFocus.y * newScale)
        }
        
        withAnimation(.easeInOut) {
            zoomScale = newScale
        }
    }
}

#Preview {
    ContentView()
}
