//
//  PersonCreationSheet.swift
//  GraphEditor
//
//  Immediately creates a new PersonNode when shown
//

import SwiftUI
import GraphEditorShared

@available(watchOS 10.0, *)
struct PersonCreationSheet: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void

    var body: some View {
        // This view never actually appears - we create the person immediately
        EmptyView()
            .onAppear {
                createNewPerson()
            }
    }

    // MARK: - Actions

    private func createNewPerson() {
        Task {
            // Create person with default "New Person" name
            let person = await viewModel.model.addPersonToPeopleList()

            // Save
            try? await viewModel.model.saveGraph()

            // Select and zoom to the new person
            await MainActor.run {
                viewModel.setSelectedNode(person.id, zoomToFit: true)
                onDismiss()
            }
        }
    }
}
