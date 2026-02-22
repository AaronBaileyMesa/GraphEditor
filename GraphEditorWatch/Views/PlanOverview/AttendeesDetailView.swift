//
//  AttendeesDetailView.swift
//  GraphEditorWatch
//
//  Attendee management for a Taco Night plan.
//

import SwiftUI
import GraphEditorShared

struct AttendeesDetailView: View {
    let planID: NodeID
    @ObservedObject var viewModel: GraphViewModel

    var linkedPersons: [PersonNode] { viewModel.model.personsForMeal(planID) }
    var allPersons: [PersonNode] { viewModel.model.allPersons() }
    var unlinkedPersons: [PersonNode] {
        let linkedIDs = Set(linkedPersons.map(\.id))
        return allPersons.filter { !linkedIDs.contains($0.id) }
    }

    var body: some View {
        List {
            // Quick action buttons
            Section {
                Button {
                    Task { @MainActor in
                        for person in allPersons {
                            await viewModel.model.linkPersonToMeal(personID: person.id, mealID: planID)
                        }
                    }
                } label: {
                    Label("Add All", systemImage: "person.3.fill")
                }

                if linkedPersons.count > 1 {
                    Button(role: .destructive) {
                        for person in linkedPersons {
                            viewModel.model.unlinkPersonFromMeal(personID: person.id, mealID: planID)
                        }
                    } label: {
                        Label("Solo Mode", systemImage: "person.fill")
                    }
                }
            }

            // Linked attendees
            if !linkedPersons.isEmpty {
                Section("Attending (\(linkedPersons.count))") {
                    ForEach(linkedPersons, id: \.id) { person in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(person.name)
                            Spacer()
                            if !person.dietaryRestrictions.isEmpty {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.model.unlinkPersonFromMeal(personID: person.id, mealID: planID)
                            } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                        }
                    }
                }
            }

            // Unlinked persons to add
            if !unlinkedPersons.isEmpty {
                Section("Add Guests") {
                    ForEach(unlinkedPersons, id: \.id) { person in
                        Button {
                            Task { @MainActor in
                                await viewModel.model.linkPersonToMeal(personID: person.id, mealID: planID)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.green)
                                Text(person.name)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Attendees")
        .navigationBarTitleDisplayMode(.inline)
    }
}
