# Node Type Architecture Refactor Plan

**Goal:** Enable rich, extensible node types with custom physics, visuals, animations, haptics, and behaviors without scattered type-checking or duplicated logic.

**Date:** 2026-02-13
**Status:** Planning Phase

---

## Executive Summary

Current architecture requires 4-9 file changes to add a new node type. This refactor will reduce that to 1-2 files by introducing:

1. **NodeTypeDescriptor** - Declarative configuration for physics, rendering, interaction
2. **Constraint System** - Composable physics constraints (fixed position, grouping, anchoring)
3. **Rendering Strategy Pattern** - Type-specific renderers without type-casting
4. **Menu Component System** - Composable menu sections instead of specialized views
5. **Animation Framework** - Node lifecycle and state change animations
6. **Haptic Feedback System** - Context-aware haptic patterns

**Target Metrics:**
- New node type: 1 file change, 30 minutes
- Zero type-casting in physics/rendering code
- 80% reduction in menu view code duplication
- Animation support for all node types

---

## Phase 1: Node Type Configuration System

### 1.1 NodeTypeDescriptor Protocol

**Purpose:** Centralize all type-specific configuration in one place.

**Location:** Create `GraphEditorShared/Sources/GraphEditorShared/NodeTypeDescriptor.swift`

```swift
/// Declarative configuration for a node type's physics, rendering, and behavior
@available(iOS 16.0, watchOS 9.0, *)
public protocol NodeTypeDescriptor {
    // MARK: - Physics Configuration

    /// Physics mass (default: 1.0)
    var mass: CGFloat { get }

    /// Base radius for physics calculations (default: 20.0)
    var physicsRadius: CGFloat { get }

    /// Physics constraints applied to this node
    var constraints: [NodeConstraint] { get }

    // MARK: - Visual Configuration

    /// Visual rendering strategy
    var renderer: NodeRenderer { get }

    /// Visual size multiplier (default: 1.0)
    var visualMultiplier: CGFloat { get }

    /// Base fill color (can be state-dependent)
    var baseFillColor: Color { get }

    /// Optional icon to display
    var icon: NodeIcon? { get }

    // MARK: - Interaction Configuration

    /// Tap behavior strategy
    var tapBehavior: NodeTapBehavior { get }

    /// Whether node can collapse/expand
    var isCollapsible: Bool { get }

    /// Custom drag behavior (default: standard position update)
    var dragBehavior: NodeDragBehavior? { get }

    // MARK: - Menu Configuration

    /// Menu sections for this node type
    func menuSections(for node: NodeProtocol, context: MenuContext) -> [MenuSection]

    // MARK: - Animation Configuration

    /// Animation set for this node type
    var animations: NodeAnimationSet { get }

    /// Haptic feedback patterns
    var haptics: NodeHapticSet { get }
}

// Default implementations
public extension NodeTypeDescriptor {
    var mass: CGFloat { 1.0 }
    var physicsRadius: CGFloat { 20.0 }
    var constraints: [NodeConstraint] { [] }
    var visualMultiplier: CGFloat { 1.0 }
    var baseFillColor: Color { .blue }
    var icon: NodeIcon? { nil }
    var tapBehavior: NodeTapBehavior { .toggleExpansion }
    var isCollapsible: Bool { true }
    var dragBehavior: NodeDragBehavior? { nil }
    var animations: NodeAnimationSet { .default }
    var haptics: NodeHapticSet { .default }
}
```

### 1.2 NodeProtocol Integration

**Modify:** `GraphEditorShared/Sources/GraphEditorShared/NodeProtocol.swift`

```swift
public protocol NodeProtocol: Identifiable, Equatable, Codable {
    // Existing properties...
    var id: NodeID { get }
    var label: Int { get }
    var position: CGPoint { get set }
    var velocity: CGPoint { get set }

    // NEW: Type descriptor
    var typeDescriptor: NodeTypeDescriptor { get }

    // DEPRECATED (moved to descriptor):
    // var mass: CGFloat { get }
    // var fillColor: Color { get }
    // var displayRadius: CGFloat { get }
    // func renderView(...) -> AnyView
}

// Computed properties that delegate to descriptor
public extension NodeProtocol {
    var mass: CGFloat { typeDescriptor.mass }
    var displayRadius: CGFloat { radius * typeDescriptor.visualMultiplier }
    var fillColor: Color { typeDescriptor.baseFillColor }
}
```

### 1.3 Example Implementation: TableNode

**Modify:** `GraphEditorShared/Sources/GraphEditorShared/HomeEconomics/TableNode.swift`

```swift
public struct TableNode: NodeProtocol {
    // Existing properties...
    public let id: NodeID
    public var position: CGPoint
    // ... etc

    // NEW: Type descriptor
    public var typeDescriptor: NodeTypeDescriptor {
        TableNodeDescriptor(node: self)
    }
}

// Separate descriptor for table-specific configuration
struct TableNodeDescriptor: NodeTypeDescriptor {
    let node: TableNode

    var mass: CGFloat { 30.0 }
    var physicsRadius: CGFloat { node.radius }

    var constraints: [NodeConstraint] {
        guard !node.seatingAssignments.isEmpty else { return [] }
        return [
            FixedPositionConstraint(),
            SeatingGroupConstraint(
                tableID: node.id,
                seatedPersons: Array(node.seatingAssignments.values)
            )
        ]
    }

    var renderer: NodeRenderer {
        RectangleNodeRenderer(
            cornerRadius: 8,
            aspectRatio: node.tableLength / node.tableWidth
        )
    }

    var visualMultiplier: CGFloat {
        max(node.tableLength, node.tableWidth) / (2 * node.radius)
    }

    var baseFillColor: Color { .brown }

    var tapBehavior: NodeTapBehavior { .none }
    var isCollapsible: Bool { false }

    var dragBehavior: NodeDragBehavior? {
        guard !node.seatingAssignments.isEmpty else { return nil }
        return TableDragBehavior(
            tableID: node.id,
            seatingAssignments: node.seatingAssignments
        )
    }

    func menuSections(for node: NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let table = node as? TableNode else { return [] }
        return [
            .info([
                .text("Table: \(table.name)"),
                .text("\(table.totalSeats) seats")
            ]),
            .actions([
                .button("Edit Seating", action: { context.showSeatingSheet(table) }),
                .button("Remove Table", action: { context.deleteNode(table.id) })
            ])
        ]
    }

    var animations: NodeAnimationSet {
        .init(
            selection: .pulse(color: .brown.opacity(0.3), duration: 0.3),
            deselection: .fadeOut(duration: 0.2)
        )
    }

    var haptics: NodeHapticSet {
        .init(
            tap: .notification(.success),
            drag: .impact(.medium),
            drop: .impact(.heavy)
        )
    }
}
```

**Benefits:**
- ✅ All TableNode configuration in one place
- ✅ Fixed positioning via `FixedPositionConstraint`
- ✅ Seating group logic via `SeatingGroupConstraint`
- ✅ Custom drag behavior encapsulated
- ✅ No type-casting needed in physics/rendering code

---

## Phase 2: Constraint System

### 2.1 NodeConstraint Protocol

**Location:** Create `GraphEditorShared/Sources/GraphEditorShared/Constraints/NodeConstraint.swift`

```swift
/// Represents a physics constraint applied to a node
@available(iOS 16.0, watchOS 9.0, *)
public protocol NodeConstraint {
    /// Apply constraint and return modified position (or nil to use physics position)
    func apply(
        to node: NodeProtocol,
        proposedPosition: CGPoint,
        context: ConstraintContext
    ) -> CGPoint?

    /// IDs of nodes this constraint affects (for dependency tracking)
    func affectedNodeIDs() -> Set<NodeID>
}

/// Context provided during constraint evaluation
public struct ConstraintContext {
    public let allNodes: [NodeProtocol]
    public let deltaTime: CGFloat
    public let simulationBounds: CGSize

    /// Helper to find nodes by ID
    public func node(withID id: NodeID) -> NodeProtocol? {
        allNodes.first { $0.id == id }
    }
}
```

### 2.2 Built-in Constraints

**Location:** Create `GraphEditorShared/Sources/GraphEditorShared/Constraints/`

#### FixedPositionConstraint.swift
```swift
/// Prevents node from moving (ignores physics)
public struct FixedPositionConstraint: NodeConstraint {
    public func apply(
        to node: NodeProtocol,
        proposedPosition: CGPoint,
        context: ConstraintContext
    ) -> CGPoint? {
        // Return original position, ignoring proposed physics position
        return node.position
    }

    public func affectedNodeIDs() -> Set<NodeID> { [] }
}
```

#### RelativePositionConstraint.swift
```swift
/// Maintains position relative to another node (e.g., seated person at table)
public struct RelativePositionConstraint: NodeConstraint {
    public let anchorNodeID: NodeID
    public let offset: CGPoint

    public func apply(
        to node: NodeProtocol,
        proposedPosition: CGPoint,
        context: ConstraintContext
    ) -> CGPoint? {
        guard let anchor = context.node(withID: anchorNodeID) else {
            return nil  // Anchor not found, use physics
        }

        // Position relative to anchor
        return CGPoint(
            x: anchor.position.x + offset.x,
            y: anchor.position.y + offset.y
        )
    }

    public func affectedNodeIDs() -> Set<NodeID> {
        [anchorNodeID]
    }
}
```

#### SeatingGroupConstraint.swift
```swift
/// Manages table seating group - fixes table and seated persons
public struct SeatingGroupConstraint: NodeConstraint {
    public let tableID: NodeID
    public let seatedPersons: [NodeID]

    public func apply(
        to node: NodeProtocol,
        proposedPosition: CGPoint,
        context: ConstraintContext
    ) -> CGPoint? {
        if node.id == tableID {
            // Fix table position
            return node.position
        } else if seatedPersons.contains(node.id) {
            // Fix seated person position
            return node.position
        }
        return nil  // Not part of this group
    }

    public func affectedNodeIDs() -> Set<NodeID> {
        var ids = Set(seatedPersons)
        ids.insert(tableID)
        return ids
    }
}
```

#### SpringConstraint.swift
```swift
/// Applies spring force toward target position (soft constraint)
public struct SpringConstraint: NodeConstraint {
    public let targetPosition: CGPoint
    public let stiffness: CGFloat
    public let damping: CGFloat

    public func apply(
        to node: NodeProtocol,
        proposedPosition: CGPoint,
        context: ConstraintContext
    ) -> CGPoint? {
        // Blend physics position toward target using spring force
        let delta = CGPoint(
            x: targetPosition.x - proposedPosition.x,
            y: targetPosition.y - proposedPosition.y
        )

        let force = CGPoint(
            x: delta.x * stiffness - node.velocity.x * damping,
            y: delta.y * stiffness - node.velocity.y * damping
        )

        return CGPoint(
            x: proposedPosition.x + force.x * context.deltaTime,
            y: proposedPosition.y + force.y * context.deltaTime
        )
    }

    public func affectedNodeIDs() -> Set<NodeID> { [] }
}
```

### 2.3 Physics Engine Integration

**Modify:** `GraphEditorShared/Sources/GraphEditorShared/PhysicsEngine.swift`

```swift
public func simulationStep(
    nodes: [any NodeProtocol],
    edges: [GraphEdge],
    // REMOVE: fixedIDs: Set<NodeID>?,
    segmentConfigs: [NodeID: SegmentConfig] = [:]
) -> ([any NodeProtocol], CGFloat) {

    // NEW: Build constraint map from node descriptors
    var constraintsByNode: [NodeID: [NodeConstraint]] = [:]
    var allConstraints: [NodeConstraint] = []

    for node in nodes {
        let constraints = node.typeDescriptor.constraints
        if !constraints.isEmpty {
            constraintsByNode[node.id] = constraints
            allConstraints.append(contentsOf: constraints)
        }
    }

    // Build set of nodes affected by constraints
    let constrainedNodeIDs = Set(allConstraints.flatMap { $0.affectedNodeIDs() })

    // Apply physics forces (skip constrained nodes for force calculation)
    var forces = repulsionCalculator.calculateRepulsionForces(nodes: nodes)
    forces = attractionCalculator.applyAttractionForces(
        forces: forces,
        nodes: nodes,
        edges: edges
    )
    forces = centeringCalculator.applyCentering(
        forces: forces,
        nodes: nodes,
        layoutMode: layoutMode,
        edges: edges,
        segmentConfigs: segmentConfigs
    )

    // Zero forces for constrained nodes
    for nodeID in constrainedNodeIDs {
        forces[nodeID] = .zero
    }

    // Update positions using forces
    let (updatedNodesPreConstraint, totalVelocity) = positionUpdater.updatePositions(
        nodes: nodes,
        forces: forces,
        alpha: alpha,
        timeStep: Constants.Physics.timeStep
    )

    // NEW: Apply constraints
    let constraintContext = ConstraintContext(
        allNodes: updatedNodesPreConstraint,
        deltaTime: Constants.Physics.timeStep,
        simulationBounds: simulationBounds
    )

    let finalNodes = updatedNodesPreConstraint.map { node in
        guard let constraints = constraintsByNode[node.id], !constraints.isEmpty else {
            return node  // No constraints, use physics position
        }

        // Apply constraints in order, last one wins
        var constrainedPosition = node.position
        for constraint in constraints {
            if let newPos = constraint.apply(
                to: node,
                proposedPosition: node.position,
                context: constraintContext
            ) {
                constrainedPosition = newPos
            }
        }

        // Return node with constrained position and zero velocity
        return node.with(position: constrainedPosition, velocity: .zero)
    }

    return (finalNodes, totalVelocity)
}
```

**Remove TableNode-specific logic from:**
- ✅ `GraphSimulator.performSimulationStep` (lines 244-260) - DELETE
- ✅ `PhysicsEngine.centerNodes` (lines 343-356) - DELETE
- ✅ `CenteringCalculator.applyCentering` - Remove `is TableNode` checks

---

## Phase 3: Rendering Strategy Pattern

### 3.1 NodeRenderer Protocol

**Location:** Create `GraphEditorShared/Sources/GraphEditorShared/Rendering/NodeRenderer.swift`

```swift
/// Strategy for rendering a node's visual representation
@available(iOS 16.0, watchOS 9.0, *)
public protocol NodeRenderer {
    /// Render node shape in GraphicsContext (for canvas)
    func renderShape(
        context: inout GraphicsContext,
        node: NodeProtocol,
        screenPosition: CGPoint,
        zoomScale: CGFloat,
        isSelected: Bool
    )

    /// Render node in SwiftUI (for overlays/previews)
    func renderView(
        node: NodeProtocol,
        zoomScale: CGFloat,
        isSelected: Bool
    ) -> AnyView

    /// Visual bounds for hit testing
    func visualBounds(
        for node: NodeProtocol,
        at screenPosition: CGPoint,
        zoomScale: CGFloat
    ) -> CGRect
}
```

### 3.2 Built-in Renderers

#### CircleNodeRenderer.swift
```swift
public struct CircleNodeRenderer: NodeRenderer {
    public func renderShape(
        context: inout GraphicsContext,
        node: NodeProtocol,
        screenPosition: CGPoint,
        zoomScale: CGFloat,
        isSelected: Bool
    ) {
        let radius = node.displayRadius * zoomScale
        let circlePath = Circle()
            .path(in: CGRect(
                x: screenPosition.x - radius,
                y: screenPosition.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

        // Fill
        context.fill(circlePath, with: .color(node.fillColor))

        // Stroke
        let strokeWidth = isSelected ? 3.0 * zoomScale : 1.5 * zoomScale
        context.stroke(
            circlePath,
            with: .color(.white.opacity(0.8)),
            lineWidth: strokeWidth
        )
    }

    public func renderView(
        node: NodeProtocol,
        zoomScale: CGFloat,
        isSelected: Bool
    ) -> AnyView {
        AnyView(
            Circle()
                .fill(node.fillColor)
                .frame(
                    width: node.displayRadius * 2 * zoomScale,
                    height: node.displayRadius * 2 * zoomScale
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.8), lineWidth: isSelected ? 3 : 1.5)
                )
        )
    }

    public func visualBounds(
        for node: NodeProtocol,
        at screenPosition: CGPoint,
        zoomScale: CGFloat
    ) -> CGRect {
        let radius = node.displayRadius * zoomScale
        return CGRect(
            x: screenPosition.x - radius,
            y: screenPosition.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    }
}
```

#### RectangleNodeRenderer.swift
```swift
public struct RectangleNodeRenderer: NodeRenderer {
    public let cornerRadius: CGFloat
    public let aspectRatio: CGFloat  // width/height

    public func renderShape(
        context: inout GraphicsContext,
        node: NodeProtocol,
        screenPosition: CGPoint,
        zoomScale: CGFloat,
        isSelected: Bool
    ) {
        let baseSize = node.displayRadius * 2 * zoomScale
        let width: CGFloat
        let height: CGFloat

        if aspectRatio > 1.0 {
            // Wider than tall
            width = baseSize
            height = baseSize / aspectRatio
        } else {
            // Taller than wide
            width = baseSize * aspectRatio
            height = baseSize
        }

        let rectPath = RoundedRectangle(cornerRadius: cornerRadius * zoomScale)
            .path(in: CGRect(
                x: screenPosition.x - width / 2,
                y: screenPosition.y - height / 2,
                width: width,
                height: height
            ))

        context.fill(rectPath, with: .color(node.fillColor))

        let strokeWidth = isSelected ? 3.0 * zoomScale : 1.5 * zoomScale
        context.stroke(
            rectPath,
            with: .color(.white.opacity(0.8)),
            lineWidth: strokeWidth
        )
    }

    public func renderView(
        node: NodeProtocol,
        zoomScale: CGFloat,
        isSelected: Bool
    ) -> AnyView {
        let baseSize = node.displayRadius * 2 * zoomScale
        let width = aspectRatio > 1.0 ? baseSize : baseSize * aspectRatio
        let height = aspectRatio > 1.0 ? baseSize / aspectRatio : baseSize

        return AnyView(
            RoundedRectangle(cornerRadius: cornerRadius * zoomScale)
                .fill(node.fillColor)
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius * zoomScale)
                        .stroke(.white.opacity(0.8), lineWidth: isSelected ? 3 : 1.5)
                )
        )
    }

    public func visualBounds(
        for node: NodeProtocol,
        at screenPosition: CGPoint,
        zoomScale: CGFloat
    ) -> CGRect {
        let baseSize = node.displayRadius * 2 * zoomScale
        let width = aspectRatio > 1.0 ? baseSize : baseSize * aspectRatio
        let height = aspectRatio > 1.0 ? baseSize / aspectRatio : baseSize

        return CGRect(
            x: screenPosition.x - width / 2,
            y: screenPosition.y - height / 2,
            width: width,
            height: height
        )
    }
}
```

### 3.3 Rendering Integration

**Modify:** `GraphEditorWatch/Views/AccessibleCanvasRenderer.swift`

**BEFORE (type-casting mess):**
```swift
private static func drawNodeShape(...) {
    if let table = node as? TableNode {
        // Draw rectangle
    } else {
        // Draw circle
    }
}
```

**AFTER (strategy pattern):**
```swift
private static func drawNodeShape(
    renderContext: RenderContext,
    graphicsContext: inout GraphicsContext,
    node: any NodeProtocol,
    isSelected: Bool
) {
    // Delegate to node's renderer
    let screenPos = modelToScreen(node.position, renderContext: renderContext)
    node.typeDescriptor.renderer.renderShape(
        context: &graphicsContext,
        node: node,
        screenPosition: screenPos,
        zoomScale: renderContext.zoomScale,
        isSelected: isSelected
    )
}
```

**Modify:** `GraphEditorWatch/Views/NodeView.swift`

**BEFORE (7-branch if-else):**
```swift
var body: some View {
    if let taskNode = node as? TaskNode {
        // TaskNode rendering
    } else if let mealNode = node as? MealNode {
        // MealNode rendering
    } else if ...
}
```

**AFTER (one line):**
```swift
var body: some View {
    node.typeDescriptor.renderer.renderView(
        node: node,
        zoomScale: zoomScale,
        isSelected: isSelected
    )
}
```

---

## Phase 4: Menu Component System

### 4.1 MenuSection & MenuAction

**Location:** Create `GraphEditorShared/Sources/GraphEditorShared/Menu/MenuComponents.swift`

```swift
/// Represents a section in a node's context menu
public struct MenuSection {
    public let title: String?
    public let items: [MenuItem]

    public static func info(_ items: [MenuItem]) -> MenuSection {
        MenuSection(title: nil, items: items)
    }

    public static func actions(_ items: [MenuItem]) -> MenuSection {
        MenuSection(title: "Actions", items: items)
    }

    public static func properties(_ items: [MenuItem]) -> MenuSection {
        MenuSection(title: "Properties", items: items)
    }
}

/// Individual menu item
public enum MenuItem {
    case text(String)
    case label(String, String)  // key, value
    case button(String, action: () -> Void)
    case toggle(String, binding: Binding<Bool>)
    case picker(String, selection: Binding<String>, options: [String])
    case navigation(String, destination: AnyView)
    case divider
}

/// Context provided to menu builders
public struct MenuContext {
    public let model: GraphModel
    public let viewModel: GraphViewModel
    public let dismiss: () -> Void

    public func deleteNode(_ id: NodeID) {
        Task {
            await model.deleteNode(id: id)
            dismiss()
        }
    }

    public func showSheet(_ view: AnyView) {
        // Present sheet
    }
}
```

### 4.2 MenuView Refactor

**Modify:** `GraphEditorWatch/Views/MenuView.swift`

**BEFORE (type routing):**
```swift
if node.unwrapped is TaskNode {
    TaskNodeMenuView(...)
} else if node.unwrapped is MealNode {
    MealNodeMenuView(...)
} else if ...
```

**AFTER (unified):**
```swift
ScrollView {
    VStack(spacing: 16) {
        let context = MenuContext(
            model: viewModel.model,
            viewModel: viewModel,
            dismiss: { presentationMode.wrappedValue.dismiss() }
        )

        ForEach(node.typeDescriptor.menuSections(for: node, context: context), id: \.title) { section in
            MenuSectionView(section: section)
        }
    }
}
```

**Create:** `GraphEditorWatch/Views/MenuSectionView.swift`

```swift
struct MenuSectionView: View {
    let section: MenuSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = section.title {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(section.items.indices, id: \.self) { index in
                MenuItemView(item: section.items[index])
            }
        }
    }
}

struct MenuItemView: View {
    let item: MenuItem

    var body: some View {
        switch item {
        case .text(let value):
            Text(value)
                .font(.body)

        case .label(let key, let value):
            HStack {
                Text(key)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
            }

        case .button(let title, let action):
            Button(action: action) {
                Text(title)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

        case .toggle(let title, let binding):
            Toggle(title, isOn: binding)

        case .picker(let title, let selection, let options):
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }

        case .navigation(let title, let destination):
            NavigationLink(title, destination: destination)

        case .divider:
            Divider()
        }
    }
}
```

**Result:** Delete 6 specialized menu views (TaskNodeMenuView, MealNodeMenuView, etc.) - **~50KB code reduction**

---

## Phase 5: Animation Framework

### 5.1 NodeAnimationSet

**Location:** Create `GraphEditorShared/Sources/GraphEditorShared/Animation/NodeAnimation.swift`

```swift
/// Animation configuration for a node type
public struct NodeAnimationSet {
    public let selection: NodeAnimation?
    public let deselection: NodeAnimation?
    public let stateChange: NodeAnimation?
    public let appear: NodeAnimation?
    public let disappear: NodeAnimation?

    public static let `default` = NodeAnimationSet(
        selection: .pulse(color: .blue.opacity(0.3), duration: 0.3),
        deselection: .fadeOut(duration: 0.2),
        stateChange: .crossfade(duration: 0.25),
        appear: .scaleIn(duration: 0.3),
        disappear: .scaleOut(duration: 0.2)
    )
}

/// Individual animation definition
public enum NodeAnimation {
    case pulse(color: Color, duration: TimeInterval)
    case fadeOut(duration: TimeInterval)
    case fadeIn(duration: TimeInterval)
    case scaleIn(duration: TimeInterval)
    case scaleOut(duration: TimeInterval)
    case crossfade(duration: TimeInterval)
    case bounce(amplitude: CGFloat, duration: TimeInterval)
    case rotate(degrees: Double, duration: TimeInterval)
    case shake(intensity: CGFloat, duration: TimeInterval)
    case custom((NodeProtocol, CGFloat) -> ViewModifier)  // progress: 0-1
}
```

### 5.2 AnimatedNodeView Wrapper

**Location:** Create `GraphEditorWatch/Views/AnimatedNodeView.swift`

```swift
struct AnimatedNodeView: View {
    let node: NodeProtocol
    let zoomScale: CGFloat
    let isSelected: Bool
    let animationState: NodeAnimationState

    var body: some View {
        node.typeDescriptor.renderer.renderView(
            node: node,
            zoomScale: zoomScale,
            isSelected: isSelected
        )
        .modifier(animationModifier)
    }

    @ViewBuilder
    private var animationModifier: some ViewModifier {
        switch animationState {
        case .idle:
            EmptyModifier()

        case .selecting(let progress):
            if let animation = node.typeDescriptor.animations.selection {
                AnimationModifierView(animation: animation, progress: progress)
            }

        case .deselecting(let progress):
            if let animation = node.typeDescriptor.animations.deselection {
                AnimationModifierView(animation: animation, progress: progress)
            }

        case .stateChanging(let progress):
            if let animation = node.typeDescriptor.animations.stateChange {
                AnimationModifierView(animation: animation, progress: progress)
            }
        }
    }
}

enum NodeAnimationState {
    case idle
    case selecting(progress: CGFloat)
    case deselecting(progress: CGFloat)
    case stateChanging(progress: CGFloat)
}
```

### 5.3 Animation Triggers

**Modify:** `GraphEditorWatch/ViewModels/GraphViewModel.swift`

```swift
// Track animation states
@Published var nodeAnimationStates: [NodeID: NodeAnimationState] = [:]

func selectNode(_ id: NodeID) {
    // Trigger selection animation
    nodeAnimationStates[id] = .selecting(progress: 0)

    withAnimation(.easeInOut(duration: 0.3)) {
        selectedNodeID = id

        // Animate progress
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            nodeAnimationStates[id] = .idle
        }
    }
}
```

---

## Phase 6: Haptic Feedback System

### 6.1 NodeHapticSet

**Location:** Create `GraphEditorShared/Sources/GraphEditorShared/Haptics/NodeHaptics.swift`

```swift
/// Haptic feedback configuration for a node type
public struct NodeHapticSet {
    public let tap: HapticPattern?
    public let longPress: HapticPattern?
    public let drag: HapticPattern?
    public let drop: HapticPattern?
    public let stateChange: HapticPattern?

    public static let `default` = NodeHapticSet(
        tap: .impact(.light),
        longPress: .impact(.medium),
        drag: .selection,
        drop: .impact(.heavy),
        stateChange: .notification(.success)
    )

    public static let none = NodeHapticSet(
        tap: nil,
        longPress: nil,
        drag: nil,
        drop: nil,
        stateChange: nil
    )
}

/// Haptic pattern definition
public enum HapticPattern {
    case impact(UIImpactFeedbackGenerator.FeedbackStyle)
    case notification(UINotificationFeedbackGenerator.FeedbackType)
    case selection
    case custom([CHHapticEvent])  // Core Haptics for complex patterns
}
```

### 6.2 HapticManager

**Location:** Create `GraphEditorWatch/Models/HapticManager.swift`

```swift
@MainActor
class HapticManager {
    static let shared = HapticManager()

    func play(_ pattern: HapticPattern?) {
        guard let pattern else { return }

        #if os(watchOS)
        switch pattern {
        case .impact(let style):
            WKInterfaceDevice.current().play(.click)  // watchOS simplified

        case .notification(let type):
            WKInterfaceDevice.current().play(type == .success ? .success : .failure)

        case .selection:
            WKInterfaceDevice.current().play(.directionUp)

        case .custom:
            // Core Haptics on watchOS
            break
        }
        #endif
    }

    func playForNode(_ node: NodeProtocol, event: HapticEvent) {
        let pattern: HapticPattern?
        switch event {
        case .tap: pattern = node.typeDescriptor.haptics.tap
        case .longPress: pattern = node.typeDescriptor.haptics.longPress
        case .drag: pattern = node.typeDescriptor.haptics.drag
        case .drop: pattern = node.typeDescriptor.haptics.drop
        case .stateChange: pattern = node.typeDescriptor.haptics.stateChange
        }
        play(pattern)
    }
}

enum HapticEvent {
    case tap, longPress, drag, drop, stateChange
}
```

### 6.3 Haptic Integration

**Modify:** `GraphEditorWatch/Views/GraphGesturesModifier.swift`

```swift
private func handleTapGesture(at location: CGPoint) async {
    guard let tappedNode = await viewModel.hitTest(at: location) else { return }

    // Play tap haptic
    HapticManager.shared.playForNode(tappedNode, event: .tap)

    // Execute tap behavior
    await viewModel.selectNode(tappedNode.id)
}

private func handleDragChanged(_ value: DragGesture.Value) {
    guard let dragged = draggedNode else { return }

    // Play drag haptic (only once at start)
    if !hasDragHapticPlayed {
        HapticManager.shared.playForNode(dragged, event: .drag)
        hasDragHapticPlayed = true
    }

    // Update position
    dragOffset = value.translation
}

private func handleDragEnded(_ value: DragGesture.Value) async {
    guard let dragged = draggedNode else { return }

    // Play drop haptic
    HapticManager.shared.playForNode(dragged, event: .drop)

    // Finalize position
    await viewModel.finalizeNodeDrag(dragged.id, offset: dragOffset)
}
```

---

## Phase 7: Migration Strategy

### 7.1 Migration Order (Minimize Breakage)

**Week 1: Foundation**
1. ✅ Create `NodeTypeDescriptor` protocol
2. ✅ Create `NodeConstraint` protocol + built-in constraints
3. ✅ Create `NodeRenderer` protocol + CircleNodeRenderer, RectangleNodeRenderer
4. ✅ Create `MenuSection` / `MenuItem` types
5. ✅ Add `typeDescriptor` property to NodeProtocol with default implementation

**Week 2: Physics Refactor**
6. ✅ Migrate PhysicsEngine to use constraints instead of fixedIDs
7. ✅ Remove TableNode-specific checks from PhysicsEngine.centerNodes
8. ✅ Remove TableNode-specific checks from GraphSimulator
9. ✅ Remove TableNode-specific checks from CenteringCalculator
10. ✅ Test physics with TableNode using constraints

**Week 3: Rendering Refactor**
11. ✅ Refactor AccessibleCanvasRenderer to use node.typeDescriptor.renderer
12. ✅ Refactor NodeView to use node.typeDescriptor.renderer
13. ✅ Remove all `as? TableNode`, `as? TaskNode` type casts from rendering code
14. ✅ Test rendering for all node types

**Week 4: Menu Refactor**
15. ✅ Create MenuSectionView / MenuItemView components
16. ✅ Migrate one node type (e.g., TaskNode) to use menuSections()
17. ✅ Refactor MenuView to use unified menu rendering
18. ✅ Migrate remaining node types
19. ✅ Delete specialized menu views
20. ✅ Test menu functionality

**Week 5: Animation & Haptics**
21. ✅ Create NodeAnimationSet / NodeAnimation types
22. ✅ Create NodeHapticSet / HapticManager
23. ✅ Add animation support to AnimatedNodeView
24. ✅ Add haptic triggers to gesture handlers
25. ✅ Implement custom animations for each node type
26. ✅ Test animations and haptics

**Week 6: Migration to Descriptors**
27. ✅ Migrate TableNode to TableNodeDescriptor (reference implementation)
28. ✅ Migrate remaining node types to descriptors
29. ✅ Remove deprecated properties from NodeProtocol
30. ✅ Full regression testing

### 7.2 Backwards Compatibility

During migration, support both old and new patterns:

```swift
public extension NodeProtocol {
    // Default descriptor delegates to protocol properties (backwards compat)
    var typeDescriptor: NodeTypeDescriptor {
        DefaultNodeDescriptor(node: self)
    }
}

struct DefaultNodeDescriptor: NodeTypeDescriptor {
    let node: NodeProtocol

    var mass: CGFloat { node.mass }  // Delegates to old property
    var baseFillColor: Color { node.fillColor }
    var renderer: NodeRenderer {
        CircleNodeRenderer()  // Default circle
    }
    // ... etc
}
```

Once all node types have custom descriptors, remove fallback properties.

---

## Phase 8: Success Metrics

### 8.1 Code Reduction

**Target Deletions:**
- ❌ TaskNodeMenuView.swift (~6KB)
- ❌ MealNodeMenuView.swift (~14KB)
- ❌ DecisionNodeMenuView.swift (~15KB)
- ❌ PreferenceNodeMenuView.swift (~6KB)
- ❌ PersonNodeMenuView.swift (~9KB)
- ❌ TableNodeMenuView.swift (~14KB)
- ❌ 50+ type-cast locations across codebase

**Total Reduction:** ~64KB + scattered type-checking logic

### 8.2 Ease of Adding New Node Types

**Before Refactor:**
- Files to modify: 4-9
- Type-casting locations: 7+
- Time: 2-8 hours

**After Refactor:**
- Files to create: 1 (NodeTypeDescriptor implementation)
- Type-casting locations: 0
- Time: 30 minutes

### 8.3 New Capabilities Unlocked

✅ **Rich Animations:**
- Selection pulse
- State change transitions
- Physics settling indicators
- Drag feedback

✅ **Context-Aware Haptics:**
- Per-node-type feedback
- Custom haptic patterns
- Event-specific responses

✅ **Flexible Constraints:**
- Fixed positioning
- Relative positioning
- Grouping (seating)
- Spring constraints
- Custom constraints

✅ **Composable Menus:**
- Shared menu sections
- Type-specific sections
- Reduced duplication

---

## Phase 9: Future Extensions

### 9.1 Advanced Node Types

**AnchorNode** (fixed position, can't move):
```swift
struct AnchorNodeDescriptor: NodeTypeDescriptor {
    var constraints: [NodeConstraint] {
        [FixedPositionConstraint()]
    }
    var renderer: NodeRenderer {
        CircleNodeRenderer()
    }
    var icon: NodeIcon? { .anchor }
    var tapBehavior: NodeTapBehavior { .none }
}
```

**GroupNode** (contains child nodes):
```swift
struct GroupNodeDescriptor: NodeTypeDescriptor {
    let childIDs: [NodeID]

    var constraints: [NodeConstraint] {
        childIDs.map { childID in
            RelativePositionConstraint(
                anchorNodeID: childID,
                offset: .zero  // Computed based on layout
            )
        }
    }
}
```

**AnimatedIconNode** (animated icon):
```swift
struct AnimatedIconNodeDescriptor: NodeTypeDescriptor {
    var animations: NodeAnimationSet {
        .init(
            selection: .rotate(degrees: 360, duration: 0.5),
            stateChange: .bounce(amplitude: 10, duration: 0.4)
        )
    }
}
```

### 9.2 Physics Enhancements

**MagneticConstraint** (attract/repel nodes):
```swift
struct MagneticConstraint: NodeConstraint {
    let targetNodeID: NodeID
    let strength: CGFloat  // Positive = attract, negative = repel

    func apply(to node: NodeProtocol, proposedPosition: CGPoint, context: ConstraintContext) -> CGPoint? {
        guard let target = context.node(withID: targetNodeID) else { return nil }

        let delta = CGPoint(
            x: target.position.x - proposedPosition.x,
            y: target.position.y - proposedPosition.y
        )
        let distance = hypot(delta.x, delta.y)

        let force = strength / (distance * distance)

        return CGPoint(
            x: proposedPosition.x + delta.x * force,
            y: proposedPosition.y + delta.y * force
        )
    }
}
```

**OrbitConstraint** (circular orbit around anchor):
```swift
struct OrbitConstraint: NodeConstraint {
    let anchorNodeID: NodeID
    let radius: CGFloat
    let angularVelocity: CGFloat  // radians per second
    var currentAngle: CGFloat

    mutating func apply(to node: NodeProtocol, proposedPosition: CGPoint, context: ConstraintContext) -> CGPoint? {
        guard let anchor = context.node(withID: anchorNodeID) else { return nil }

        // Update angle
        currentAngle += angularVelocity * context.deltaTime

        // Position on orbit
        return CGPoint(
            x: anchor.position.x + radius * cos(currentAngle),
            y: anchor.position.y + radius * sin(currentAngle)
        )
    }
}
```

### 9.3 Advanced Rendering

**GlowRenderer** (animated glow effect):
```swift
struct GlowNodeRenderer: NodeRenderer {
    let baseRenderer: NodeRenderer
    let glowColor: Color
    let glowRadius: CGFloat
    let pulseSpeed: TimeInterval

    func renderShape(context: inout GraphicsContext, node: NodeProtocol, screenPosition: CGPoint, zoomScale: CGFloat, isSelected: Bool) {
        // Render glow
        let glowIntensity = sin(Date().timeIntervalSince1970 / pulseSpeed) * 0.5 + 0.5
        context.addFilter(.blur(radius: glowRadius * zoomScale * glowIntensity))
        context.fill(/* glow shape */, with: .color(glowColor.opacity(glowIntensity)))

        // Render base
        baseRenderer.renderShape(context: &context, node: node, screenPosition: screenPosition, zoomScale: zoomScale, isSelected: isSelected)
    }
}
```

**ImageNodeRenderer** (custom image):
```swift
struct ImageNodeRenderer: NodeRenderer {
    let imageName: String

    func renderShape(context: inout GraphicsContext, node: NodeProtocol, screenPosition: CGPoint, zoomScale: CGFloat, isSelected: Bool) {
        if let image = Image(imageName) {
            context.draw(
                image,
                at: screenPosition,
                anchor: .center
            )
        }
    }
}
```

---

## Conclusion

This refactor transforms the node type system from:

**❌ Ad-hoc type-checking scattered across 10+ files**

To:

**✅ Declarative, composable, type-safe configuration system**

### Key Benefits

1. **Extensibility:** Add new node types in 30 minutes, not 2-8 hours
2. **Maintainability:** All type-specific logic in one place (descriptor)
3. **Testability:** Each component (constraint, renderer, menu) testable in isolation
4. **Performance:** No runtime type-casting overhead
5. **Rich Features:** Animation, haptics, constraints built-in

### Next Steps

1. Review this plan with team
2. Prioritize phases (can implement incrementally)
3. Create feature branch: `refactor/node-type-system`
4. Begin Phase 1: Foundation (Week 1)
5. Track progress against success metrics

**Estimated Total Effort:** 6 weeks (1 developer)

**Estimated Code Reduction:** ~70KB + improved architecture

**Estimated Time Savings:** 90% faster to add new node types (8 hours → 30 minutes)
