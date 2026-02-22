//
//  TableSetupDetailView.swift
//  GraphEditorWatch
//
//  Table configuration for a Taco Night plan: Taco Bar mode or Seating Chart.
//

import SwiftUI
import GraphEditorShared

struct TableSetupDetailView: View {
    let planID: NodeID
    @ObservedObject var viewModel: GraphViewModel
    @State private var mode: TableMode = .tacoBar

    var meal: MealNode? {
        viewModel.model.nodes.first(where: { $0.id == planID })?.unwrapped as? MealNode
    }
    var table: TableNode? { viewModel.model.tableForMeal(planID) }
    var persons: [PersonNode] { viewModel.model.personsForMeal(planID) }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Mode picker
                Picker("Layout", selection: $mode) {
                    Text("Taco Bar").tag(TableMode.tacoBar)
                    Text("Seating").tag(TableMode.seatingChart)
                }
                .pickerStyle(.wheel)

                if mode == .tacoBar {
                    TacoBarChecklistView(planID: planID, viewModel: viewModel)
                } else {
                    SeatingAssignmentView(table: table, persons: persons, viewModel: viewModel)
                }

                ExtrasView(guestCount: persons.count)
            }
            .padding()
        }
        .navigationTitle("Table Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            mode = meal?.tableMode ?? .tacoBar
        }
        .onChange(of: mode) { newMode in
            viewModel.model.updateTableMode(planID, to: newMode)
        }
    }
}

// MARK: - Taco Bar Checklist

private struct TacoBarChecklistView: View {
    let planID: NodeID
    @ObservedObject var viewModel: GraphViewModel

    var linkedTacos: [TacoNode] { viewModel.model.tacosForMeal(planID) }

    // Generate an ordered bar setup from linked tacos
    var barItems: [String] {
        var items: [String] = []
        // Shells first
        let shells: [String] = linkedTacos.compactMap { taco in
            switch taco.shell {
            case .crunchy: return "Crunchy Shells"
            case .softFlour: return "Flour Tortillas"
            case .softCorn: return "Corn Tortillas"
            case .none: return nil
            }
        }
        items += Array(Set(shells)).sorted()

        // Then proteins
        let proteins: [String] = linkedTacos.compactMap { taco in
            switch taco.protein {
            case .beef: return "Beef (Carne)"
            case .chicken: return "Chicken (Pollo)"
            case .none: return nil
            }
        }
        items += Array(Set(proteins)).sorted()

        // Then toppings (aggregated, alphabetical)
        let toppings = Set(linkedTacos.flatMap(\.toppings)).sorted()
        items += toppings

        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bar Layout Order")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if barItems.isEmpty {
                Text("Add tacos to Menu to generate bar layout.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(barItems.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .trailing)
                        Text(item)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Seating Assignment

private struct SeatingAssignmentView: View {
    let table: TableNode?
    let persons: [PersonNode]
    @ObservedObject var viewModel: GraphViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Seating")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let table = table {
                ForEach(0..<table.totalSeats, id: \.self) { seatIndex in
                    HStack {
                        Text("Seat \(seatIndex + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let personID = table.seatingAssignments[seatIndex],
                           let person = persons.first(where: { $0.id == personID }) {
                            Text(person.name)
                                .font(.subheadline)
                        } else {
                            Text("—")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Text("No table configured. Add a table from the graph canvas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Extras

private struct ExtrasView: View {
    let guestCount: Int

    var napkins: Int { max(guestCount + 2, 4) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Extras")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "square.and.pencil")
                Text("Napkins")
                Spacer()
                Text("\(napkins)")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                Text("Drinks")
                Spacer()
                Text("\(guestCount)")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
