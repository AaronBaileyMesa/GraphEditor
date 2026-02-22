//
//  QuickEditSheet.swift
//  GraphEditorWatch
//
//  Minimal plan creation sheet shown when starting a new taco night.
//

import SwiftUI
import GraphEditorShared

/// Quick-creation modal for starting a new Taco Night plan
struct QuickEditSheet: View {
    @ObservedObject var viewModel: GraphViewModel
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var planName: String = GraphModel.defaultPlanName()
    @State private var dinnerTime: Date = {
        // Default to 6pm today
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 18
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    @State private var showWizard = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Icon
                    Text("🌮")
                        .font(.system(size: 40))

                    // Plan name field
                    TextField("Plan name", text: $planName)
                        .multilineTextAlignment(.center)

                    // Dinner time picker
                    DatePicker(
                        "Dinner Time",
                        selection: $dinnerTime,
                        displayedComponents: [.hourAndMinute]
                    )

                    // Save button
                    Button {
                        savePlan()
                    } label: {
                        Label(isSaving ? "Creating..." : "Save & Open Plan", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(isSaving || planName.isEmpty)

                    Divider()

                    // Advanced setup link
                    Button("Advanced Setup") {
                        showWizard = true
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showWizard) {
                TacoNightWizard(viewModel: viewModel, onDismiss: { showWizard = false })
            }
        }
    }

    private func savePlan() {
        isSaving = true
        Task { @MainActor in
            // Create a new MealNode with draft status
            let position = CGPoint(x: 100, y: 100)
            _ = await viewModel.model.addMeal(
                name: planName,
                date: dinnerTime,
                mealType: .dinner,
                servings: 4,
                guests: 4,
                dinnerTime: dinnerTime,
                protein: nil,
                at: position
            )
            try? await viewModel.model.saveGraph()
            dismiss()
            onSave()
        }
    }
}
