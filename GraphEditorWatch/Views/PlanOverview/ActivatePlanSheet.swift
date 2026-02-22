//
//  ActivatePlanSheet.swift
//  GraphEditorWatch
//
//  Plan activation sheet with notification scheduling.
//

import SwiftUI
import UserNotifications
import GraphEditorShared

struct ActivatePlanSheet: View {
    let planID: NodeID
    @ObservedObject var viewModel: GraphViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var enableReminders = true
    @State private var isActivating = false

    var meal: MealNode? {
        viewModel.model.nodes.first(where: { $0.id == planID })?.unwrapped as? MealNode
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("🌮 \(meal?.name ?? "Taco Night")")
                        .font(.headline)
                    if let meal = meal {
                        Label(formatDinnerTime(meal.dinnerTime), systemImage: "clock")
                            .font(.caption)
                    }
                }

                Section("Options") {
                    Toggle("Set Reminders", isOn: $enableReminders)
                }

                Section {
                    Button {
                        activatePlan()
                    } label: {
                        HStack {
                            Spacer()
                            Label(
                                isActivating ? "Activating..." : "Activate Plan",
                                systemImage: "bolt.fill"
                            )
                            .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isActivating)
                    .listRowBackground(Color.orange)
                    .foregroundStyle(.white)
                }
            }
            .navigationTitle("Activate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func formatDinnerTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func activatePlan() {
        isActivating = true
        Task { @MainActor in
            // Update plan status to active
            viewModel.model.updatePlanStatus(planID, to: .active)

            // Schedule reminders if enabled
            if enableReminders {
                await scheduleTaskReminders()
            }

            dismiss()
        }
    }

    private func scheduleTaskReminders() async {
        let center = UNUserNotificationCenter.current()

        // Request permission
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        // Remove previous notifications for this plan
        center.removePendingNotificationRequests(withIdentifiers: ["plan-\(planID.uuidString)"])

        // Schedule notification for dinner time
        if let meal = meal {
            let content = UNMutableNotificationContent()
            content.title = meal.name
            content.body = "Taco Night starts soon! \(meal.guests) guests expected."
            content.sound = .default

            // Notify 30 minutes before dinner
            let fireDate = meal.dinnerTime.addingTimeInterval(-30 * 60)
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "plan-\(planID.uuidString)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }

        // Schedule task reminders
        let tasks = viewModel.model.orderedTasks(for: planID)
        for task in tasks {
            guard let startTime = task.plannedStart else { continue }
            guard startTime > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Time to: \(task.taskType.displayName)"
            content.body = "Est. \(task.estimatedTime) minutes"
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: startTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "task-\(task.id.uuidString)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
