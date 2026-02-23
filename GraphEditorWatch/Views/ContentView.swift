//
//  ContentView.swift
//  GraphEditorWatch
//

import SwiftUI
import WatchKit
import GraphEditorShared
import Contacts
import os

struct ContentView: View {
    private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "contentview")
    
    @ObservedObject var viewModel: GraphViewModel
    
    // Local gesture/UI state only
    @State private var draggedNode: (any NodeProtocol)? 
    @State private var dragOffset: CGPoint = .zero
    @State private var currentDragLocation: CGPoint? // Live finger position during drag
    @State private var dragStartNode: (any NodeProtocol)?  // Starting node for edge preview
    @State private var potentialEdgeTarget: (any NodeProtocol)?
    @State private var selectedNodeID: NodeID?
    @State private var selectedEdgeID: UUID?
    @State private var panStartOffset: CGSize?
    @State private var showMenu: Bool = false
    @State private var showOverlays: Bool = false
    @FocusState private var canvasFocus: Bool
    @State private var wristSide: WKInterfaceDeviceWristLocation = .left
    @State private var showEditSheet: Bool = false
    @State private var viewSize: CGSize = .zero
    @State private var isSimulating: Bool = false
    @State private var saturation: Double = 1.0
    
    private var minZoom: CGFloat { AppConstants.defaultMinZoom }
    private var maxZoom: CGFloat { AppConstants.defaultMaxZoom }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                GraphCanvasView(
                    viewModel: viewModel,
                    draggedNode: Binding(get: { draggedNode }, set: { draggedNode = $0 }),
                    dragOffset: $dragOffset,
                    potentialEdgeTarget: Binding(get: { potentialEdgeTarget }, set: { potentialEdgeTarget = $0 }),
                    selectedNodeID: Binding(
                        get: { selectedNodeID },
                        set: { newValue in
                            selectedNodeID = newValue
                            viewModel.selectedNodeID = newValue
                        }
                    ),
                    selectedEdgeID: Binding(
                        get: { selectedEdgeID },
                        set: { newValue in
                            selectedEdgeID = newValue
                            viewModel.selectedEdgeID = newValue
                        }
                    ),
                    viewSize: $viewSize,
                    panStartOffset: $panStartOffset,
                    showMenu: $showMenu,
                    onUpdateZoomRanges: { _, _ in },
                    isAddingEdge: $viewModel.isAddingEdge,
                    isSimulating: $isSimulating,
                    saturation: $saturation,
                    currentDragLocation: $currentDragLocation,
                        dragStartNode: $dragStartNode
                )
                .debugViewHierarchy()

            }
            
            .onAppear {
                viewSize = geo.size
                viewModel.viewSize = geo.size  // Sync to ViewModel
                wristSide = WKInterfaceDevice.current().wristLocation
                canvasFocus = true
                Task { await viewModel.resumeSimulation() }
                viewModel.resetViewToFitGraph(viewSize: geo.size)
                print("ContentView appeared – confirming render")
            }
            .focused($canvasFocus)
            .onChange(of: viewModel.model.editingNodeID) { _, newValue in
                // Release canvas focus when sheet appears
                canvasFocus = (newValue == nil)
            }
            .sheet(item: $viewModel.model.editingNodeID) { id in
                EditContentSheet(
                    selectedID: id,
                    viewModel: viewModel,
                    onSave: { newContents in
                        Task {
                            await viewModel.model.updateNodeContents(withID: id, newContents: newContents)
                            viewModel.model.editingNodeID = nil  // Dismiss sheet
                        }
                    }
                )
                .environment(\.disableCanvasFocus, true)  // As in your existing code
            }
        }
            .ignoresSafeArea(edges: [.leading, .trailing, .top, .bottom])
            .onChange(of: viewSize) { _, newSize in
                viewModel.viewSize = newSize  // Sync to ViewModel
                viewModel.resetViewToFitGraph(viewSize: newSize)
            }
            .onChange(of: viewModel.selectedNodeID) { _, newID in
                // Sync ContentView's local state when viewModel changes programmatically
                selectedNodeID = newID
            }
          
            // Menu sheet
            .sheet(isPresented: $showMenu) {
                NavigationStack {
                    MenuView(
                        viewModel: viewModel,
                        isSimulatingBinding: $isSimulating,
                        onCenterGraph: centerGraph,
                        showMenu: $showMenu,
                        showOverlays: $showOverlays,
                        selectedNodeID: Binding(
                            get: { selectedNodeID },
                            set: { selectedNodeID = $0; viewModel.selectedNodeID = $0 }
                        ),
                        selectedEdgeID: Binding(
                            get: { selectedEdgeID },
                            set: { selectedEdgeID = $0; viewModel.selectedEdgeID = $0 }
                        )
                    )
                    .navigationBarTitleDisplayMode(.inline)
                }
                .onDisappear {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        saturation = 1.0
                    }
                }
            }
            .navigationDestination(isPresented: $viewModel.showDashboard) {
                DashboardView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showContactPicker) {
                if let nodeID = viewModel.contactPickerForNodeID {
                    ContactPickerView { contact in
                        linkContactToNode(contact: contact, nodeID: nodeID)
                    }
                }
            }

        }
    }

    private func linkContactToNode(contact: CNContact, nodeID: NodeID) {
        guard let personNode = viewModel.model.nodes.first(where: { $0.id == nodeID })?.unwrapped as? PersonNode,
              let nodeIndex = viewModel.model.nodes.firstIndex(where: { $0.id == nodeID }) else {
            return
        }

        // Extract contact data
        let identifier = contact.identifier
        let contactName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        
        var thumbnailData: Data?
        if contact.imageDataAvailable, let imageData = contact.thumbnailImageData {
            // Use the contact's photo
            thumbnailData = imageData
        } else {
            // Generate a monogram if no photo is available
            thumbnailData = MonogramGenerator.generateMonogram(from: contactName)
        }

        // Create updated PersonNode with contact info
        let updatedPerson = PersonNode(
            id: personNode.id,
            label: personNode.label,
            position: personNode.position,
            velocity: personNode.velocity,
            radius: personNode.radius,
            name: contactName,
            defaultSpiceLevel: personNode.defaultSpiceLevel,
            dietaryRestrictions: personNode.dietaryRestrictions,
            contactIdentifier: identifier,
            thumbnailImageData: thumbnailData,
            proteinPreference: personNode.proteinPreference,
            shellPreference: personNode.shellPreference,
            toppingPreferences: personNode.toppingPreferences
        )

        // Update in model
        viewModel.model.nodes[nodeIndex] = AnyNode(updatedPerson)
        viewModel.model.objectWillChange.send()
        viewModel.model.pushUndo()

        // Close the picker
        viewModel.showContactPicker = false
        viewModel.contactPickerForNodeID = nil
        
        // Regenerate controls to reflect the updated state (linkContact should now be hidden)
        Task {
            await viewModel.generateControls(for: nodeID)
        }
    }
        
    private func centerGraph() {
        guard viewSize.width > 0 else { return }
        
        let oldCentroid = viewModel.effectiveCentroid
        viewModel.resetViewToFitGraph(viewSize: viewSize)
        let newCentroid = viewModel.effectiveCentroid
        
        let centroidShift = CGSize(
            width: (oldCentroid.x - newCentroid.x) * viewModel.zoomScale,
            height: (oldCentroid.y - newCentroid.y) * viewModel.zoomScale
        )
        
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.offset = CGSize(
                width: viewModel.offset.width  + centroidShift.width,
                height: viewModel.offset.height + centroidShift.height
            )
        }
        
        #if DEBUG
        logger.debug("Centering graph – oldCentroid: (\(oldCentroid.x), \(oldCentroid.y)), newCentroid: (\(newCentroid.x), \(newCentroid.y)), shift: (\(centroidShift.width), \(centroidShift.height))")
        #endif
    }
}

// Keep the clamped helper (used elsewhere too)
extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
