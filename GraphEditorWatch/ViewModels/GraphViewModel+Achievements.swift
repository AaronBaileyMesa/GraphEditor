//
//  GraphViewModel+Achievements.swift
//  GraphEditorWatch
//
//  Achievement system integration for GraphViewModel
//

import Foundation
import GraphEditorShared

extension GraphViewModel {

    /// Initialize achievement milestones for the current graph if needed
    /// Should be called when loading graphs that might need milestone initialization
    @MainActor
    public func initializeAchievementsIfNeeded() {
        // Only initialize for the user's personal graph (not meal plans or other graphs)
        guard currentGraphName == "_userGraph" || currentGraphName == "default" else {
            return
        }

        // Check if taco night milestones need initialization
        if model.needsMilestoneInitialization(for: .tacoNight) {
            model.initializeTacoNightMilestones()
        }
    }

    /// Record a completed taco night event and unlock milestones
    @MainActor
    public func recordTacoNightCompletion(mealID: UUID) {
        // Find the meal node
        guard let mealNode = model.nodes.first(where: { $0.id == mealID })?.unwrapped as? MealNode else {
            return
        }

        // Create attempt from meal
        let attempt = model.createAttemptFromMeal(mealNode)

        // Record attempt and get newly unlocked milestones
        let unlockedMilestones = model.recordAttempt(attempt)

        // TODO: Show celebration UI for unlocked milestones
    }
}
