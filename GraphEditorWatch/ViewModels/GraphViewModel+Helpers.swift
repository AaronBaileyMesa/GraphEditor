//
//  GraphViewModel+Helpers.swift
//  GraphEditorWatch
//
//  Extension for internal helper methods

import Foundation
import GraphEditorShared
import os

// MARK: - Internal Helpers
extension GraphViewModel {
    
    /// Debounces save operations to avoid excessive I/O
    @MainActor
    internal func saveAfterDelay() async {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                do {
                    try await self?.model.saveGraph()
                    try self?.saveViewState()
                } catch {
                    #if DEBUG
                    Logger(subsystem: "io.handcart.GraphEditor", category: "viewmodel")
                        .error("Save failed: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }
}
