//
//  AccessibleCanvas.swift
//  GraphEditorWatch
//

import SwiftUI
import GraphEditorShared
import os

// swiftlint:disable file_length
// Rationale: Complex canvas rendering with accessibility support requires extensive view logic.
// This file handles TimelineView scheduling, coordinate transformation, and accessible rendering.

// NEW: Subview for Canvas content to force updates by depending on context.date
struct AnimatedCanvasContent: View {
    let contextDate: Date  // Changes every tick (animated) or fixed (static), for logging and .id if needed
    let viewModel: GraphViewModel
    let zoomScale: CGFloat
    let offset: CGSize
    let draggedNode: (any NodeProtocol)?
    let dragOffset: CGPoint
    let potentialEdgeTarget: (any NodeProtocol)?
    let selectedNodeID: NodeID?
    let viewSize: CGSize
    let selectedEdgeID: UUID?
    let showOverlays: Bool
    let saturation: Double
    let currentDragLocation: CGPoint?
    let isAddingEdge: Bool
    let dragStartNode: (any NodeProtocol)?
    
    var body: some View {
        Canvas { graphicsContext, _ in
            var context = graphicsContext  // Single var for mutable GraphicsContext (use this for all draws)
            let allVisibleNodes = viewModel.model.visibleNodes  // Fresh capture every recompute
            let allVisibleEdges = viewModel.model.visibleEdges
            
            // Filter out control nodes - they're rendered by SwiftUI overlay for immediate display
            let visibleNodes = allVisibleNodes.filter { node in
                !(node is ControlNode)
            }
            
            // Filter out control edges (spring edges to control nodes)
            let controlNodeIDs = Set(viewModel.model.ephemeralControlNodes.map { $0.id })
            let visibleEdges = allVisibleEdges.filter { edge in
                !controlNodeIDs.contains(edge.from) && !controlNodeIDs.contains(edge.target)
            }
            
            let effectiveCentroid = viewModel.effectiveCentroid
            
            // ONE source of truth – used by every drawing function and hit-testing
            let renderContext = RenderContext(
                effectiveCentroid: effectiveCentroid,
                zoomScale: zoomScale,      // already scaled to fill screen
                offset: offset,
                viewSize: viewSize         // full physical size → perfect hit-testing
            )
            
            // Split selected / non-selected for proper layering
            let nonSelectedNodes = visibleNodes.filter { $0.id != selectedNodeID }
            let selectedNode = visibleNodes.first { $0.id == selectedNodeID }
            let nonSelectedEdges = visibleEdges.filter { $0.id != selectedEdgeID }
            let selectedEdge = visibleEdges.first { $0.id == selectedEdgeID }
            
            // MARK: - Edges (non-selected)
            AccessibleCanvasRenderer.drawEdges(
                renderContext: renderContext,
                graphicsContext: context,
                visibleEdges: nonSelectedEdges,
                visibleNodes: visibleNodes,
                saturation: saturation
            )
            
            // MARK: - Arrows (non-selected)
            AccessibleCanvasRenderer.drawArrows(
                renderContext: renderContext,
                graphicsContext: context,
                visibleEdges: nonSelectedEdges,
                visibleNodes: visibleNodes,
                saturation: saturation
            )
            
            // MARK: - Nodes (non-selected)
            for node in nonSelectedNodes {
                AccessibleCanvasRenderer.drawSingleNode(
                    renderContext: renderContext,
                    graphicsContext: context,
                    node: node,  // Draw using actual model position
                    saturation: saturation,
                    isSelected: false
                )
            }
            
            // NEW: Draw selected edge (if any) – was missing in animatedCanvas
            if let edge = selectedEdge {
                AccessibleCanvasRenderer.drawSingleEdgeLine(
                    config: EdgeDrawingConfig(
                        renderContext: renderContext,
                        graphicsContext: context,
                        saturation: saturation,
                        isSelected: true,
                        logger: AccessibleCanvas.logger
                    ),
                    edge: edge,
                    visibleNodes: visibleNodes
                )
                AccessibleCanvasRenderer.drawSingleArrow(
                    config: EdgeDrawingConfig(
                        renderContext: renderContext,
                        graphicsContext: context,
                        saturation: saturation,
                        isSelected: true,
                        logger: AccessibleCanvas.logger
                    ),
                    edge: edge,
                    visibleNodes: visibleNodes
                )
            }
            
            // MARK: - Selected Node (if any)
            if let node = selectedNode {
                AccessibleCanvasRenderer.drawSingleNode(
                    renderContext: renderContext,
                    graphicsContext: context,
                    node: node,
                    saturation: saturation,
                    isSelected: true
                )
            }
            
            // MARK: - Overlays (unchanged)
            if showOverlays {
                AccessibleCanvasRenderer.drawBoundingBox(
                    nodes: visibleNodes,
                    in: &context,
                    renderContext: renderContext
                )
            }
            
            // MARK: - Drag Preview (assuming this is the truncated part; adjust as needed)
            drawDragPreview(in: &context, renderContext: renderContext, visibleNodes: visibleNodes)
        }
    }
    
    // Shared drawDragPreview (now inside AnimatedCanvasContent since it's the only user)
    private func drawDragPreview(in context: inout GraphicsContext, renderContext: RenderContext, visibleNodes: [any NodeProtocol]) {
        // FIXED: Only draw drag preview if the node is actually being dragged with an offset
        // This prevents duplicate rendering when a node is selected but not dragged
        if let dragged = draggedNode, dragOffset != .zero {
            // Create a temporary node at the dragged position for rendering
            var draggedCopy = dragged
            draggedCopy.position = dragged.position + dragOffset
            
            AccessibleCanvasRenderer.drawSingleNode(
                renderContext: renderContext,
                graphicsContext: context,
                node: draggedCopy,
                saturation: saturation,
                isSelected: true
            )
        }
        
        // Draw edge preview line when adding an edge
        if isAddingEdge,
           let dragLoc = currentDragLocation {
            // Find the source node from viewModel.draggedNodeID (set when addEdge was tapped)
            let sourceNode = visibleNodes.first { $0.id == viewModel.draggedNodeID } ?? dragStartNode ?? draggedNode
            
            guard let source = sourceNode else { return }
            let sourceScreen = CoordinateTransformer.modelToScreen(source.position, in: renderContext)
            
            // Draw line from source to current drag location
            var path = Path()
            path.move(to: sourceScreen)
            path.addLine(to: dragLoc)
            
            context.stroke(
                path,
                with: .color(.yellow.opacity(0.6)),
                lineWidth: 2.0
            )
            
            // Draw a small circle at the drag location
            let circlePath = Path(ellipseIn: CGRect(
                x: dragLoc.x - 4,
                y: dragLoc.y - 4,
                width: 8,
                height: 8
            ))
            context.fill(circlePath, with: .color(.yellow.opacity(0.8)))
        }
    }
}

struct AccessibleCanvas: View {
    @ObservedObject var viewModel: GraphViewModel
    let zoomScale: CGFloat
    let offset: CGSize
    let draggedNode: (any NodeProtocol)?
    let dragOffset: CGPoint
    let potentialEdgeTarget: (any NodeProtocol)?
    let selectedNodeID: NodeID?
    let selectedEdgeID: UUID?
    let viewSize: CGSize
    let showOverlays: Bool
    let saturation: Double
    let currentDragLocation: CGPoint?
    let isAddingEdge: Bool
    let dragStartNode: (any NodeProtocol)?
    let onUpdateZoomRanges: (CGFloat, CGFloat) -> Void
    
    static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "accessiblecanvas")
    
    var body: some View {
        ZStack {
            // Canvas layer (draws regular nodes and edges)
            Group {
                if viewModel.model.isSimulating {
                    TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                        AnimatedCanvasContent(
                            contextDate: context.date,
                            viewModel: viewModel,
                            zoomScale: zoomScale,
                            offset: offset,
                            draggedNode: draggedNode,
                            dragOffset: dragOffset,
                            potentialEdgeTarget: potentialEdgeTarget,
                            selectedNodeID: selectedNodeID,
                            viewSize: viewSize,
                            selectedEdgeID: selectedEdgeID,
                            showOverlays: showOverlays,
                            saturation: saturation,
                            currentDragLocation: currentDragLocation,
                            isAddingEdge: isAddingEdge,
                            dragStartNode: dragStartNode
                        )
                    }
                } else {
                    AnimatedCanvasContent(
                        contextDate: Date(),
                        viewModel: viewModel,
                        zoomScale: zoomScale,
                        offset: offset,
                        draggedNode: draggedNode,
                        dragOffset: dragOffset,
                        potentialEdgeTarget: potentialEdgeTarget,
                        selectedNodeID: selectedNodeID,
                        viewSize: viewSize,
                        selectedEdgeID: selectedEdgeID,
                        showOverlays: showOverlays,
                        saturation: saturation,
                        currentDragLocation: currentDragLocation,
                        isAddingEdge: isAddingEdge,
                        dragStartNode: dragStartNode
                    )
                }
            }
            
            // SwiftUI overlay for control nodes (immediate rendering)
            // Use @ObservedObject to ensure immediate updates
            // IMPORTANT: Don't use .id() modifier here - it breaks animations
            ControlNodesOverlayWrapper(
                viewModel: viewModel,
                zoomScale: zoomScale,
                offset: offset,
                viewSize: viewSize
            )
        }
        .accessibilityIdentifier("graphCanvas")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(Color.black)
    }
}

// Wrapper that observes ViewModel for immediate updates
struct ControlNodesOverlayWrapper: View {
    @ObservedObject var viewModel: GraphViewModel
    let zoomScale: CGFloat
    let offset: CGSize
    let viewSize: CGSize
    
    var body: some View {
        ControlNodesOverlay(
            controlNodes: viewModel.model.ephemeralControlNodes,
            controlEdges: viewModel.model.ephemeralControlEdges,
            visibleNodes: viewModel.model.visibleNodes,
            effectiveCentroid: viewModel.effectiveCentroid,
            zoomScale: zoomScale,
            offset: offset,
            viewSize: viewSize
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.model.ephemeralControlNodes.count)
    }
}

// NEW: SwiftUI overlay for control nodes to bypass Canvas rendering lag
struct ControlNodesOverlay: View {
    let controlNodes: [ControlNode]
    let controlEdges: [GraphEdge]
    let visibleNodes: [any NodeProtocol]
    let effectiveCentroid: CGPoint
    let zoomScale: CGFloat
    let offset: CGSize
    let viewSize: CGSize
    
    var body: some View {
        // Find owner node position for animation anchor
        let ownerScreenPos: CGPoint? = {
            guard let ownerID = controlNodes.first?.ownerID,
                  let owner = visibleNodes.first(where: { $0.id == ownerID }) else {
                return nil
            }
            return worldToScreen(
                worldPos: owner.position,
                effectiveCentroid: effectiveCentroid,
                zoomScale: zoomScale,
                offset: offset,
                viewSize: viewSize
            )
        }()
        
        return ZStack {
            // Draw control edges first (behind the control nodes)
            ForEach(controlEdges, id: \.id) { edge in
                if let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
                   let toNode = visibleNodes.first(where: { $0.id == edge.target }) {
                    let fromScreen = worldToScreen(
                        worldPos: fromNode.position,
                        effectiveCentroid: effectiveCentroid,
                        zoomScale: zoomScale,
                        offset: offset,
                        viewSize: viewSize
                    )
                    let toScreen = worldToScreen(
                        worldPos: toNode.position,
                        effectiveCentroid: effectiveCentroid,
                        zoomScale: zoomScale,
                        offset: offset,
                        viewSize: viewSize
                    )
                    
                    Path { path in
                        path.move(to: fromScreen)
                        path.addLine(to: toScreen)
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1.0)
                    .transition(.opacity)
                }
            }
            
            // Draw control nodes on top
            ForEach(controlNodes, id: \.id) { control in
                let screenPos = worldToScreen(
                    worldPos: control.position,
                    effectiveCentroid: effectiveCentroid,
                    zoomScale: zoomScale,
                    offset: offset,
                    viewSize: viewSize
                )
                
                ControlNodeView(control: control, zoomScale: zoomScale, ownerScreenPos: ownerScreenPos ?? screenPos)
                    .position(screenPos)
            }
        }
    }
    
    private func logControlRendering() {
        #if DEBUG
        if !controlNodes.isEmpty {
            AccessibleCanvas.logger.debug("=== Control Rendering ===")
            AccessibleCanvas.logger.debug("Centroid: (\(effectiveCentroid.x, format: .fixed(precision: 1)), \(effectiveCentroid.y, format: .fixed(precision: 1)))")
            AccessibleCanvas.logger.debug("ZoomScale: \(zoomScale, format: .fixed(precision: 2))")
            AccessibleCanvas.logger.debug("Offset: (\(offset.width, format: .fixed(precision: 1)), \(offset.height, format: .fixed(precision: 1)))")
            
            // Find owner node to calculate actual distances
            if let ownerID = controlNodes.first?.ownerID,
               let owner = visibleNodes.first(where: { $0.id == ownerID }) {
                AccessibleCanvas.logger.debug("Owner position: (\(owner.position.x, format: .fixed(precision: 1)), \(owner.position.y, format: .fixed(precision: 1)))")
                
                for control in controlNodes {
                    let modelDx = control.position.x - owner.position.x
                    let modelDy = control.position.y - owner.position.y
                    let modelDistance = hypot(modelDx, modelDy)
                    
                    let screenPos = worldToScreen(
                        worldPos: control.position,
                        effectiveCentroid: effectiveCentroid,
                        zoomScale: zoomScale,
                        offset: offset,
                        viewSize: viewSize
                    )
                    let ownerScreenPos = worldToScreen(
                        worldPos: owner.position,
                        effectiveCentroid: effectiveCentroid,
                        zoomScale: zoomScale,
                        offset: offset,
                        viewSize: viewSize
                    )
                    
                    let screenDx = screenPos.x - ownerScreenPos.x
                    let screenDy = screenPos.y - ownerScreenPos.y
                    let screenDistance = hypot(screenDx, screenDy)
                    
                    AccessibleCanvas.logger.debug("Control \(control.kind.rawValue): model=(\(control.position.x, format: .fixed(precision: 1)), \(control.position.y, format: .fixed(precision: 1))) dist=\(modelDistance, format: .fixed(precision: 1))pt → screen=(\(screenPos.x, format: .fixed(precision: 1)), \(screenPos.y, format: .fixed(precision: 1))) dist=\(screenDistance, format: .fixed(precision: 1))px")
                }
            }
        }
        #endif
    }
    
    private func worldToScreen(
        worldPos: CGPoint,
        effectiveCentroid: CGPoint,
        zoomScale: CGFloat,
        offset: CGSize,
        viewSize: CGSize
    ) -> CGPoint {
        let canvasCenterX = viewSize.width / 2
        let canvasCenterY = viewSize.height / 2
        
        let relativeX = (worldPos.x - effectiveCentroid.x) * zoomScale
        let relativeY = (worldPos.y - effectiveCentroid.y) * zoomScale
        
        let screenX = canvasCenterX + relativeX + offset.width
        let screenY = canvasCenterY + relativeY + offset.height
        
        return CGPoint(x: screenX, y: screenY)
    }
}

// NEW: SwiftUI view for individual control node
struct ControlNodeView: View {
    let control: ControlNode
    let zoomScale: CGFloat
    let ownerScreenPos: CGPoint
    @State private var isPressed: Bool = false
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 0.0
    
    var body: some View {
        let iconName: String = switch control.kind {
        case .addChild: "plus.circle.fill"
        case .addEdge: "arrow.right.circle.fill"
        case .edit: "pencil"
        case .delete: "trash.fill"
        case .duplicate: "doc.on.doc.fill"
        case .addToggleChild: "checklist"
        }
        
        ZStack {
            // Invisible larger hit testing area (1.5x the visual size)
            Circle()
                .fill(Color.clear)
                .frame(
                    width: control.radius * 2 * zoomScale * 1.5,
                    height: control.radius * 2 * zoomScale * 1.5
                )
                .contentShape(Circle())
            
            // Outer glow for depth
            Circle()
                .fill(control.fillColor.opacity(0.3))
                .frame(
                    width: control.radius * 2 * zoomScale + 4,
                    height: control.radius * 2 * zoomScale + 4
                )
                .blur(radius: 3)
                .allowsHitTesting(false)  // Don't intercept touches
            
            // Main circle with shadow
            Circle()
                .fill(control.fillColor.opacity(0.95))
                .frame(width: control.radius * 2 * zoomScale, height: control.radius * 2 * zoomScale)
                .shadow(color: .black.opacity(0.4), radius: 2 * zoomScale, x: 0, y: 1 * zoomScale)
                .allowsHitTesting(false)  // Don't intercept touches
            
            // Icon (scaled proportionally with control size)
            Image(systemName: iconName)
                .font(.system(size: 18 * zoomScale, weight: .medium))  // Increased from 16 to 18
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                .allowsHitTesting(false)  // Don't intercept touches
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                scale = 1.0
                opacity = 1.0
            }
        }
        .onDisappear {
            scale = 0.1
            opacity = 0.0
        }
    }
}

#Preview("Control Node Animations") {
    struct AnimationPreview: View {
        @State private var showControls = false
        
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Simulated owner node
                Circle()
                    .fill(Color.blue)
                    .frame(width: 40, height: 40)
                
                if showControls {
                    // Simulated control nodes in a circle
                    ForEach(Array(ControlKind.allCases.enumerated()), id: \.element) { index, kind in
                        let angle = CGFloat(index) * (360.0 / CGFloat(ControlKind.allCases.count))
                        let radius: CGFloat = 50.0
                        let xOffset = cos(angle * .pi / 180) * radius
                        let yOffset = sin(angle * .pi / 180) * radius
                        
                        ControlNodeView(
                            control: ControlNode(
                                position: CGPoint(x: xOffset, y: yOffset),
                                ownerID: nil,
                                kind: kind
                            ),
                            zoomScale: 1.0,
                            ownerScreenPos: .zero
                        )
                        .offset(x: xOffset, y: yOffset)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.1).combined(with: .opacity),
                                removal: .scale(scale: 0.1).combined(with: .opacity)
                            )
                        )
                        .animation(
                            .spring(response: 0.3, dampingFraction: 0.7)
                                .delay(Double(index) * 0.05),
                            value: showControls
                        )
                    }
                }
                
                VStack {
                    Spacer()
                    Button(showControls ? "Hide Controls" : "Show Controls") {
                        withAnimation {
                            showControls.toggle()
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    return AnimationPreview()
}
