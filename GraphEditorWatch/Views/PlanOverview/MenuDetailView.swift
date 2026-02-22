//
//  MenuDetailView.swift
//  GraphEditorWatch
//
//  Multi-taco selection with scaling for a Taco Night plan.
//

import SwiftUI
import GraphEditorShared

struct MenuDetailView: View {
    let planID: NodeID
    @ObservedObject var viewModel: GraphViewModel

    @State private var selectedTacoIDs: Set<NodeID> = []
    @State private var tacosPerPerson: Double = 2.5

    var meal: MealNode? {
        viewModel.model.nodes.first(where: { $0.id == planID })?.unwrapped as? MealNode
    }
    var linkedTacos: [TacoNode] { viewModel.model.tacosForMeal(planID) }
    var allTacos: [TacoNode] { viewModel.model.allTacos() }
    var guestCount: Int { meal?.guests ?? 1 }
    var totalTacos: Int { Int((Double(guestCount) * tacosPerPerson).rounded(.up)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Preview pane
                VStack(spacing: 2) {
                    Text("\(totalTacos) tacos total")
                        .font(.headline)
                    Text(String(format: "%.1f per person • %d guests", tacosPerPerson, guestCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

                // Scaling slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tacos per person")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $tacosPerPerson, in: 1...5, step: 0.5)
                        .tint(.orange)
                }

                Divider()

                // Taco list with multi-select
                if allTacos.isEmpty {
                    Text("No tacos in graph yet.\nAdd tacos from the graph canvas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    ForEach(allTacos, id: \.id) { taco in
                        TacoSelectRow(
                            taco: taco,
                            isSelected: selectedTacoIDs.contains(taco.id),
                            onToggle: { toggleTaco(taco.id) }
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { saveAndScale() }
            }
        }
        .onAppear {
            selectedTacoIDs = Set(linkedTacos.map(\.id))
            tacosPerPerson = meal?.tacosPerPerson ?? 2.5
        }
    }

    private func toggleTaco(_ id: NodeID) {
        if selectedTacoIDs.contains(id) {
            selectedTacoIDs.remove(id)
        } else {
            selectedTacoIDs.insert(id)
        }
    }

    private func saveAndScale() {
        Task { @MainActor in
            // Unlink tacos not in selection
            for taco in linkedTacos where !selectedTacoIDs.contains(taco.id) {
                viewModel.model.unlinkTacoFromMeal(tacoID: taco.id, mealID: planID)
            }
            // Link newly selected tacos
            let linkedIDs = Set(linkedTacos.map(\.id))
            for id in selectedTacoIDs where !linkedIDs.contains(id) {
                await viewModel.model.linkTacoToMeal(tacoID: id, mealID: planID)
            }
            // Save tacosPerPerson
            viewModel.model.updateTacosPerPerson(planID, to: tacosPerPerson)
        }
    }
}

// MARK: - Taco Select Row

private struct TacoSelectRow: View {
    let taco: TacoNode
    let isSelected: Bool
    let onToggle: () -> Void

    var proteinLabel: String {
        switch taco.protein {
        case .beef: return "Beef"
        case .chicken: return "Chicken"
        case .none: return "Custom"
        }
    }

    var shellLabel: String {
        switch taco.shell {
        case .crunchy: return "Crunchy"
        case .softFlour: return "Soft Flour"
        case .softCorn: return "Soft Corn"
        case .none: return ""
        }
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : .secondary)
                    .font(.title3)

                TacoIconView(protein: taco.protein, shell: taco.shell, size: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(proteinLabel)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text(shellLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(8)
            .background(isSelected ? Color.green.opacity(0.1) : Color.clear,
                       in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
