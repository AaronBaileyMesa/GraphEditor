//
//  UserGraphViewModel.swift
//  GraphEditorWatch
//
//  ViewModel for the User Graph canvas showing all sub-graphs as GraphNodes
//

import Combine
import GraphEditorShared
import SwiftUI
import os

@MainActor
public class UserGraphViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published public var graphNodes: [GraphNode] = []
    @Published public var pinnedNodes: [PinnedNodeReference] = []
    @Published public var userEdges: [UserGraphEdge] = []
    @Published public var offset: CGSize = .zero
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var selectedGraphName: String?
    @Published public var viewSize: CGSize = .zero

    // MARK: - Private Properties

    private let storage: GraphStorage
    private var userGraphState: UserGraphState
    private var cancellables = Set<AnyCancellable>()

    private static var logger: Logger {
        Logger(subsystem: "io.handcart.GraphEditor", category: "usergraph")
    }

    // MARK: - Initialization

    public init(storage: GraphStorage) {
        self.storage = storage
        self.userGraphState = UserGraphState()

        Task {
            await syncFromStorage()
        }
    }

    // MARK: - Storage Sync

    /// Syncs the user graph from storage: rebuilds GraphNodes from available graphs and applies saved state
    public func syncFromStorage() async {
        do {
            // Load user graph state (positions, edges, pins)
            if let loadedState = try await storage.loadUserGraphState() {
                self.userGraphState = loadedState
                self.offset = loadedState.viewState.offset
                self.zoomScale = loadedState.viewState.zoomScale
                self.pinnedNodes = loadedState.pinnedNodes
                self.userEdges = loadedState.userEdges
                Self.logger.debug("Loaded user graph state with \(loadedState.graphPositions.count) positions")
            } else {
                Self.logger.debug("No user graph state found, starting fresh")
            }

            // Get all available graphs
            let graphNames = try await storage.listGraphNames()

            // Build GraphNodes for each graph
            var nodes: [GraphNode] = []
            var nextLabel = 1

            for graphName in graphNames {
                // Get node count from graph state
                let graphState = try? await storage.loadGraphState(for: graphName)
                let nodeCount = graphState?.nodes.count ?? 0

                // Check if we have a saved position
                let position = userGraphState.graphPositions[graphName] ?? autoLayoutPosition(for: nodes.count, total: graphNames.count)

                // Create GraphNode
                let graphNode = GraphNode(
                    label: nextLabel,
                    position: position,
                    graphName: graphName,
                    displayName: graphName,  // TODO: Support custom display names
                    nodeCount: nodeCount,
                    lastModified: Date()  // TODO: Get actual modification time
                )

                nodes.append(graphNode)
                nextLabel += 1

                // Save auto-generated position if not already saved
                if userGraphState.graphPositions[graphName] == nil {
                    userGraphState.graphPositions[graphName] = position
                }
            }

            self.graphNodes = nodes
            Self.logger.debug("Synced \(nodes.count) graph nodes")

            // Save updated state (includes any new auto-layout positions)
            try await saveState()

        } catch {
            Self.logger.error("Failed to sync from storage: \(error.localizedDescription)")
        }
    }

    /// Auto-layout position for a new graph node (radial layout)
    private func autoLayoutPosition(for index: Int, total: Int) -> CGPoint {
        guard total > 1 else {
            return CGPoint(x: 250, y: 250)  // Center for single node
        }

        let radius: CGFloat = 150.0
        let angle = (2.0 * .pi * CGFloat(index)) / CGFloat(total)
        let x = 250 + radius * cos(angle)
        let y = 250 + radius * sin(angle)

        return CGPoint(x: x, y: y)
    }

    /// Saves current state to storage
    public func saveState() async throws {
        // Update view state in userGraphState
        userGraphState.viewState = ViewState(
            offset: offset,
            zoomScale: zoomScale,
            selectedNodeID: nil,
            selectedEdgeID: nil
        )

        try await storage.saveUserGraphState(userGraphState)
        Self.logger.debug("Saved user graph state")
    }

    // MARK: - Graph Node Management

    /// Updates a GraphNode's position (called after drag)
    public func updateGraphNodePosition(_ graphName: String, to position: CGPoint) async {
        userGraphState.graphPositions[graphName] = position

        // Update the GraphNode in the array
        if let index = graphNodes.firstIndex(where: { $0.graphName == graphName }) {
            graphNodes[index] = graphNodes[index].with(position: position, velocity: .zero)
        }

        do {
            try await saveState()
        } catch {
            Self.logger.error("Failed to save position update: \(error.localizedDescription)")
        }
    }

    /// Adds a new graph to the user graph (called after createNewGraph)
    public func addGraphNode(for graphName: String) async {
        let position = autoLayoutPosition(for: graphNodes.count, total: graphNodes.count + 1)

        let graphNode = GraphNode(
            label: graphNodes.count + 1,
            position: position,
            graphName: graphName,
            displayName: graphName,
            nodeCount: 0
        )

        graphNodes.append(graphNode)
        userGraphState.graphPositions[graphName] = position

        do {
            try await saveState()
        } catch {
            Self.logger.error("Failed to save new graph node: \(error.localizedDescription)")
        }
    }

    /// Removes a graph node (called after deleteGraph)
    public func removeGraphNode(for graphName: String) async {
        graphNodes.removeAll { $0.graphName == graphName }
        userGraphState.graphPositions.removeValue(forKey: graphName)

        // Remove associated pins and edges
        pinnedNodes.removeAll { $0.sourceGraphName == graphName }
        userGraphState.pinnedNodes.removeAll { $0.sourceGraphName == graphName }

        userEdges.removeAll { $0.fromGraph == graphName || $0.toGraph == graphName }
        userGraphState.userEdges.removeAll { $0.fromGraph == graphName || $0.toGraph == graphName }

        do {
            try await saveState()
        } catch {
            Self.logger.error("Failed to save after removing graph node: \(error.localizedDescription)")
        }
    }

    // MARK: - Pinned Nodes

    /// Adds a pinned node reference
    public func pinNode(
        from graphName: String,
        nodeID: UUID,
        label: String,
        nodeType: String,
        at position: CGPoint
    ) async {
        let pin = PinnedNodeReference(
            sourceGraphName: graphName,
            sourceNodeID: nodeID,
            position: position,
            cachedLabel: label,
            cachedNodeType: nodeType
        )

        pinnedNodes.append(pin)
        userGraphState.pinnedNodes.append(pin)

        do {
            try await saveState()
        } catch {
            Self.logger.error("Failed to save pinned node: \(error.localizedDescription)")
        }
    }

    /// Removes a pinned node reference
    public func unpinNode(_ pinID: UUID) async {
        pinnedNodes.removeAll { $0.id == pinID }
        userGraphState.pinnedNodes.removeAll { $0.id == pinID }

        do {
            try await saveState()
        } catch {
            Self.logger.error("Failed to save after unpinning: \(error.localizedDescription)")
        }
    }

    // MARK: - User Edges

    /// Adds a user edge between two graphs
    public func addUserEdge(from: String, to: String, label: String? = nil) async {
        let edge = UserGraphEdge(fromGraph: from, toGraph: to, label: label)

        userEdges.append(edge)
        userGraphState.userEdges.append(edge)

        do {
            try await saveState()
        } catch {
            Self.logger.error("Failed to save user edge: \(error.localizedDescription)")
        }
    }

    /// Removes a user edge
    public func removeUserEdge(_ edgeID: UUID) async {
        userEdges.removeAll { $0.id == edgeID }
        userGraphState.userEdges.removeAll { $0.id == edgeID }

        do {
            try await saveState()
        } catch {
            Self.logger.error("Failed to save after removing edge: \(error.localizedDescription)")
        }
    }
}
