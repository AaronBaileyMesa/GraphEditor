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

// swiftlint:disable file_length
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
    @Published public var viewSize: CGSize = .zero  // Current viewport size for centering nodes
    @Published public var showDashboard: Bool = false  // True when dashboard should be shown
    @Published public var showContactPicker: Bool = false  // True when contact picker should be shown
    @Published public var contactPickerForNodeID: UUID?  // NodeID for which contact picker is shown

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
    public func defaultAction() -> @MainActor (GraphViewModel, NodeID) async -> Void {
        // Action handler mapping to reduce cyclomatic complexity
        let actionHandlers: [ControlKind: @MainActor (GraphViewModel, NodeID) async -> Void] = [
            .addChild: Self.handleAddChild,
            .edit: Self.handleEdit,
            .addEdge: Self.handleAddEdge,
            .delete: Self.handleDelete,
            .duplicate: Self.handleDuplicate,
            .addToggleChild: Self.handleAddToggleChild,
            .toggleExpand: Self.handleToggleExpand,
            .openMenu: Self.handleOpenMenu,
            .startWorkflow: Self.handleStartWorkflow,
            .stopWorkflow: Self.handleStopWorkflow,
            .completeTask: Self.handleCompleteTask,
            .startTask: Self.handleStartTask,
            .blockTask: Self.handleBlockTask,
            .unblockTask: Self.handleUnblockTask,
            .declineTask: Self.handleDeclineTask,
            .resetTask: Self.handleResetTask,
            .addShopTask: Self.handleAddShopTask,
            .addPrepTask: Self.handleAddPrepTask,
            .addCookTask: Self.handleAddCookTask,
            .addRecipe: Self.handleAddRecipe,
            .scaleRecipe: Self.handleScaleRecipe,
            .createTacoOrder: Self.handleCreateTacoOrder,
            .linkContact: Self.handleLinkContact,
            .editPreferences: Self.handleEditPreferences,
            .addPersonNode: Self.handleAddPersonNode,
            .addMealNode: Self.handleAddMealNode,
            .addTacoNight: Self.handleAddTacoNight,
            .viewDashboard: Self.handleViewDashboard,
            .selectProtein: Self.handleSelectProtein,
            .selectShell: Self.handleSelectShell,
            .selectToppings: Self.handleSelectToppings,
            .selectVeggies: Self.handleSelectVeggies,
            .selectCreamy: Self.handleSelectCreamy,
            .selectHerbsZest: Self.handleSelectHerbsZest,
            .selectFireKick: Self.handleSelectFireKick,
            .backToCategories: Self.handleBackToCategories,
            .toggleBeef: Self.handleToggleBeef,
            .toggleChicken: Self.handleToggleChicken,
            .toggleCrunchyShell: Self.handleToggleCrunchyShell,
            .toggleSoftFlourShell: Self.handleToggleSoftFlourShell,
            .toggleSoftCornShell: Self.handleToggleSoftCornShell,
            .toggleLettuce: Self.handleToggleTopping("Lettuce"),
            .toggleTomatoes: Self.handleToggleTopping("Tomatoes"),
            .toggleCheese: Self.handleToggleTopping("Cheese"),
            .toggleSourCream: Self.handleToggleTopping("Sour Cream"),
            .toggleGuacamole: Self.handleToggleTopping("Guacamole"),
            .toggleSalsa: Self.handleToggleTopping("Salsa"),
            .toggleOnions: Self.handleToggleTopping("Onions"),
            .toggleCilantro: Self.handleToggleTopping("Cilantro"),
            .toggleJalapeños: Self.handleToggleTopping("Jalapeños"),
            .toggleHotSauce: Self.handleToggleTopping("Hot Sauce"),
            .toggleRadishes: Self.handleToggleTopping("Radishes"),
            .toggleLime: Self.handleToggleTopping("Lime"),
            .togglePickledJalapeños: Self.handleToggleTopping("Pickled Jalapeños")
        ]
        
        return actionHandlers[self] ?? { _, _ in
            Self.logger.warning("No handler found for control kind: \(String(describing: self))")
        }
    }
    
    // MARK: - Basic Node Operations
    
    @MainActor
    private static func handleAddChild(viewModel: GraphViewModel, nodeID: NodeID) async {
        let success = await viewModel.model.addPlainChild(to: nodeID)
        if success {
            WKInterfaceDevice.current().play(.click)
            logger.debug("Added plain child to node \(nodeID.uuidString.prefix(8))")
        } else {
            WKInterfaceDevice.current().play(.failure)
        }
    }
    
    @MainActor
    private static func handleEdit(viewModel: GraphViewModel, nodeID: NodeID) async {
        viewModel.model.editingNodeID = nodeID
        WKInterfaceDevice.current().play(.click)
        logger.debug("Opened edit sheet for node \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleOpenMenu(viewModel: GraphViewModel, nodeID: NodeID) async {
        // Select the node - this will show its specialized menu view via MenuView routing
        viewModel.selectedNodeID = nodeID
        WKInterfaceDevice.current().play(.click)
        logger.debug("Opened menu for node \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleAddEdge(viewModel: GraphViewModel, nodeID: NodeID) async {
        viewModel.startAddingEdge(from: nodeID)
        logger.debug("Started adding edge from node \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleDelete(viewModel: GraphViewModel, nodeID: NodeID) async {
        await viewModel.deleteNode(withID: nodeID)
        WKInterfaceDevice.current().play(.click)
        logger.debug("Deleted node \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleDuplicate(viewModel: GraphViewModel, nodeID: NodeID) async {
        if let newID = await viewModel.model.duplicateNode(withID: nodeID) {
            WKInterfaceDevice.current().play(.click)
            logger.debug("Duplicated node \(nodeID.uuidString.prefix(8)) to \(newID.uuidString.prefix(8))")
            
            // Give SwiftUI time to render the new node while paused
            try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms for one frame at 60fps
            
            // Select the duplicate
            viewModel.selectedNodeID = newID
            
            // Center the view on the duplicated node
            viewModel.centerNode(newID, viewSize: viewModel.viewSize)
            
            // Explicitly generate controls for the duplicated node
            await viewModel.generateControls(for: newID)
        }
    }
    
    @MainActor
    private static func handleAddToggleChild(viewModel: GraphViewModel, nodeID: NodeID) async {
        let success = await viewModel.model.addToggleChild(to: nodeID)
        if success {
            WKInterfaceDevice.current().play(.click)
            logger.debug("Added toggle child to node \(nodeID.uuidString.prefix(8))")
        } else {
            WKInterfaceDevice.current().play(.failure)
        }
    }
    
    @MainActor
    private static func handleToggleExpand(viewModel: GraphViewModel, nodeID: NodeID) async {
        await viewModel.toggleExpansion(for: nodeID)
        WKInterfaceDevice.current().play(.click)
        logger.debug("Toggled expansion for node \(nodeID.uuidString.prefix(8))")
    }
    
    // MARK: - Workflow Controls (Meal Planning)
    
    @MainActor
    private static func handleStartWorkflow(viewModel: GraphViewModel, nodeID: NodeID) async {
        viewModel.model.startWorkflow(for: nodeID)
        WKInterfaceDevice.current().play(.success)
        logger.debug("Started workflow for meal \(nodeID.uuidString.prefix(8))")
        
        // Auto-select and center the first task
        if let firstTask = viewModel.model.currentTask(for: nodeID) {
            viewModel.selectedNodeID = firstTask.id
            
            // Center the first task on screen
            if viewModel.viewSize != .zero {
                viewModel.centerNode(firstTask.id, viewSize: viewModel.viewSize)
            }
        }
    }
    
    @MainActor
    private static func handleStopWorkflow(viewModel: GraphViewModel, nodeID: NodeID) async {
        viewModel.model.stopWorkflow(for: nodeID)
        WKInterfaceDevice.current().play(.click)
        logger.debug("Stopped workflow for meal \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleCompleteTask(viewModel: GraphViewModel, nodeID: NodeID) async {
        // nodeID is the task node - need to find parent meal node
        guard let mealID = viewModel.model.findMealForTask(nodeID) else {
            logger.error("Could not find parent meal for task \(nodeID.uuidString.prefix(8))")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        
        // Complete current task and auto-advance
        if let nextTask = viewModel.model.completeCurrentTask(for: mealID, autoAdvance: true) {
            WKInterfaceDevice.current().play(.success)
            logger.debug("Completed task and started next: \(nextTask.taskType.rawValue)")
            
            // Auto-select the next task to show its controls
            viewModel.selectedNodeID = nextTask.id
            
            // Center the next task on screen
            if viewModel.viewSize != .zero {
                viewModel.centerNode(nextTask.id, viewSize: viewModel.viewSize)
            }
        } else {
            WKInterfaceDevice.current().play(.success)
            logger.debug("Completed final task for meal \(mealID.uuidString.prefix(8))")
            
            // Workflow complete - select the meal node to show completion state
            viewModel.selectedNodeID = mealID
            
            // Center the meal node on screen
            if viewModel.viewSize != .zero {
                viewModel.centerNode(mealID, viewSize: viewModel.viewSize)
            }
        }
    }
    
    @MainActor
    private static func handleStartTask(viewModel: GraphViewModel, nodeID: NodeID) async {
        viewModel.model.updateTaskStatus(nodeID, to: .inProgress)
        WKInterfaceDevice.current().play(.click)
        logger.debug("Started task \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleBlockTask(viewModel: GraphViewModel, nodeID: NodeID) async {
        viewModel.model.updateTaskStatus(nodeID, to: .blocked)
        WKInterfaceDevice.current().play(.click)
        logger.debug("Blocked task \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleUnblockTask(viewModel: GraphViewModel, nodeID: NodeID) async {
        viewModel.model.updateTaskStatus(nodeID, to: .inProgress)
        WKInterfaceDevice.current().play(.click)
        logger.debug("Unblocked task \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleDeclineTask(viewModel: GraphViewModel, nodeID: NodeID) async {
        viewModel.model.updateTaskStatus(nodeID, to: .declined)
        WKInterfaceDevice.current().play(.click)
        logger.debug("Declined task \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleResetTask(viewModel: GraphViewModel, nodeID: NodeID) async {
        viewModel.model.updateTaskStatus(nodeID, to: .pending)
        WKInterfaceDevice.current().play(.click)
        logger.debug("Reset task \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleAddShopTask(viewModel: GraphViewModel, nodeID: NodeID) async {
        await viewModel.model.addTaskToMeal(mealID: nodeID, taskType: .shop)
        WKInterfaceDevice.current().play(.click)
        logger.debug("Added shop task to meal \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleAddPrepTask(viewModel: GraphViewModel, nodeID: NodeID) async {
        await viewModel.model.addTaskToMeal(mealID: nodeID, taskType: .prep)
        WKInterfaceDevice.current().play(.click)
        logger.debug("Added prep task to meal \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleAddCookTask(viewModel: GraphViewModel, nodeID: NodeID) async {
        await viewModel.model.addTaskToMeal(mealID: nodeID, taskType: .cook)
        WKInterfaceDevice.current().play(.click)
        logger.debug("Added cook task to meal \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleAddRecipe(viewModel: GraphViewModel, nodeID: NodeID) async {
        // swiftlint:disable:next todo
        // FIXME: Implement recipe addition flow
        WKInterfaceDevice.current().play(.click)
        logger.debug("Add recipe to meal \(nodeID.uuidString.prefix(8)) - not yet implemented")
    }
    
    @MainActor
    private static func handleScaleRecipe(viewModel: GraphViewModel, nodeID: NodeID) async {
        // swiftlint:disable:next todo
        // FIXME: Implement recipe scaling flow
        WKInterfaceDevice.current().play(.click)
        logger.debug("Scale recipe \(nodeID.uuidString.prefix(8)) - not yet implemented")
    }
    
    @MainActor
    private static func handleCreateTacoOrder(viewModel: GraphViewModel, nodeID: NodeID) async {
        // Find the PersonNode
        guard let personNode = viewModel.model.nodes.first(where: { $0.id == nodeID })?.unwrapped as? PersonNode else {
            logger.error("Could not find PersonNode for \(nodeID.uuidString.prefix(8))")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        
        // Create a TacoNode
        let tacoPosition = CGPoint(
            x: personNode.position.x + 60,  // Offset to the right
            y: personNode.position.y
        )
        
        let tacoNode = TacoNode(
            label: viewModel.model.nextNodeLabel,
            position: tacoPosition
        )
        
        viewModel.model.nextNodeLabel += 1
        
        // Add the taco node to the model
        viewModel.model.nodes.append(AnyNode(tacoNode))
        
        // Create an edge from person to taco
        await viewModel.model.addEdge(from: nodeID, target: tacoNode.id, type: .association)
        
        WKInterfaceDevice.current().play(.success)
        logger.debug("Created taco order \(tacoNode.id.uuidString.prefix(8)) for person \(personNode.name)")
        
        // Select the new taco node
        viewModel.selectedNodeID = tacoNode.id
    }

    @MainActor
    private static func handleLinkContact(viewModel: GraphViewModel, nodeID: NodeID) async {
        // Verify this is a PersonNode
        guard viewModel.model.nodes.first(where: { $0.id == nodeID })?.unwrapped is PersonNode else {
            logger.error("linkContact called on non-PersonNode: \(nodeID.uuidString.prefix(8))")
            WKInterfaceDevice.current().play(.failure)
            return
        }

        // Set a flag to show contact picker - the view will handle this
        viewModel.showContactPicker = true
        viewModel.contactPickerForNodeID = nodeID

        WKInterfaceDevice.current().play(.click)
        logger.debug("Showing contact picker for PersonNode \(nodeID.uuidString.prefix(8))")
    }

    @MainActor
    private static func handleEditPreferences(viewModel: GraphViewModel, nodeID: NodeID) async {
        // Verify this is a PersonNode
        guard viewModel.model.nodes.first(where: { $0.id == nodeID })?.unwrapped is PersonNode else {
            logger.error("editPreferences called on non-PersonNode: \(nodeID.uuidString.prefix(8))")
            WKInterfaceDevice.current().play(.failure)
            return
        }

        // Open the edit sheet for this node
        viewModel.model.editingNodeID = nodeID

        WKInterfaceDevice.current().play(.click)
        logger.debug("Opening edit preferences for PersonNode \(nodeID.uuidString.prefix(8))")
    }

    // MARK: - RootNode Creation Controls
    
    @MainActor
    private static func handleAddPersonNode(viewModel: GraphViewModel, nodeID: NodeID) async {
        // Verify this is RootNode or PeopleListNode
        let ownerNode = viewModel.model.nodes.first(where: { $0.id == nodeID })?.unwrapped
        guard ownerNode is RootNode || ownerNode is PeopleListNode else {
            logger.error("addPersonNode called on invalid node type: \(nodeID.uuidString.prefix(8))")
            WKInterfaceDevice.current().play(.failure)
            return
        }

        // Create person with default "New Person" name immediately
        let person = await viewModel.model.addPersonToPeopleList()
        
        // Save
        try? await viewModel.model.saveGraph()
        
        // Select and zoom to the new person
        viewModel.setSelectedNode(person.id, zoomToFit: true)
        
        WKInterfaceDevice.current().play(.click)
        logger.debug("Created new person from \(type(of: ownerNode))")
    }
    
    @MainActor
    private static func handleAddMealNode(viewModel: GraphViewModel, nodeID: NodeID) async {
        // Verify this is RootNode
        guard viewModel.model.nodes.first(where: { $0.id == nodeID })?.unwrapped is RootNode else {
            logger.error("addMealNode called on non-RootNode: \(nodeID.uuidString.prefix(8))")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        
        let meal = await viewModel.model.addMealFromRoot()
        
        WKInterfaceDevice.current().play(.success)
        logger.debug("Created MealNode \(meal.id.uuidString.prefix(8)) from RootNode")
        
        // Give SwiftUI time to render the new node
        try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms for one frame at 60fps
        
        // Select the new meal node
        viewModel.selectedNodeID = meal.id
        
        // Center the view on the newly created MealNode
        viewModel.centerNode(meal.id, viewSize: viewModel.viewSize)
        
        // Explicitly generate controls for the new MealNode
        await viewModel.generateControls(for: meal.id)
    }
    
    @MainActor
    private static func handleAddTacoNight(viewModel: GraphViewModel, nodeID: NodeID) async {
        // Verify this is RootNode
        guard viewModel.model.nodes.first(where: { $0.id == nodeID })?.unwrapped is RootNode else {
            logger.error("addTacoNight called on non-RootNode: \(nodeID.uuidString.prefix(8))")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        
        // TODO: Launch TacoNightWizard modal
        // For now, just provide haptic feedback
        WKInterfaceDevice.current().play(.click)
        logger.debug("TacoNight wizard requested from RootNode (not yet implemented)")
    }
    
    @MainActor
    private static func handleViewDashboard(viewModel: GraphViewModel, nodeID: NodeID) async {
        // Verify this is RootNode
        guard viewModel.model.nodes.first(where: { $0.id == nodeID })?.unwrapped is RootNode else {
            logger.error("viewDashboard called on non-RootNode: \(nodeID.uuidString.prefix(8))")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        
        // Set flag to show dashboard
        viewModel.showDashboard = true
        WKInterfaceDevice.current().play(.click)
        logger.debug("Dashboard view requested from RootNode")
    }
    
    // MARK: - Taco Category Controls
    
    @MainActor
    private static func handleSelectProtein(viewModel: GraphViewModel, nodeID: NodeID) async {
        await setTacoCategory(.selectProtein, viewModel: viewModel, nodeID: nodeID)
    }

    @MainActor
    private static func handleSelectShell(viewModel: GraphViewModel, nodeID: NodeID) async {
        await setTacoCategory(.selectShell, viewModel: viewModel, nodeID: nodeID)
    }

    @MainActor
    private static func handleSelectToppings(viewModel: GraphViewModel, nodeID: NodeID) async {
        await setTacoCategory(.selectToppings, viewModel: viewModel, nodeID: nodeID)
    }

    @MainActor
    private static func setTacoCategory(_ kind: ControlKind, viewModel: GraphViewModel, nodeID: NodeID) async {
        viewModel.model.activeTacoCategory[nodeID] = kind
        await viewModel.model.updateEphemerals(selectedNodeID: nodeID)
        WKInterfaceDevice.current().play(.click)
    }

    @MainActor
    private static func handleSelectVeggies(viewModel: GraphViewModel, nodeID: NodeID) async {
        await setToppingSubCategory(.selectVeggies, viewModel: viewModel, nodeID: nodeID)
    }

    @MainActor
    private static func handleSelectCreamy(viewModel: GraphViewModel, nodeID: NodeID) async {
        await setToppingSubCategory(.selectCreamy, viewModel: viewModel, nodeID: nodeID)
    }

    @MainActor
    private static func handleSelectHerbsZest(viewModel: GraphViewModel, nodeID: NodeID) async {
        await setToppingSubCategory(.selectHerbsZest, viewModel: viewModel, nodeID: nodeID)
    }

    @MainActor
    private static func handleSelectFireKick(viewModel: GraphViewModel, nodeID: NodeID) async {
        await setToppingSubCategory(.selectFireKick, viewModel: viewModel, nodeID: nodeID)
    }

    @MainActor
    private static func setToppingSubCategory(_ kind: ControlKind, viewModel: GraphViewModel, nodeID: NodeID) async {
        viewModel.model.activeToppingSubCategory[nodeID] = kind
        await viewModel.model.updateEphemerals(selectedNodeID: nodeID)
        WKInterfaceDevice.current().play(.click)
    }
    
    @MainActor
    private static func handleBackToCategories(viewModel: GraphViewModel, nodeID: NodeID) async {
        // Navigate back one level at a time:
        // sub-category level → toppings sub-category menu → top-level categories
        if viewModel.model.activeToppingSubCategory[nodeID] != nil {
            viewModel.model.activeToppingSubCategory.removeValue(forKey: nodeID)
            // Stay in selectToppings so sub-category nodes remain visible
        } else {
            viewModel.model.activeTacoCategory.removeValue(forKey: nodeID)
        }

        await viewModel.model.updateEphemerals(selectedNodeID: nodeID)

        WKInterfaceDevice.current().play(.click)
        logger.debug("Navigated back for taco \(nodeID.uuidString.prefix(8))")
    }


    
    // MARK: - Taco Configuration Controls
    
    @MainActor
    private static func handleToggleBeef(viewModel: GraphViewModel, nodeID: NodeID) async {
        guard let index = viewModel.model.nodes.firstIndex(where: { $0.id == nodeID }),
              var tacoNode = viewModel.model.nodes[index].unwrapped as? TacoNode else {
            logger.error("Could not find TacoNode for \(nodeID.uuidString.prefix(8))")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        
        // Toggle beef selection (exclusive with chicken)
        tacoNode = tacoNode.with(protein: tacoNode.protein == .beef ? nil : .beef)
        viewModel.model.nodes[index] = AnyNode(tacoNode)
        
        // Refresh control nodes to update selection state
        await viewModel.model.updateEphemerals(selectedNodeID: nodeID)
        
        WKInterfaceDevice.current().play(.click)
        logger.debug("Toggled beef for taco \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleToggleChicken(viewModel: GraphViewModel, nodeID: NodeID) async {
        guard let index = viewModel.model.nodes.firstIndex(where: { $0.id == nodeID }),
              var tacoNode = viewModel.model.nodes[index].unwrapped as? TacoNode else {
            logger.error("Could not find TacoNode for \(nodeID.uuidString.prefix(8))")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        
        // Toggle chicken selection (exclusive with beef)
        tacoNode = tacoNode.with(protein: tacoNode.protein == .chicken ? nil : .chicken)
        viewModel.model.nodes[index] = AnyNode(tacoNode)
        
        // Refresh control nodes to update selection state
        await viewModel.model.updateEphemerals(selectedNodeID: nodeID)
        
        WKInterfaceDevice.current().play(.click)
        logger.debug("Toggled chicken for taco \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleToggleCrunchyShell(viewModel: GraphViewModel, nodeID: NodeID) async {
        guard let index = viewModel.model.nodes.firstIndex(where: { $0.id == nodeID }),
              var tacoNode = viewModel.model.nodes[index].unwrapped as? TacoNode else {
            logger.error("Could not find TacoNode for \(nodeID.uuidString.prefix(8))")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        
        // Toggle crunchy shell selection (exclusive with other shells)
        tacoNode = tacoNode.with(shell: tacoNode.shell == .crunchy ? nil : .crunchy)
        viewModel.model.nodes[index] = AnyNode(tacoNode)
        
        // Refresh control nodes to update selection state
        await viewModel.model.updateEphemerals(selectedNodeID: nodeID)
        
        WKInterfaceDevice.current().play(.click)
        logger.debug("Toggled crunchy shell for taco \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleToggleSoftFlourShell(viewModel: GraphViewModel, nodeID: NodeID) async {
        guard let index = viewModel.model.nodes.firstIndex(where: { $0.id == nodeID }),
              var tacoNode = viewModel.model.nodes[index].unwrapped as? TacoNode else {
            logger.error("Could not find TacoNode for \(nodeID.uuidString.prefix(8))")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        
        // Toggle soft flour shell selection (exclusive with other shells)
        tacoNode = tacoNode.with(shell: tacoNode.shell == .softFlour ? nil : .softFlour)
        viewModel.model.nodes[index] = AnyNode(tacoNode)
        
        // Refresh control nodes to update selection state
        await viewModel.model.updateEphemerals(selectedNodeID: nodeID)
        
        WKInterfaceDevice.current().play(.click)
        logger.debug("Toggled soft flour shell for taco \(nodeID.uuidString.prefix(8))")
    }
    
    @MainActor
    private static func handleToggleSoftCornShell(viewModel: GraphViewModel, nodeID: NodeID) async {
        guard let index = viewModel.model.nodes.firstIndex(where: { $0.id == nodeID }),
              var tacoNode = viewModel.model.nodes[index].unwrapped as? TacoNode else {
            logger.error("Could not find TacoNode for \(nodeID.uuidString.prefix(8))")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        
        // Toggle soft corn shell selection (exclusive with other shells)
        tacoNode = tacoNode.with(shell: tacoNode.shell == .softCorn ? nil : .softCorn)
        viewModel.model.nodes[index] = AnyNode(tacoNode)
        
        // Refresh control nodes to update selection state
        await viewModel.model.updateEphemerals(selectedNodeID: nodeID)
        
        WKInterfaceDevice.current().play(.click)
        logger.debug("Toggled soft corn shell for taco \(nodeID.uuidString.prefix(8))")
    }
    
    private static func handleToggleTopping(_ topping: String) -> @MainActor (GraphViewModel, NodeID) async -> Void {
        return { @MainActor viewModel, nodeID in
            guard let index = viewModel.model.nodes.firstIndex(where: { $0.id == nodeID }),
                  var tacoNode = viewModel.model.nodes[index].unwrapped as? TacoNode else {
                logger.error("Could not find TacoNode for \(nodeID.uuidString.prefix(8))")
                WKInterfaceDevice.current().play(.failure)
                return
            }
            
            var toppings = tacoNode.toppings
            if let existingIndex = toppings.firstIndex(of: topping) {
                // Remove topping
                toppings.remove(at: existingIndex)
            } else {
                // Add topping
                toppings.append(topping)
            }
            
            tacoNode = tacoNode.with(toppings: toppings)
            viewModel.model.nodes[index] = AnyNode(tacoNode)
            
            // Refresh control nodes to update selection state
            await viewModel.model.updateEphemerals(selectedNodeID: nodeID)
            
            WKInterfaceDevice.current().play(.click)
            logger.debug("Toggled \(topping) for taco \(nodeID.uuidString.prefix(8))")
        }
    }
}
