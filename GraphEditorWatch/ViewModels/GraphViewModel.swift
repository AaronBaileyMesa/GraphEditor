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
    @Published public var selectedNodeID: UUID? {
        didSet {
            Task { @MainActor in
                objectWillChange.send()
                redrawTrigger += 1  // Force redraw on selection change
                Self.logger.debug("Selected node changed to \(self.selectedNodeID?.uuidString.prefix(8) ?? "nil") – triggered controls update")
                // REMOVED: isAnimating sets – now synced via $isSimulating subscription
            }
        }
    }
    
    @Published public var offset: CGSize = .zero
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var currentGraphName: String = "default"
    @Published public var draggedNodeID: UUID?
    @Published public var redrawTrigger: Int = 0  // Increments to force view redraws
    @Published public var isAnimating: Bool = false  // True for active animations (simulation or transitions)
    @Published public var lastFrameTime: Date?  // For calculating elapsed time per frame
    @Published public var isAddingEdge: Bool = false  // FIXED: Added missing property
    @Published var isEditMode: Bool = false
    
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
        return model.nodes.first { $0.id == id }?.unwrapped is ToggleNode
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
            
            // Forward model's changes (store directly without assigning the whole chain)
            model.objectWillChange
                .receive(on: RunLoop.main)  // Use RunLoop.main for immediate execution in the current run loop
                .sink { [weak self] _ in
                    self?.redrawTrigger += 1  // NEW: Increment to trigger redraw
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
                await viewModel.model.addPlainChild(to: nodeID)  // Call existing model method (ensure it's public)
            }
        case .edit:
            return { viewModel, nodeID in
                viewModel.isEditMode.toggle()
                if viewModel.isEditMode {
                    await viewModel.generateControls(for: nodeID)  // Show extras
                    await viewModel.model.pauseSimulation()  // Or node-specific pause
                    viewModel.model.editingNodeID = nodeID  // Open editor sheet on enter (merged old action)
                } else {
                    await viewModel.clearControls()
                    await viewModel.model.resumeSimulation()
                    
                    // Fixed: Proper error handling instead of force-try
                    do {
                        try await viewModel.model.saveGraph()
                        Self.logger.info("Auto-saved graph on edit mode exit")
                    } catch {
                        Self.logger.error("Auto-save failed on edit mode exit: \(error.localizedDescription)")
                        // Optional: You could also notify the user here (e.g., via a haptic or alert),
                        // but logging is sufficient for a background auto-save.
                    }
                }
                WKInterfaceDevice.current().play(.click)
                Self.logger.debug("Toggled edit mode for node \(nodeID.uuidString.prefix(8)): \(viewModel.isEditMode)")
            }
        case .addEdge:
            return { viewModel, nodeID in
                if viewModel.isEditMode {
                    viewModel.startAddingEdge(from: nodeID)  // Proceed only in edit mode
                } else {
                    Self.logger.warning("Add edge attempted outside edit mode for node \(nodeID.uuidString.prefix(8))")
                    // Optional: viewModel.isEditMode = true; await viewModel.generateControls(for: nodeID)  // Auto-enter mode if desired
                }
            }
        }
    }
}
