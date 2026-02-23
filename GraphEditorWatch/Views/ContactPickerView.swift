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
    
    @State private var searchQuery: String = ""
    @State private var allContacts: [CNContact] = []
    @State private var isLoading: Bool = true
    @State private var isSearching: Bool = false
    @State private var errorMessage: String?
    @State private var showSearchField: Bool = false
    
    private var displayedContacts: [CNContact] {
        if searchQuery.isEmpty {
            return allContacts
        } else {
            // Filter locally for fast response
            return allContacts.filter { contact in
                let fullName = "\(contact.givenName) \(contact.familyName)".lowercased()
                let nickname = contact.nickname.lowercased()
                let query = searchQuery.lowercased()
                return fullName.contains(query) || nickname.contains(query)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Collapsible search field - icon only when collapsed
                if showSearchField {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .font(.caption)

                        TextField("Search", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.caption)

                        Button(action: {
                            searchQuery = ""
                            showSearchField = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    // Compact search icon button
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showSearchField = true
                            }
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(6)
                                .background(Color.blue.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Contact list
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading Contacts...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if allContacts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.title)
                            .foregroundColor(.gray)
                        Text("No Contacts Found")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if displayedContacts.isEmpty {
                    // Filtered results empty
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.title)
                            .foregroundColor(.gray)

                        Text("No matches for '\(searchQuery)'")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Show contacts list
                    List {
                        ForEach(displayedContacts, id: \.identifier) { contact in
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
            .navigationTitle("Link Contact")
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
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Request access
            let granted = try await ContactManager.shared.requestAccess()
            
            guard granted else {
                errorMessage = "Contact access denied. Please enable in Settings."
                return
            }
            
            // Fetch all contacts
            let contacts = try await ContactManager.shared.fetchAllContacts()
            
            await MainActor.run {
                allContacts = contacts
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load contacts: \(error.localizedDescription)"
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
