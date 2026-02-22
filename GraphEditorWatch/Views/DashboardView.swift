//
//  DashboardView.swift
//  GraphEditorWatch
//
//  Home screen showing graph statistics and access to the graph canvas.
//

import SwiftUI
import GraphEditorShared

/// Home/Dashboard screen shown at app launch when homeEconomicsEnabled is true
struct DashboardView: View {
    @ObservedObject var viewModel: GraphViewModel

    /// Compute node counts by type
    private var nodeCounts: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        
        for node in viewModel.model.nodes {
            let unwrapped = node.unwrapped
            let typeName: String
            if unwrapped is MealNode {
                typeName = "Meal"
            } else if unwrapped is PersonNode {
                typeName = "Person"
            } else if unwrapped is TableNode {
                typeName = "Table"
            } else if unwrapped is TacoNode {
                typeName = "Taco"
            } else if unwrapped is TaskNode {
                typeName = "Task"
            } else if unwrapped is RecipeNode {
                typeName = "Recipe"
            } else if unwrapped is IngredientNode {
                typeName = "Ingredient"
            } else if unwrapped is PreferenceNode {
                typeName = "Preference"
            } else if unwrapped is DecisionNode {
                typeName = "Decision"
            } else if unwrapped is ChoiceNode {
                typeName = "Choice"
            } else if unwrapped is TransactionNode {
                typeName = "Transaction"
            } else if unwrapped is CategoryNode {
                typeName = "Category"
            } else if unwrapped is Node {
                typeName = "Node"
            } else {
                typeName = "Other"
            }
            
            counts[typeName, default: 0] += 1
        }
        
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Node counts by type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Graph Statistics")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if nodeCounts.isEmpty {
                            Text("No nodes in graph")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(nodeCounts, id: \.name) { item in
                                HStack {
                                    Text(item.name)
                                        .font(.caption)
                                    Spacer()
                                    Text("\(item.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("Home")
        }
    }
}
