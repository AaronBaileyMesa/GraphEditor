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
                            try await viewModel.model.createNewGraph(name: newGraphName)
                            viewModel.currentGraphName = newGraphName
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
        Button {
            WKInterfaceDevice.current().play(.click)
            newGraphName = ""
            showNewSheet = true
        } label: {
            Label("New", systemImage: "doc.badge.plus")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("newGraphButton")
    }
    
    private var saveGraphButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            viewModel.currentGraphName = graphName
            Task {
                do {
                    try await viewModel.model.saveGraph()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            onDismiss()
        } label: {
            Label("Save", systemImage: "square.and.arrow.down")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("saveButton")
    }
    
    private var loadGraphButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            Task {
                await viewModel.model.loadGraph(name: graphName)
                viewModel.currentGraphName = graphName
            }
            onDismiss()
        } label: {
            Label("Load", systemImage: "folder")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("loadButton")
    }
    
    private var listGraphsButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            Task {
                do {
                    graphs = try await viewModel.model.listGraphNames()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            Label("List", systemImage: "list.bullet")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("listGraphsButton")
    }
    
    // Added missing definitions below (copied from GraphSection.swift)
    private func graphItemButton(name: String) -> some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            Task {
                await viewModel.model.loadGraph(name: name)
                viewModel.currentGraphName = name
                graphName = name
            }
            onDismiss()
        } label: {
            Label(name, systemImage: "doc")
                .labelStyle(.titleAndIcon)
                .font(.caption2)  // Smaller for long names
        }
        .accessibilityHint("Load graph \(name)")
    }
    
    private var deleteGraphButton: some View {
        Button(role: .destructive) {
            WKInterfaceDevice.current().play(.click)
            Task {
                do {
                    try await viewModel.model.deleteGraph(name: graphName)
                    graphName = "default"
                    await viewModel.model.loadGraph(name: "default")
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            onDismiss()
        } label: {
            Label("Del", systemImage: "trash")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("deleteGraphButton")
    }
}
