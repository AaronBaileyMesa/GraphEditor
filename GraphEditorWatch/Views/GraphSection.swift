//
//  GraphSection.swift
//  GraphEditorWatch
//
//  Created by handcart on 10/5/25.
//

import SwiftUI
import WatchKit

struct GraphSection: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void
    
    @State private var graphName: String = ""
    @State private var showNewSheet: Bool = false
    @State private var newGraphName: String = ""
    @State private var graphs: [String] = []
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            graphNameField
            if viewModel.canRedo || viewModel.canUndo {
                undoButton
                redoButton
            }
            newGraphButton
            saveGraphButton
            loadGraphButton
            listGraphsButton
            ForEach(graphs, id: \.self) { name in
                graphItemButton(name: name)
            }
            resetGraphButton
            deleteGraphButton
            if let error = errorMessage {
                Text(error).foregroundColor(.red).font(.caption2).gridCellColumns(2)
            }
        }
        .sheet(isPresented: $showNewSheet) {
            VStack(spacing: 4) {
                TextField("New Name", text: $newGraphName)
                    .font(.caption)
                    .accessibilityIdentifier("newGraphNameTextField")
                Button {
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
                } label: {
                    Label("Create", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                }
                .accessibilityIdentifier("createButton")
            }
        }
        .onAppear { graphName = viewModel.currentGraphName }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Graph section")
    }
    
    private var graphNameField: some View {
        TextField("Name", text: $graphName)
            .font(.caption)
            .accessibilityIdentifier("graphNameTextField")
            .gridCellColumns(2)
    }
    
    private var undoButton: some View {
        if viewModel.canUndo {
            return AnyView(Button {
                WKInterfaceDevice.current().play(.click)
                Task { await viewModel.undo() }
                onDismiss()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.left")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
            }
            .accessibilityIdentifier("undoButton"))
        } else {
            return AnyView(EmptyView())
        }
    }
    
    private var redoButton: some View {
        if viewModel.canRedo {
            return AnyView(Button {
                WKInterfaceDevice.current().play(.click)
                Task { await viewModel.redo() }
                onDismiss()
            } label: {
                Label("Redo", systemImage: "arrow.uturn.right")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
            }
            .accessibilityIdentifier("redoButton"))
        } else {
            return AnyView(EmptyView())
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
                do {
                    try await viewModel.model.loadGraph(name: graphName)
                    viewModel.currentGraphName = graphName
                } catch {
                    errorMessage = error.localizedDescription
                }
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
    
    private func graphItemButton(name: String) -> some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            Task {
                do {
                    try await viewModel.model.loadGraph(name: name)
                    viewModel.currentGraphName = name
                    graphName = name
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            onDismiss()
        } label: {
            Label(name, systemImage: "doc")
                .labelStyle(.titleAndIcon)
                .font(.caption2)  // Smaller for long names
        }
        .accessibilityHint("Load graph \(name)")
    }
    
    private var resetGraphButton: some View {
        Button(role: .destructive) {
            WKInterfaceDevice.current().play(.click)
            Task { await viewModel.clearGraph() }
            onDismiss()
        } label: {
            Label("Reset", systemImage: "arrow.counterclockwise")
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .accessibilityIdentifier("resetGraphButton")
    }
    
    private var deleteGraphButton: some View {
        Button(role: .destructive) {
            WKInterfaceDevice.current().play(.click)
            Task {
                do {
                    try await viewModel.model.deleteGraph(name: graphName)
                    graphName = "default"
                    try await viewModel.model.loadGraph(name: "default")
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
