//
//  GraphViewModel.swift
//  GraphEditorWatch
//
//  Created by handcart on 10/3/25.
//
//  Core ViewModel for GraphEditor. Extended in separate files:
//  - GraphViewModel+Helpers.swift: Internal helpers (saveAfterDelay)
//  - GraphViewModel+NodeOperations.swift: Node/Edge CRUD, undo/redo
//  - GraphViewModel+Simulation.swift: Physics simulation coordination
//  - GraphViewModel+MultiGraph.swift: Multi-graph support
//  - GraphViewModel+Controls.swift: Control node management
//  - GraphViewModel+ViewState.swift: Zoom, offset, selection, tap handling

import Combine
import GraphEditorShared
import WatchKit
import os

// MARK: - GraphViewModel

@MainActor public class GraphViewModel: ObservableObject {
    
    // MARK: Published Properties
    @Published public var model: GraphModel
    @Published public var selectedEdgeID: UUID?
    @Published public var pendingEdgeType: EdgeType = .association
    @Published public var selectedNodeID: UUID?
    
    @Published public var offset: CGSize = .zero
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var currentGraphName: String = "default"
    @Published public var draggedNodeID: UUID?
    @Published public var isAnimating: Bool = false  // True for active animations (simulation or transitions)
    @Published public var lastFrameTime: Date?  // For calculating elapsed time per frame
    @Published public var isAddingEdge: Bool = false  // FIXED: Added missing property
    
    // MARK: Private Properties
    
    private var inactiveObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?
    private var pauseObserver: NSObjectProtocol?
    private var resumeObserver: NSObjectProtocol?
    
    internal var saveTimer: Timer?
    internal var resumeTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var hasInitiallyLaunched = false
    
    private static var logger: Logger {
        Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
    }
    
    // MARK: Computed Properties
    
    var isSelectedToggleNode: Bool {
        guard let id = selectedNodeID else { return false }
        if let node = model.nodes.first(where: { $0.id == id })?.unwrapped as? Node {
            return node.isCollapsible
        }
        return false
    }
    
    public var canUndo: Bool {
        model.canUndo
    }
    
    public var canRedo: Bool {
        model.canRedo
    }
    
    @MainActor
    public var effectiveCentroid: CGPoint {
        model.centroid ?? .zero
    }
    
    public enum AppFocusState: Equatable {
        case graph
        case node(UUID)
        case edge(UUID)
        case menu
    }
    
    @Published public var focusState: AppFocusState = .graph
    
    public init(model: GraphModel) {
            self.model = model
            self.currentGraphName = model.currentGraphName  // Sync on init
            
            // Forward model's changes to trigger view updates
            model.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
            
            pauseObserver = NotificationCenter.default.addObserver(forName: .graphSimulationPause, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in  // Ensure main for publishes
                    await self?.model.pauseSimulation()
                }
            }
            
            resumeObserver = NotificationCenter.default.addObserver(forName: .graphSimulationResume, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in  // Ensure main for publishes
                    await self?.resumeSimulationAfterDelay()
                }
            }
            
            inactiveObserver = NotificationCenter.default.addObserver(forName: WKApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
                NotificationCenter.default.post(name: .graphSimulationPause, object: nil)  // Trigger existing pause logic
            }
            
            activeObserver = NotificationCenter.default.addObserver(forName: WKApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                // FIXED: Don't auto-resume on initial launch - only when returning from background
                Task { @MainActor in
                    guard let self = self, self.hasInitiallyLaunched else {
                        self?.hasInitiallyLaunched = true
                        return
                    }
                    NotificationCenter.default.post(name: .graphSimulationResume, object: nil)  // Trigger existing resume logic
                }
            }
            
            // NEW: Sync isAnimating to model's simulation state (handles resumption after controls added)
            model.$isSimulating
                .receive(on: RunLoop.main)  // Use RunLoop.main for immediate updates
                .sink { [weak self] isSimulating in
                    self?.isAnimating = isSimulating
                    Self.logger.debug("Synced isAnimating to \(isSimulating) from model.isSimulating")
                }
                .store(in: &cancellables)
            
            // Setup control subscriptions (consolidated to one call)
            model.setupControlSubscriptions(
                selectedNodePublisher: $selectedNodeID.eraseToAnyPublisher()
            )
        }
    
    /// Centers and fits the graph to the view — intended for initial load or explicit user action only
    @MainActor
    // MARK: - Viewport Fitting (Correct & Clean)
    deinit {
        if let pause = pauseObserver { NotificationCenter.default.removeObserver(pause) }
        if let resume = resumeObserver { NotificationCenter.default.removeObserver(resume) }
        if let inactive = inactiveObserver { NotificationCenter.default.removeObserver(inactive) }
        if let active = activeObserver { NotificationCenter.default.removeObserver(active) }
    }
}

extension ControlKind {
    // Added: small logger specific to ControlKind so the extension can log without referencing GraphViewModel
    private static var logger: Logger { Logger(subsystem: "io.handcart.GraphEditor", category: "controlkind") }

    /// Returns a default action closure for this kind (watch-specific).
    /// - Returns: A closure that performs the action using GraphViewModel and owner NodeID.
    public func defaultAction() -> @MainActor (GraphViewModel, NodeID) async -> Void {  // FIXED: Added @MainActor for isolation
        switch self {
        case .addChild:
            return { viewModel, nodeID in
                let success = await viewModel.model.addPlainChild(to: nodeID)
                if success {
                    WKInterfaceDevice.current().play(.click)
                    Self.logger.debug("Added plain child to node \(nodeID.uuidString.prefix(8))")
                } else {
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        case .edit:
            return { viewModel, nodeID in
                // Simply open the edit content sheet
                viewModel.model.editingNodeID = nodeID
                WKInterfaceDevice.current().play(.click)
                Self.logger.debug("Opened edit sheet for node \(nodeID.uuidString.prefix(8))")
            }
        case .addEdge:
            return { viewModel, nodeID in
                // Start adding edge mode directly
                viewModel.startAddingEdge(from: nodeID)
                Self.logger.debug("Started adding edge from node \(nodeID.uuidString.prefix(8))")
            }
        case .delete:
            return { viewModel, nodeID in
                // Delete the node
                await viewModel.deleteNode(withID: nodeID)
                WKInterfaceDevice.current().play(.click)
                Self.logger.debug("Deleted node \(nodeID.uuidString.prefix(8))")
            }
        case .duplicate:
            return { viewModel, nodeID in
                // Duplicate the node (simulation is already paused from control selection)
                if let newID = await viewModel.model.duplicateNode(withID: nodeID) {
                    WKInterfaceDevice.current().play(.click)
                    Self.logger.debug("Duplicated node \(nodeID.uuidString.prefix(8)) to \(newID.uuidString.prefix(8))")
                    
                    // Give SwiftUI time to render the new node while paused
                    try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms for one frame at 60fps
                    
                    // Select the duplicate - this triggers control generation via subscription
                    viewModel.selectedNodeID = newID
                }
            }
        case .addToggleChild:
            return { viewModel, nodeID in
                // Add a toggle node child
                let success = await viewModel.model.addToggleChild(to: nodeID)
                if success {
                    WKInterfaceDevice.current().play(.click)
                    Self.logger.debug("Added toggle child to node \(nodeID.uuidString.prefix(8))")
                } else {
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        case .toggleExpand:
            return { viewModel, nodeID in
                // Toggle expansion state of collapsible node
                await viewModel.toggleExpansion(for: nodeID)
                WKInterfaceDevice.current().play(.click)
                Self.logger.debug("Toggled expansion for node \(nodeID.uuidString.prefix(8))")
            }
        }
    }
}
