//
//  PlanOverviewScreen.swift
//  GraphEditorWatch
//
//  Central hub for managing a Taco Night plan, with section cards for
//  Attendees, Menu, Table, Shopping, and Timeline.
//

import SwiftUI
import GraphEditorShared

/// The main plan management hub, navigated to from DashboardView
struct PlanOverviewScreen: View {
    let planID: NodeID
    @ObservedObject var viewModel: GraphViewModel
    @State private var showActivate = false

    var meal: MealNode? {
        viewModel.model.nodes.first(where: { $0.id == planID })?.unwrapped as? MealNode
    }

    // MARK: - Computed Summaries

    var attendeesSummary: String {
        let linked = viewModel.model.personsForMeal(planID).count
        let target = meal?.guests ?? 0
        return linked == 0 ? "Tap to add guests" : "\(linked)/\(target) guests"
    }

    var menuSummary: String {
        let count = viewModel.model.tacosForMeal(planID).count
        return count == 0 ? "Tap to build menu" : "\(count) taco type\(count == 1 ? "" : "s")"
    }

    var tableSummary: String {
        guard let table = viewModel.model.tableForMeal(planID) else {
            return "Not configured"
        }
        let modeLabel = meal?.tableMode == .seatingChart ? "Seating" : "Taco Bar"
        return "\(modeLabel) • \(table.totalSeats) seats"
    }

    var shoppingListSummary: String {
        let items = viewModel.model.generateTacoShoppingList(for: planID)
        return items.isEmpty ? "Add tacos to generate" : "\(items.count) items"
    }

    var timelineSummary: String {
        let tasks = viewModel.model.orderedTasks(for: planID)
        guard let first = tasks.first, let start = first.plannedStart else {
            return "Not scheduled"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Start \(formatter.localizedString(for: start, relativeTo: Date()))"
    }

    var workflowProgress: Double {
        viewModel.model.workflowProgress(for: planID)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header
                PlanHeaderView(planID: planID, viewModel: viewModel)

                // Progress if workflow has started
                if workflowProgress > 0 {
                    ProgressView(value: workflowProgress)
                        .tint(.green)
                        .padding(.horizontal, 4)
                }

                // Core section cards
                SectionCard(
                    icon: "person.3.fill",
                    title: "Attendees",
                    summary: attendeesSummary,
                    destination: AttendeesDetailView(planID: planID, viewModel: viewModel)
                )

                SectionCard(
                    icon: "takeoutbag.and.cup.and.straw.fill",
                    title: "Menu",
                    summary: menuSummary,
                    destination: MenuDetailView(planID: planID, viewModel: viewModel)
                )

                SectionCard(
                    icon: "rectangle.split.3x3",
                    title: "Table Setup",
                    summary: tableSummary,
                    destination: TableSetupDetailView(planID: planID, viewModel: viewModel)
                )

                // Logistics section
                Label("Logistics", systemImage: "list.bullet.clipboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                SectionCard(
                    icon: "cart.fill",
                    title: "Shopping List",
                    summary: shoppingListSummary,
                    destination: ShoppingListDetailView(planID: planID, viewModel: viewModel)
                )

                SectionCard(
                    icon: "clock.fill",
                    title: "Prep Timeline",
                    summary: timelineSummary,
                    destination: PrepTimelineDetailView(planID: planID, viewModel: viewModel)
                )

                // View full graph
                NavigationLink(destination: ContentView(viewModel: viewModel)) {
                    Label("View Connections", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                // Activate / Complete Plan button
                if meal?.planStatus == .active {
                    Button {
                        viewModel.model.updatePlanStatus(planID, to: .completed)
                        // Record achievement attempt and unlock milestones
                        viewModel.recordTacoNightCompletion(mealID: planID)
                    } label: {
                        Label("Mark Complete", systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    Button { showActivate = true } label: {
                        Label("Activate Plan", systemImage: "bolt.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showActivate) {
            ActivatePlanSheet(planID: planID, viewModel: viewModel)
        }
    }
}
