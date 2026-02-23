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
    @State private var searchResults: [CNContact] = []
    @State private var isSearching: Bool = false
    
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

                // Results
                if isSearching {
                    ProgressView()
                        .padding()
                } else if !searchQuery.isEmpty && !searchResults.isEmpty {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(searchResults, id: \.identifier) { contact in
                                Button(action: {
                                    onContactSelected(contact)
                                    dismiss()
                                }) {
                                    ContactRowView(contact: contact)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                    }
                } else if !searchQuery.isEmpty && searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.title)
                            .foregroundColor(.gray)

                        Text("No contacts found")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.title)
                            .foregroundColor(.gray)
                        
                        Text("Start typing to search contacts")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
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
        .onAppear {
            // Request contact access
            Task {
                _ = try? await ContactManager.shared.requestAccess()
            }
        }
    }
    
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
