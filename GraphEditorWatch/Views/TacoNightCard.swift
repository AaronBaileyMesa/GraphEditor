//
//  TacoNightCard.swift
//  GraphEditorWatch
//
//  Prominent card component shown on the Dashboard for the active taco night plan.
//

import SwiftUI
import GraphEditorShared

/// Card displayed on DashboardView representing the current Taco Night plan
struct TacoNightCard: View {
    let plan: MealNode?
    let progress: Double?

    var body: some View {
        VStack(spacing: 8) {
            // Taco icon
            TacoIconView(protein: plan?.protein, shell: .softFlour, size: 44)

            if let plan = plan {
                // Active plan
                Text(plan.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let progress = progress, progress > 0 {
                    // Progress ring + summary
                    HStack(spacing: 6) {
                        ProgressView(value: progress)
                            .progressViewStyle(.circular)
                            .frame(width: 20, height: 20)
                            .tint(.green)

                        Text("\(plan.guests) guests • \(Int(progress * 100))% done")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("\(plan.guests) guests")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Tap to open plan")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else {
                // No active plan
                Text("Plan or Resume\nTaco Night")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("Tap to get started")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
