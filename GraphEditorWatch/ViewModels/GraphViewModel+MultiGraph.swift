//
//  GraphViewModel+MultiGraph.swift
//  GraphEditorWatch
//
//  Extension for multi-graph support (create, load, delete, list graphs)

import Foundation
import GraphEditorShared
import os

// MARK: - Multi-Graph Support
extension GraphViewModel {
    
    /// Creates a new empty graph and switches to it, resetting view state.
    @MainActor
    public func createNewGraph(name: String) async throws {
        // Save current view state before switching
        try saveViewState()
        
        try await model.createNewGraph(name: name)
        currentGraphName = model.currentGraphName
        
        // Reset view state for new graph
        offset = .zero
        zoomScale = 1.0
        selectedNodeID = nil
        selectedEdgeID = nil
        focusState = .graph
        
        await resumeSimulation()
    }
    
    @MainActor
    public func loadGraph(name: String) async throws {
        // Save current view state before switching
        try saveViewState()
        try await model.switchToGraph(named: name)
        currentGraphName = model.currentGraphName

        // Mark as in sub-graph
        isInSubGraph = true

        // Load view state for the new graph
        if let viewState = try? model.storage.loadViewState(for: currentGraphName) {
            offset = viewState.offset
            zoomScale = viewState.zoomScale
            selectedNodeID = viewState.selectedNodeID
            selectedEdgeID = viewState.selectedEdgeID
        } else {
            // No saved view state → reset to defaults
            offset = .zero
            zoomScale = 1.0
            selectedNodeID = nil
            selectedEdgeID = nil
        }

        focusState = .graph
        await resumeSimulation()
        Task { await startLayoutAnimation() }
    }

    /// Returns to the user graph from a sub-graph
    @MainActor
    public func returnToUserGraph() {
        isInSubGraph = false
        // Navigation handled in view layer
    }
    
    /// Deletes a graph by name.
    @MainActor
    public func deleteGraph(name: String) async throws {
        try await model.deleteGraph(named: name)
    }
    
    /// Lists all graph names.
    @MainActor
    public func listGraphNames() async throws -> [String] {
        try await model.listGraphNames()
    }
    
    /// Saves current view state for the current graph.
    public func saveViewState() throws {
        let viewState = ViewState(
            offset: offset,
            zoomScale: zoomScale,
            selectedNodeID: selectedNodeID,
            selectedEdgeID: selectedEdgeID
        )
        try model.storage.saveViewState(viewState, for: currentGraphName)
        
        #if DEBUG
        Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
            .debug("Saved view state for '\(self.currentGraphName)'")
        #endif
    }
}
