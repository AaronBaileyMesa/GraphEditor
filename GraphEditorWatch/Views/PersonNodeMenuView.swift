//
//  PersonNodeMenuView.swift
//  GraphEditor
//
//  Menu view for PersonNode with preferences editing
//

import SwiftUI
import WatchKit
import GraphEditorShared
import Contacts

@available(watchOS 10.0, *)
struct PersonNodeMenuView: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void
    @Binding var selectedNodeID: NodeID?
    
    @State private var personNode: PersonNode?
    @State private var editedName: String = ""
    @State private var editedSpiceLevel: String?
    @State private var editedRestrictions: [String] = []
    @State private var showEditSheet: Bool = false
    @State private var showTablePicker: Bool = false
    @State private var showContactPicker: Bool = false
    @State private var currentTable: TableNode?
    @State private var currentSeatIndex: Int?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let person = personNode {
                    // Person Info Section with thumbnail
                    VStack(spacing: 8) {
                        // Contact thumbnail if available
                        if let thumbnailData = person.thumbnailImageData,
                           let uiImage = UIImage(data: thumbnailData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        }
                        
                        Text(person.name)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 4)
                    
                    // Only show preferences if they're set
                    if person.defaultSpiceLevel != nil || !person.dietaryRestrictions.isEmpty {
                        infoSection(person: person)
                    }
                    
                    // Only show seating section if assigned to a table
                    if currentTable != nil {
                        seatingSection(person: person)
                    }
                    
                    // Actions Section
                    Text("Actions")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    
                    actionButton(
                        person.contactIdentifier != nil ? "Update Contact" : "Link Contact",
                        icon: "person.crop.circle.badge.plus",
                        color: .purple
                    ) {
                        showContactPicker = true
                    }
                    
                    actionButton("Edit Preferences", icon: "pencil.circle.fill", color: .blue) {
                        prepareEdit()
                        showEditSheet = true
                    }
                    
                    actionButton("Close", icon: "xmark.circle.fill", color: .gray) {
                        onDismiss()
                    }
                }
            }
            .padding(8)
        }
        .onAppear {
            loadPerson()
        }
        .sheet(isPresented: $showEditSheet) {
            editSheet
        }
        .sheet(isPresented: $showTablePicker) {
            tablePickerSheet
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView { contact in
                linkContact(contact)
            }
        }
    }
    
    // MARK: - Seating Section
    
    @ViewBuilder
    private func seatingSection(person: PersonNode) -> some View {
        if let table = currentTable, let seatIndex = currentSeatIndex {
            VStack(alignment: .leading, spacing: 6) {
                Text("Table Assignment")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                seatedView(table: table, seatIndex: seatIndex)
            }
        }
    }
    
    @ViewBuilder
    private func seatedView(table: TableNode, seatIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "table.furniture.fill")
                    .foregroundColor(.brown)
                    .font(.caption)
                Text("Table:")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text(table.name)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text("Seat:")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text("Seat \(seatIndex + 1)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            HStack(spacing: 6) {
                Button(action: {
                    showTablePicker = true
                }) {
                    Text("Change Table")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    removeFromTable()
                }) {
                    Text("Remove")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.brown.opacity(0.1))
        .cornerRadius(6)
    }
    

    // MARK: - Edit Sheet
    
    @ViewBuilder
    private var editSheet: some View {
        NavigationView {
            Form {
                Section("Name") {
                    TextField("Name", text: $editedName)
                        .onAppear {
                            // If this is a new person with the default name, clear it for easy editing
                            if editedName == "New Person" {
                                editedName = ""
                            }
                        }
                }
                
                Section("Spice Preference") {
                    Picker("Spice Level", selection: Binding(
                        get: { editedSpiceLevel ?? "none" },
                        set: { editedSpiceLevel = $0 == "none" ? nil : $0 }
                    )) {
                        Text("None").tag("none")
                        Text("Mild").tag("mild")
                        Text("Medium").tag("medium")
                        Text("Hot").tag("hot")
                    }
                }
                
                Section("Dietary Restrictions") {
                    Toggle("Vegetarian", isOn: Binding(
                        get: { editedRestrictions.contains("vegetarian") },
                        set: { if $0 { editedRestrictions.append("vegetarian") } else { editedRestrictions.removeAll { $0 == "vegetarian" } } }
                    ))
                    Toggle("Vegan", isOn: Binding(
                        get: { editedRestrictions.contains("vegan") },
                        set: { if $0 { editedRestrictions.append("vegan") } else { editedRestrictions.removeAll { $0 == "vegan" } } }
                    ))
                    Toggle("Gluten-Free", isOn: Binding(
                        get: { editedRestrictions.contains("gluten-free") },
                        set: { if $0 { editedRestrictions.append("gluten-free") } else { editedRestrictions.removeAll { $0 == "gluten-free" } } }
                    ))
                    Toggle("Dairy-Free", isOn: Binding(
                        get: { editedRestrictions.contains("dairy-free") },
                        set: { if $0 { editedRestrictions.append("dairy-free") } else { editedRestrictions.removeAll { $0 == "dairy-free" } } }
                    ))
                }
            }
            .navigationTitle("Edit Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showEditSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePerson()
                        showEditSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Info Section
    
    @ViewBuilder
    private func infoSection(person: PersonNode) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preferences")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 6) {
                if let spiceLevel = person.defaultSpiceLevel {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(spiceColor(spiceLevel))
                            .font(.caption)
                        Text("Spice Level:")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                        Text(spiceLevel.capitalized)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }
                
                if !person.dietaryRestrictions.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: "leaf.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Dietary:")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        ForEach(person.dietaryRestrictions, id: \.self) { restriction in
                            Text("• \(restriction.capitalized)")
                                .font(.caption)
                                .padding(.leading, 20)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(6)
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.body)
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(color.opacity(0.2))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Functions
    
    private func spiceColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "mild":
            return .green
        case "medium":
            return .orange
        case "hot":
            return .red
        default:
            return .gray
        }
    }
    
    // MARK: - Data Loading
    
    private func loadPerson() {
        guard let nodeID = selectedNodeID,
              let node = viewModel.model.nodes.first(where: { $0.id == nodeID }),
              let person = node.unwrapped as? PersonNode else {
            return
        }
        
        personNode = person
        
        // Find which table this person is seated at
        currentTable = nil
        currentSeatIndex = nil
        for tableNode in viewModel.model.nodes {
            if let table = tableNode.unwrapped as? TableNode {
                for (seatIndex, personID) in table.seatingAssignments where personID == person.id {
                    currentTable = table
                    currentSeatIndex = seatIndex
                    break
                }
            }
        }
    }
    
    private func prepareEdit() {
        guard let person = personNode else { return }
        editedName = person.name
        editedSpiceLevel = person.defaultSpiceLevel
        editedRestrictions = person.dietaryRestrictions
    }
    
    private func savePerson() {
        guard let person = personNode,
              let nodeIndex = viewModel.model.nodes.firstIndex(where: { $0.id == person.id }) else {
            return
        }
        
        // Generate a monogram if:
        // 1. Not linked to a contact (no contactIdentifier)
        // 2. No existing thumbnail data
        // 3. Name is not empty and not the default
        var thumbnailData = person.thumbnailImageData
        if person.contactIdentifier == nil && 
           thumbnailData == nil && 
           !editedName.isEmpty && 
           editedName != "New Person" {
            thumbnailData = MonogramGenerator.generateMonogram(from: editedName)
            print("📷 Generated monogram for '\(editedName)': \(thumbnailData?.count ?? 0) bytes")
        }
        
        // Create updated person node, preserving contact data
        let updatedPerson = PersonNode(
            id: person.id,
            label: person.label,
            position: person.position,
            velocity: person.velocity,
            radius: person.radius,
            name: editedName,
            defaultSpiceLevel: editedSpiceLevel,
            dietaryRestrictions: editedRestrictions,
            contactIdentifier: person.contactIdentifier,
            thumbnailImageData: thumbnailData,
            proteinPreference: person.proteinPreference,
            shellPreference: person.shellPreference,
            toppingPreferences: person.toppingPreferences
        )
        
        // Update in model - wrap in Task to use async methods
        Task {
            // Update the node by creating a new array (triggers @Published)
            var updatedNodes = viewModel.model.nodes
            updatedNodes[nodeIndex] = AnyNode(updatedPerson)
            viewModel.model.nodes = updatedNodes
            
            // Save to trigger persistence and refresh
            try? await viewModel.model.saveGraph()
            
            // Reload local state on main thread
            await MainActor.run {
                personNode = updatedPerson
            }
        }
    }
    
    private func linkContact(_ contact: CNContact) {
        guard let person = personNode,
              let nodeIndex = viewModel.model.nodes.firstIndex(where: { $0.id == person.id }) else {
            return
        }
        
        Task {
            // Extract contact info
            let displayName = await ContactManager.shared.displayName(for: contact)
            let thumbnailData = await ContactManager.shared.thumbnailData(for: contact)
            
            print("📇 Linking contact: \(displayName)")
            print("📷 Thumbnail data size: \(thumbnailData?.count ?? 0) bytes")
            
            // Create updated person node with contact data
            let updatedPerson = PersonNode(
                id: person.id,
                label: person.label,
                position: person.position,
                velocity: person.velocity,
                radius: person.radius,
                name: displayName.isEmpty ? person.name : displayName,
                defaultSpiceLevel: person.defaultSpiceLevel,
                dietaryRestrictions: person.dietaryRestrictions,
                contactIdentifier: contact.identifier,
                thumbnailImageData: thumbnailData,
                proteinPreference: person.proteinPreference,
                shellPreference: person.shellPreference,
                toppingPreferences: person.toppingPreferences
            )
            
            // Update in model
            var updatedNodes = viewModel.model.nodes
            updatedNodes[nodeIndex] = AnyNode(updatedPerson)
            viewModel.model.nodes = updatedNodes
            
            // Save to trigger persistence and refresh
            try? await viewModel.model.saveGraph()
            
            // Reload local state on main thread
            await MainActor.run {
                personNode = updatedPerson
            }
        }
    }
    
    // MARK: - Table Picker Sheet
    
    @ViewBuilder
    private var tablePickerSheet: some View {
        NavigationView {
            List {
                Section("Available Tables") {
                    ForEach(availableTables, id: \.id) { table in
                        Button(action: {
                            // Show seat picker for this table
                            assignToTable(table)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(table.name)
                                    .font(.body)
                                
                                Text("\(table.seatingAssignments.count)/\(table.totalSeats) seats occupied")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showTablePicker = false
                    }
                }
            }
        }
    }
    
    // MARK: - Seating Helpers
    
    private var availableTables: [TableNode] {
        viewModel.model.nodes.compactMap { $0.unwrapped as? TableNode }
            .filter { $0.seatingAssignments.count < $0.totalSeats }
    }
    
    private func assignToTable(_ table: TableNode) {
        guard let person = personNode else { return }
        
        // Find first available seat (0 to totalSeats-1)
        let occupiedSeats = Set(table.seatingAssignments.keys)
        guard let firstAvailableSeat = (0..<table.totalSeats).first(where: { !occupiedSeats.contains($0) }) else {
            showTablePicker = false
            return
        }
        
        Task {
            // Remove from current table if assigned
            if let currentTable = currentTable {
                await viewModel.model.removePersonFromTable(
                    personID: person.id,
                    tableID: currentTable.id
                )
            }
            
            // Assign to new table
            await viewModel.model.assignPersonToTable(
                personID: person.id,
                tableID: table.id,
                seatIndex: firstAvailableSeat
            )
            
            // Reload
            await MainActor.run {
                loadPerson()
                showTablePicker = false
            }
        }
    }
    
    private func removeFromTable() {
        guard let person = personNode, let table = currentTable else { return }
        
        Task {
            await viewModel.model.removePersonFromTable(
                personID: person.id,
                tableID: table.id
            )
            
            // Reload
            await MainActor.run {
                loadPerson()
            }
        }
    }
}
