//
//  PlanHeaderView.swift
//  GraphEditorWatch
//
//  Editable header showing plan name and dinner time.
//

import SwiftUI
import GraphEditorShared

/// Header for Plan Overview showing plan name and scheduled dinner time
struct PlanHeaderView: View {
    let planID: NodeID
    @ObservedObject var viewModel: GraphViewModel
    @State private var showEditSheet = false

    var meal: MealNode? {
        viewModel.model.nodes.first(where: { $0.id == planID })?.unwrapped as? MealNode
    }

    var body: some View {
        Button { showEditSheet = true } label: {
            VStack(spacing: 4) {
                Text(meal?.name ?? "Taco Night")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let meal = meal {
                    let formatter: DateFormatter = {
                        let f = DateFormatter()
                        f.dateStyle = .medium
                        f.timeStyle = .short
                        return f
                    }()
                    Text(formatter.string(from: meal.dinnerTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Label("Tap to edit", systemImage: "pencil")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEditSheet) {
            PlanHeaderEditSheet(planID: planID, viewModel: viewModel)
        }
    }
}

/// Sheet for editing the plan name and dinner time
private struct PlanHeaderEditSheet: View {
    let planID: NodeID
    @ObservedObject var viewModel: GraphViewModel
    @Environment(\.dismiss) private var dismiss

    var meal: MealNode? {
        viewModel.model.nodes.first(where: { $0.id == planID })?.unwrapped as? MealNode
    }

    @State private var name: String = ""
    @State private var dinnerTime: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                TextField("Plan name", text: $name)
                DatePicker("Dinner time", selection: $dinnerTime, displayedComponents: [.hourAndMinute, .date])
            }
            .navigationTitle("Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                name = meal?.name ?? ""
                dinnerTime = meal?.dinnerTime ?? Date()
            }
        }
    }
}
