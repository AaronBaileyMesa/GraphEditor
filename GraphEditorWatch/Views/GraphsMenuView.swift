//
//  GraphsMenuView.swift
//  GraphEditor
//
//  Created by handcart on 10/23/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared

struct GraphsMenuView: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void
    
    @State private var graphName: String = ""
    @State private var showNewSheet: Bool = false
    @State private var newGraphName: String = ""
    @State private var graphs: [String] = []
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {  // Scrollable for long lists
            VStack(spacing: 8) {
                Text("Graphs").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading)
                
                // Current graph name editing (from GraphSection)
                TextField("Current Name", text: $graphName)
                    .font(.caption)
                    .accessibilityIdentifier("graphNameTextField")
                
                // Buttons for save/load/delete current graph
                HStack(spacing: 8) {
                    saveGraphButton
                    loadGraphButton
                    deleteGraphButton
                }
                
                // New graph button
                newGraphButton
                
                // List graphs button and dynamic list
                listGraphsButton
                ForEach(graphs, id: \.self) { name in
                    graphItemButton(name: name)
                }
                
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).font(.caption2)
                }
            }
            .padding(4)
        }
        .navigationTitle("Manage Graphs")  // Clear title
        .sheet(isPresented: $showNewSheet) {
            // Same as GraphSection's new graph sheet
            VStack(spacing: 4) {
                TextField("New Name", text: $newGraphName).font(.caption)
                Button("Create") {
                    WKInterfaceDevice.current().play(.click)
                    Task {
                        do {
                            let available = try await viewModel.model.listGraphNames()
                            if available.contains(newGraphName) {
                                errorMessage = "Graph '\(newGraphName)' already exists."
                                return
                            }
                            try await viewModel.model.createNewGraph(name: newGraphName)
                            try await viewModel.model.switchToGraph(named: newGraphName)
                            showNewSheet = false
                            onDismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
        .onAppear {
            graphName = viewModel.currentGraphName
            // Optionally auto-list graphs here: Task { graphs = try await viewModel.model.listGraphNames() }
        }
    }
    
    private var newGraphButton: some View {
        MenuButton(
            action: {
                newGraphName = ""
                showNewSheet = true
            },
            label: {
                Label("New", systemImage: "doc.badge.plus")
            },
            accessibilityIdentifier: "newGraphButton"
        )
    }
    
    private var saveGraphButton: some View {
        MenuButton(
            action: {
                viewModel.currentGraphName = graphName
                Task {
                    do {
                        try await viewModel.model.saveGraph()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                onDismiss()
            },
            label: {
                Label("Save", systemImage: "square.and.arrow.down")
            },
            accessibilityIdentifier: "saveButton"
        )
    }
    
    private var loadGraphButton: some View {
        MenuButton(
            action: {
                Task {
                    do {
                        let availableGraphs = try await viewModel.model.listGraphNames()
                        guard availableGraphs.contains(graphName) else {
                            errorMessage = "Graph '\(graphName)' does not exist."
                            return
                        }
                        try await viewModel.model.switchToGraph(named: graphName)
                        viewModel.currentGraphName = graphName
                        onDismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            },
            label: {
                Label("Load", systemImage: "folder")
            },
            accessibilityIdentifier: "loadButton"
        )
    }
    
    private var listGraphsButton: some View {
        MenuButton(
            action: {
                Task {
                    do {
                        graphs = try await viewModel.model.listGraphNames()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            },
            label: {
                Label("List", systemImage: "list.bullet")
            },
            accessibilityIdentifier: "listGraphsButton"
        )
    }
    
    // Added missing definitions below (copied from GraphSection.swift)
    private func graphItemButton(name: String) -> some View {
        MenuButton(
            action: {
                Task {
                    do {
                        try await viewModel.model.switchToGraph(named: name)
                        viewModel.currentGraphName = name
                        graphName = name
                        onDismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            },
            label: {
                Label(name, systemImage: "doc")
            }
        )
        .font(.caption2)  // Smaller for long names
        .accessibilityHint("Load graph \(name)")
    }
    
    private var deleteGraphButton: some View {
        MenuButton(
            action: {
                Task {
                    do {
                        try await viewModel.model.deleteGraph(named: graphName)
                        graphName = "default"
                        try await viewModel.model.switchToGraph(named: "default")
                        onDismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            },
            label: {
                Label("Del", systemImage: "trash")
            },
            accessibilityIdentifier: "deleteGraphButton",
            role: .destructive
        )
    }
}
