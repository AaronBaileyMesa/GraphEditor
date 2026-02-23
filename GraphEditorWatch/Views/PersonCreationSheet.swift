//
//  PersonCreationSheet.swift
//  GraphEditor
//
//  Sheet for creating a new PersonNode with contact search or manual entry
//

import SwiftUI
import Contacts
import GraphEditorShared

@available(watchOS 10.0, *)
struct PersonCreationSheet: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void

    @State private var searchQuery: String = ""
    @State private var searchResults: [CNContact] = []
    @State private var isSearching: Bool = false
    @State private var showingManualEntry: Bool = false
    @State private var manualName: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.caption)

                    TextField("Search contacts", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .onChange(of: searchQuery) { _, newValue in
                            Task {
                                await performSearch(query: newValue)
                            }
                        }

                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 8)
                .padding(.top, 8)

                // Results or options
                if isSearching {
                    ProgressView()
                        .padding()
                } else if !searchQuery.isEmpty && !searchResults.isEmpty {
                    // Contact search results
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(searchResults, id: \.identifier) { contact in
                                contactRow(contact)
                            }
                        }
                        .padding(8)
                    }
                } else if !searchQuery.isEmpty && searchResults.isEmpty {
                    // No results
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.title)
                            .foregroundColor(.gray)

                        Text("No contacts found")
                            .font(.caption)
                            .foregroundColor(.gray)

                        manualEntryButton
                    }
                    .padding()
                } else {
                    // Default options
                    VStack(spacing: 12) {
                        Text("Create Person")
                            .font(.caption.bold())
                            .padding(.top, 8)

                        Button(action: {
                            showingManualEntry = true
                        }) {
                            Label("Enter Name Manually", systemImage: "pencil")
                                .font(.caption)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Text("or start typing to search contacts")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                manualEntrySheet
            }
        }
        .onAppear {
            // Request contact access if needed
            Task {
                _ = try? await ContactManager.shared.requestAccess()
            }
        }
    }

    // MARK: - Contact Row

    @ViewBuilder
    private func contactRow(_ contact: CNContact) -> some View {
        Button(action: {
            createPersonFromContact(contact)
        }) {
            HStack(spacing: 8) {
                // Thumbnail - use contact's thumbnail data or show placeholder
                if let thumbnailData = contact.thumbnailImageData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayNameSync(for: contact))
                        .font(.caption)
                        .fontWeight(.medium)

                    if !contact.nickname.isEmpty {
                        Text("(\(contact.nickname))")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func displayNameSync(for contact: CNContact) -> String {
        if !contact.nickname.isEmpty {
            return contact.nickname
        }

        let components = [contact.givenName, contact.familyName].filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }

    // MARK: - Manual Entry

    @ViewBuilder
    private var manualEntryButton: some View {
        Button(action: {
            showingManualEntry = true
        }) {
            Label("Enter Name Manually", systemImage: "pencil")
                .font(.caption)
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var manualEntrySheet: some View {
        NavigationView {
            VStack(spacing: 12) {
                Text("Enter person's name")
                    .font(.caption)
                    .foregroundColor(.gray)

                TextField("Name", text: $manualName)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                Button(action: {
                    createManualPerson()
                }) {
                    Text("Create")
                        .font(.caption.bold())
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(manualName.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(manualName.isEmpty)
            }
            .padding()
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingManualEntry = false
                        manualName = ""
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await ContactManager.shared.searchContacts(query: query)
        } catch {
            print("⚠️ Contact search failed: \(error)")
            searchResults = []
        }
    }

    private func createPersonFromContact(_ contact: CNContact) {
        Task {
            // Extract contact info
            let displayName = await ContactManager.shared.displayName(for: contact)
            let thumbnailData = await ContactManager.shared.thumbnailData(for: contact)

            print("📇 Creating person from contact: \(displayName)")

            // Create person with contact info
            let person = await viewModel.model.addPersonToPeopleList()

            // Link to contact
            _ = await viewModel.model.linkPersonToContact(
                personID: person.id,
                contactIdentifier: contact.identifier,
                thumbnailData: thumbnailData,
                displayName: displayName
            )

            // Save
            try? await viewModel.model.saveGraph()

            // Select and zoom to the new person
            await MainActor.run {
                viewModel.setSelectedNode(person.id, zoomToFit: true)
                onDismiss()
            }
        }
    }

    private func createManualPerson() {
        guard !manualName.isEmpty else { return }

        Task {
            // Create person with manual name
            let person = await viewModel.model.addPersonToPeopleList()

            // Update with custom name
            var editState = PersonEditState(from: person)
            editState.name = manualName

            // Generate monogram for manual entry
            let monogramData = MonogramGenerator.generateMonogram(from: manualName)
            editState.thumbnailImageData = monogramData

            _ = await viewModel.model.updatePerson(personID: person.id, with: editState)

            // Save
            try? await viewModel.model.saveGraph()

            // Select and zoom to the new person
            await MainActor.run {
                viewModel.setSelectedNode(person.id, zoomToFit: true)
                showingManualEntry = false
                manualName = ""
                onDismiss()
            }
        }
    }
}
