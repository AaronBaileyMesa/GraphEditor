//
//  GraphSection.swift
//  GraphEditorWatch
//
//  Created by handcart on 10/5/25.  // Updated date for refactor
//

import SwiftUI

struct GraphSection: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void
    
    @State private var graphName: String = ""
    @State private var showNewSheet: Bool = false
    @State private var newGraphName: String = ""
    @State private var graphs: [String] = []
    @State private var errorMessage: String?
    
    var body: some View {
        Section(header: Text("Graph")) {
            if viewModel.canRedo || viewModel.canUndo {
                Section(header: Text("Undo")) {
                    if viewModel.canUndo {
                        Button("Undo") {
                            Task { await viewModel.undo()}
                            onDismiss()

                        }
                    }
                    if viewModel.canRedo {
                        Button("Redo") {
                            Task { await viewModel.redo()}
                            onDismiss()
                        }
                    }
                }
            }
            
            TextField("Graph Name", text: $graphName)
                .onAppear { graphName = viewModel.currentGraphName }
            
            Button("New Graph") {
                newGraphName = ""
                showNewSheet = true
            }
            .onSubmit { /* Same as above */ }
            .sheet(isPresented: $showNewSheet) {
                VStack {
                    TextField("New Graph Name", text: $newGraphName)
                    Button("Create") {
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
            
            Button("Save Graph") {
                Task {
                    viewModel.currentGraphName = graphName
                    do {
                        try await viewModel.model.saveGraph()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    onDismiss()
                }
            }
            .onSubmit { /* Same as above */ }
            
            Button("Load Graph") {
                Task {
                    do {
                        try await viewModel.model.loadGraph(name: graphName)
                        viewModel.currentGraphName = graphName
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    onDismiss()
                }
            }
            .onSubmit { /* Same as above */ }
            
            Button("List Graphs") {
                Task {
                    do {
                        graphs = try await viewModel.model.listGraphNames()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .onSubmit { /* Same as above */ }
            
            ForEach(graphs, id: \.self) { name in
                Button(name) {
                    Task {
                        do {
                            try await viewModel.model.loadGraph(name: name)
                            viewModel.currentGraphName = name
                            graphName = name
                            onDismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            
            Button("Reset Graph", role: .destructive) {
                Task { await viewModel.clearGraph() }
                onDismiss()
            }
            .onSubmit { /* Same as above */ }
            
            Button("Delete Graph", role: .destructive) {
                Task {
                    do {
                        try await viewModel.model.deleteGraph(name: graphName)
                        graphName = "default"
                        try await viewModel.model.loadGraph(name: "default")
                        onDismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .onSubmit { /* Same as above */ }
            
            if let error = errorMessage {
                Text(error).foregroundColor(.red)
            }
        }
        .accessibilityLabel("Graph section")  // NEW: Accessibility
    }
}
