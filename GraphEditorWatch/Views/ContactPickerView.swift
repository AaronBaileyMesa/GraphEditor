//
//  ContactPickerView.swift
//  GraphEditor
//
//  Contact picker for linking contacts to PersonNodes
//

import SwiftUI
import Contacts

@available(watchOS 10.0, *)
struct ContactPickerView: View {
    @Environment(\.dismiss) var dismiss
    let onContactSelected: (CNContact) -> Void
    
    @State private var contacts: [CNContact] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    
    var filteredContacts: [CNContact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            let name = "\(contact.givenName) \(contact.familyName) \(contact.nickname)"
            return name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading Contacts...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button("Dismiss") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else if contacts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.title)
                            .foregroundColor(.gray)
                        Text("No Contacts Found")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(filteredContacts, id: \.identifier) { contact in
                            Button(action: {
                                onContactSelected(contact)
                                dismiss()
                            }) {
                                ContactRowView(contact: contact)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadContacts()
        }
    }
    
    private func loadContacts() async {
        do {
            // Request access
            let granted = try await ContactManager.shared.requestAccess()
            
            guard granted else {
                errorMessage = "Contact access denied. Please enable in Settings."
                isLoading = false
                return
            }
            
            // Fetch contacts
            let fetchedContacts = try await ContactManager.shared.fetchAllContacts()
            
            await MainActor.run {
                contacts = fetchedContacts
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load contacts: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

@available(watchOS 10.0, *)
struct ContactRowView: View {
    let contact: CNContact
    
    private var displayName: String {
        "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or placeholder
            if let thumbnailData = contact.thumbnailImageData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.body)
                
                if !contact.nickname.isEmpty {
                    Text(contact.nickname)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
