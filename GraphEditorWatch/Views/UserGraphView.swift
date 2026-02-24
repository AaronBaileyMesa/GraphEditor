//
//  UserGraphView.swift
//  GraphEditorWatch
//
//  Main canvas view for the User Graph showing all sub-graphs as GraphNodes
//

import SwiftUI
import GraphEditorShared

struct UserGraphView: View {
    @ObservedObject var userGraphViewModel: UserGraphViewModel
    @ObservedObject var graphViewModel: GraphViewModel  // For navigation to sub-graphs

    @State private var selectedGraphName: String?
    @State private var showMenu: Bool = false
    @State private var draggedGraphName: String?
    @State private var dragOffset: CGPoint = .zero
    @State private var panStartOffset: CGSize?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .edgesIgnoringSafeArea(.all)

                // Graph nodes
                ForEach(userGraphViewModel.graphNodes, id: \.id) { graphNode in
                    GraphNodeView(
                        graphNode: graphNode,
                        zoomScale: userGraphViewModel.zoomScale,
                        offset: userGraphViewModel.offset,
                        viewSize: geometry.size,
                        isSelected: selectedGraphName == graphNode.graphName
                    )
                    .onTapGesture {
                        handleGraphNodeTap(graphNode)
                    }
                }

                // User edges (Phase 3)
                UserEdgesView(
                    edges: userGraphViewModel.userEdges,
                    graphNodes: userGraphViewModel.graphNodes,
                    zoomScale: userGraphViewModel.zoomScale,
                    offset: userGraphViewModel.offset,
                    viewSize: geometry.size
                )

                // Pinned nodes (Phase 4)
                PinnedNodesView(
                    pinnedNodes: userGraphViewModel.pinnedNodes,
                    graphViewModel: graphViewModel,
                    zoomScale: userGraphViewModel.zoomScale,
                    offset: userGraphViewModel.offset,
                    viewSize: geometry.size,
                    onTap: handlePinnedNodeTap
                )
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        handleDragChanged(value, viewSize: geometry.size)
                    }
                    .onEnded { value in
                        handleDragEnded(value, viewSize: geometry.size)
                    }
            )
            .onAppear {
                userGraphViewModel.viewSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                userGraphViewModel.viewSize = newSize
            }
        }
        .navigationTitle("All Graphs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showMenu = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showMenu) {
            NavigationStack {
                UserGraphMenuView(
                    userGraphViewModel: userGraphViewModel,
                    graphViewModel: graphViewModel,
                    onDismiss: { showMenu = false }
                )
            }
        }
    }

    // MARK: - Gesture Handlers

    private func handleGraphNodeTap(_ graphNode: GraphNode) {
        selectedGraphName = graphNode.graphName
        Task {
            do {
                try await graphViewModel.loadGraph(name: graphNode.graphName)
            } catch {
                print("Failed to load graph: \(error.localizedDescription)")
            }
        }
    }

    private func handlePinnedNodeTap(_ pin: PinnedNodeReference) {
        Task {
            do {
                // Load the source graph
                try await graphViewModel.loadGraph(name: pin.sourceGraphName)
                // Select the pinned node
                graphViewModel.selectedNodeID = pin.sourceNodeID
            } catch {
                print("Failed to navigate to pinned node: \(error.localizedDescription)")
            }
        }
    }

    private func handleDragChanged(_ value: DragGesture.Value, viewSize: CGSize) {
        let magnitude = hypot(value.translation.width, value.translation.height)

        // Start dragging a graph node if threshold exceeded
        if draggedGraphName == nil && magnitude > 5.0 {
            // Check if we started on a graph node
            if let hitNode = graphNodeAt(value.startLocation, viewSize: viewSize) {
                draggedGraphName = hitNode.graphName
                let screenPos = value.startLocation
                let modelPos = screenToModel(screenPos, viewSize: viewSize)
                dragOffset = modelPos - hitNode.position
            } else {
                // Start panning
                panStartOffset = value.translation
            }
        }

        // Dragging a graph node
        if let draggedName = draggedGraphName {
            if let index = userGraphViewModel.graphNodes.firstIndex(where: { $0.graphName == draggedName }) {
                let screenPos = value.location
                let modelPos = screenToModel(screenPos, viewSize: viewSize)
                let newPos = modelPos - dragOffset

                // Update the graph node position in the view model
                var updatedNode = userGraphViewModel.graphNodes[index]
                updatedNode = updatedNode.with(position: newPos, velocity: .zero)
                userGraphViewModel.graphNodes[index] = updatedNode
            }
        }

        // Panning the canvas
        if draggedGraphName == nil {
            let delta = CGSize(
                width: value.translation.width - (panStartOffset?.width ?? 0),
                height: value.translation.height - (panStartOffset?.height ?? 0)
            )
            userGraphViewModel.offset.width += delta.width / userGraphViewModel.zoomScale
            userGraphViewModel.offset.height += delta.height / userGraphViewModel.zoomScale
            panStartOffset = value.translation
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value, viewSize: CGSize) {
        let magnitude = hypot(value.translation.width, value.translation.height)

        // If we were dragging a graph node, save its position
        if let draggedName = draggedGraphName {
            if let node = userGraphViewModel.graphNodes.first(where: { $0.graphName == draggedName }) {
                Task {
                    await userGraphViewModel.updateGraphNodePosition(draggedName, to: node.position)
                }
            }
            draggedGraphName = nil
            dragOffset = .zero
        } else if magnitude < 5.0 {
            // Treat as tap if no movement
            if let hitNode = graphNodeAt(value.location, viewSize: viewSize) {
                handleGraphNodeTap(hitNode)
            }
        }

        panStartOffset = nil
    }

    // MARK: - Helper Methods

    private func graphNodeAt(_ screenPos: CGPoint, viewSize: CGSize) -> GraphNode? {
        let modelPos = screenToModel(screenPos, viewSize: viewSize)

        for graphNode in userGraphViewModel.graphNodes {
            let distance = hypot(modelPos.x - graphNode.position.x, modelPos.y - graphNode.position.y)
            if distance <= graphNode.displayRadius {
                return graphNode
            }
        }
        return nil
    }

    private func screenToModel(_ screenPos: CGPoint, viewSize: CGSize) -> CGPoint {
        let centeredX = screenPos.x - viewSize.width / 2
        let centeredY = screenPos.y - viewSize.height / 2
        let modelX = (centeredX / userGraphViewModel.zoomScale) - userGraphViewModel.offset.width
        let modelY = (centeredY / userGraphViewModel.zoomScale) - userGraphViewModel.offset.height
        return CGPoint(x: modelX, y: modelY)
    }
}

/// Individual GraphNode view on the user graph canvas
struct GraphNodeView: View {
    let graphNode: GraphNode
    let zoomScale: CGFloat
    let offset: CGSize
    let viewSize: CGSize
    let isSelected: Bool

    private var screenPosition: CGPoint {
        let scaledX = graphNode.position.x * zoomScale + offset.width
        let scaledY = graphNode.position.y * zoomScale + offset.height
        return CGPoint(
            x: scaledX + viewSize.width / 2,
            y: scaledY + viewSize.height / 2
        )
    }

    var body: some View {
        ZStack {
            // Use the GraphNode's renderView
            graphNode.renderView(zoomScale: zoomScale, isSelected: isSelected)
        }
        .position(screenPosition)
    }
}

/// Renders user edges between graphs
struct UserEdgesView: View {
    let edges: [UserGraphEdge]
    let graphNodes: [GraphNode]
    let zoomScale: CGFloat
    let offset: CGSize
    let viewSize: CGSize

    var body: some View {
        Canvas { context, _ in
            for edge in edges {
                guard let fromNode = graphNodes.first(where: { $0.graphName == edge.fromGraph }),
                      let toNode = graphNodes.first(where: { $0.graphName == edge.toGraph }) else {
                    continue
                }

                let fromScreen = modelToScreen(fromNode.position)
                let toScreen = modelToScreen(toNode.position)

                var path = Path()
                path.move(to: fromScreen)
                path.addLine(to: toScreen)

                context.stroke(
                    path,
                    with: .color(.blue.opacity(0.6)),
                    lineWidth: 2.0 * zoomScale
                )

                // Draw label if present
                if let label = edge.label {
                    let midPoint = CGPoint(
                        x: (fromScreen.x + toScreen.x) / 2,
                        y: (fromScreen.y + toScreen.y) / 2
                    )
                    let labelText = Text(label)
                        .font(.system(size: 10 * zoomScale))
                        .foregroundColor(.white)
                    context.draw(labelText, at: midPoint)
                }
            }
        }
    }

    private func modelToScreen(_ modelPos: CGPoint) -> CGPoint {
        let scaledX = modelPos.x * zoomScale + offset.width
        let scaledY = modelPos.y * zoomScale + offset.height
        return CGPoint(
            x: scaledX + viewSize.width / 2,
            y: scaledY + viewSize.height / 2
        )
    }
}

/// Renders pinned nodes on the user graph
struct PinnedNodesView: View {
    let pinnedNodes: [PinnedNodeReference]
    let graphViewModel: GraphViewModel
    let zoomScale: CGFloat
    let offset: CGSize
    let viewSize: CGSize
    let onTap: (PinnedNodeReference) -> Void

    var body: some View {
        ForEach(pinnedNodes, id: \.id) { pin in
            PinnedNodePreview(
                pin: pin,
                zoomScale: zoomScale,
                offset: offset,
                viewSize: viewSize
            )
            .onTapGesture {
                onTap(pin)
            }
        }
    }
}

/// Preview of a pinned node
struct PinnedNodePreview: View {
    let pin: PinnedNodeReference
    let zoomScale: CGFloat
    let offset: CGSize
    let viewSize: CGSize

    private var screenPosition: CGPoint {
        let scaledX = pin.position.x * zoomScale + offset.width
        let scaledY = pin.position.y * zoomScale + offset.height
        return CGPoint(
            x: scaledX + viewSize.width / 2,
            y: scaledY + viewSize.height / 2
        )
    }

    var body: some View {
        VStack(spacing: 2 * zoomScale) {
            // Pin icon
            Image(systemName: "pin.fill")
                .font(.system(size: 12 * zoomScale))
                .foregroundColor(.yellow)
            
            // Node preview circle
            Circle()
                .fill(Color.blue.opacity(0.7))
                .frame(width: 20 * zoomScale, height: 20 * zoomScale)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1.5)
                )
            
            // Label
            Text(pin.cachedLabel)
                .font(.system(size: 8 * zoomScale))
                .foregroundColor(.white)
        }
        .position(screenPosition)
    }
}

/// Menu for user graph (Phase 2 minimal, expand in Phase 3+)
struct UserGraphMenuView: View {
    @ObservedObject var userGraphViewModel: UserGraphViewModel
    @ObservedObject var graphViewModel: GraphViewModel
    let onDismiss: () -> Void

    @State private var newGraphName: String = ""
    @State private var showNewGraphSheet: Bool = false
    @State private var showDeleteGraphSheet: Bool = false
    @State private var showCreateEdgeSheet: Bool = false
    @State private var showManagePinsSheet: Bool = false
    @State private var errorMessage: String?
    @State private var edgeFromGraph: String = ""
    @State private var edgeToGraph: String = ""
    @State private var edgeLabel: String = ""
    @State private var graphToDelete: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("User Graph").font(.subheadline.bold())

                // New Graph button
                MenuButton(
                    action: {
                        showNewGraphSheet = true
                    },
                    label: {
                        Label("New Graph", systemImage: "plus.circle")
                    },
                    accessibilityIdentifier: "newGraphButton"
                )

                // Create Edge button
                MenuButton(
                    action: {
                        showCreateEdgeSheet = true
                    },
                    label: {
                        Label("Create Edge", systemImage: "arrow.right.circle")
                    },
                    accessibilityIdentifier: "createEdgeButton"
                )

                // Manage Pins button
                if !userGraphViewModel.pinnedNodes.isEmpty {
                    MenuButton(
                        action: {
                            showManagePinsSheet = true
                        },
                        label: {
                            Label("Manage Pins", systemImage: "pin.slash")
                        },
                        accessibilityIdentifier: "managePinsButton"
                    )
                }
                
                // Delete Graph button
                MenuButton(
                    action: {
                        showDeleteGraphSheet = true
                    },
                    label: {
                        Label("Delete Graph", systemImage: "trash")
                    },
                    accessibilityIdentifier: "deleteGraphButton"
                )

                // Refresh button
                MenuButton(
                    action: {
                        Task {
                            await userGraphViewModel.syncFromStorage()
                        }
                        onDismiss()
                    },
                    label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    },
                    accessibilityIdentifier: "refreshButton"
                )

                if let error = errorMessage {
                    Text(error).foregroundColor(.red).font(.caption2)
                }
            }
            .padding(4)
        }
        .navigationTitle("User Graph Menu")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onDismiss() }
            }
        }
        .sheet(isPresented: $showNewGraphSheet) {
            VStack(spacing: 8) {
                Text("New Graph").font(.headline)
                TextField("Graph Name", text: $newGraphName)
                    .font(.caption)

                Button("Create") {
                    Task {
                        do {
                            try await graphViewModel.model.createNewGraph(name: newGraphName)
                            await userGraphViewModel.addGraphNode(for: newGraphName)
                            newGraphName = ""
                            showNewGraphSheet = false
                            onDismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel") {
                    showNewGraphSheet = false
                }
            }
            .padding()
        }
        .sheet(isPresented: $showCreateEdgeSheet) {
            VStack(spacing: 8) {
                Text("Create Edge").font(.headline)
                
                Picker("From Graph", selection: $edgeFromGraph) {
                    Text("Select...").tag("")
                    ForEach(userGraphViewModel.graphNodes, id: \.graphName) { node in
                        Text(node.displayName).tag(node.graphName)
                    }
                }
                .font(.caption)
                
                Picker("To Graph", selection: $edgeToGraph) {
                    Text("Select...").tag("")
                    ForEach(userGraphViewModel.graphNodes, id: \.graphName) { node in
                        Text(node.displayName).tag(node.graphName)
                    }
                }
                .font(.caption)
                
                TextField("Label (optional)", text: $edgeLabel)
                    .font(.caption)

                Button("Create") {
                    Task {
                        guard !edgeFromGraph.isEmpty && !edgeToGraph.isEmpty else {
                            errorMessage = "Please select both graphs"
                            return
                        }
                        guard edgeFromGraph != edgeToGraph else {
                            errorMessage = "Cannot create edge to same graph"
                            return
                        }
                        
                        let label = edgeLabel.isEmpty ? nil : edgeLabel
                        await userGraphViewModel.addUserEdge(from: edgeFromGraph, to: edgeToGraph, label: label)
                        
                        edgeFromGraph = ""
                        edgeToGraph = ""
                        edgeLabel = ""
                        showCreateEdgeSheet = false
                        onDismiss()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel") {
                    showCreateEdgeSheet = false
                }
            }
            .padding()
        }
        .sheet(isPresented: $showDeleteGraphSheet) {
            VStack(spacing: 8) {
                Text("Delete Graph").font(.headline)
                
                Picker("Graph to Delete", selection: $graphToDelete) {
                    Text("Select...").tag(nil as String?)
                    ForEach(userGraphViewModel.graphNodes, id: \.graphName) { node in
                        Text(node.displayName).tag(node.graphName as String?)
                    }
                }
                .font(.caption)

                Button("Delete") {
                    Task {
                        guard let nameToDelete = graphToDelete else {
                            errorMessage = "Please select a graph"
                            return
                        }
                        
                        do {
                            try await graphViewModel.deleteGraph(name: nameToDelete)
                            await userGraphViewModel.removeGraphNode(for: nameToDelete)
                            graphToDelete = nil
                            showDeleteGraphSheet = false
                            onDismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel") {
                    showDeleteGraphSheet = false
                }
            }
            .padding()
        }
        .sheet(isPresented: $showManagePinsSheet) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 8) {
                        Text("Pinned Nodes").font(.subheadline.bold())
                        
                        ForEach(userGraphViewModel.pinnedNodes, id: \.id) { pin in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pin.cachedLabel)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text("from \(pin.sourceGraphName)")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Button {
                                    Task {
                                        await userGraphViewModel.unpinNode(pin.id)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding(8)
                }
                .navigationTitle("Manage Pins")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            showManagePinsSheet = false
                            onDismiss()
                        }
                    }
                }
            }
        }
    }
}
