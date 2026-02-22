//
//  MealDefinitionSheet.swift
//  GraphEditor
//
//  Sheet for defining a new taco dinner meal
//

import SwiftUI
import GraphEditorShared

@available(watchOS 10.0, *)
struct MealDefinitionSheet: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void

    @State private var guests: Int = 4
    @State private var dinnerTime: Date = {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 18, minute: 30, second: 0, of: Date()) ?? Date()
    }()
    @State private var protein: ProteinType = .beef
    @State private var isCreating: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("New Taco Dinner")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Guests
                NavigationLink {
                    SimpleCrownNumberInput(value: Binding(
                        get: { Double(guests) },
                        set: { guests = Int($0) }
                    ))
                    .navigationTitle("Guests")
                } label: {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Guests")
                            .font(.caption)
                        Spacer()
                        Text("\(guests)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.bordered)

                // Dinner Time
                NavigationLink {
                    TimePickerView(time: $dinnerTime)
                } label: {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Dinner Time")
                            .font(.caption)
                        Spacer()
                        Text(timeString)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.bordered)

                // Protein Choice
                VStack(spacing: 6) {
                    Text("Protein")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        Button {
                            protein = .beef
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 18))
                                Text("Beef")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(protein == .beef ? .red : .gray)

                        Button {
                            protein = .chicken
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "bird.fill")
                                    .font(.system(size: 18))
                                Text("Chicken")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(protein == .chicken ? .yellow : .gray)
                    }
                }

                // Create Plan Button
                Button {
                    createTacoPlan()
                } label: {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(maxWidth: .infinity)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Create Plan")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreating)
            }
            .padding()
        }
        .navigationTitle("Taco Dinner")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: dinnerTime)
    }

    private func createTacoPlan() {
        isCreating = true

        Task { @MainActor in
            // Position for the new meal aligned with directional layout anchor
            // For horizontal layout with 35pt spacing, 5 tasks (175pt total):
            // anchor = 20 + (165 - 175) / 2 = 15pt (but segment doesn't fit, so use margin)
            // anchor = 20pt for segments that don't fit
            let mealPosition = CGPoint(x: 20, y: 125)

            // Build the taco dinner graph
            _ = await TacoTemplateBuilder.buildGraph(
                in: viewModel.model,
                guests: guests,
                dinnerTime: dinnerTime,
                protein: protein,
                at: mealPosition
            )

            // Start simulation to settle the new nodes
            await viewModel.model.startSimulation()

            isCreating = false
            onDismiss()
        }
    }
}
