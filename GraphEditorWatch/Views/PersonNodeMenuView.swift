//
//  PersonNodeMenuView.swift
//  GraphEditorWatch
//
//  Menu view for PersonNode with preferences editing
//

import SwiftUI
import WatchKit
import GraphEditorShared

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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let person = personNode {
                    // Person Info Section
                    Text(person.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 4)
                    
                    infoSection(person: person)
                    
                    // Actions Section
                    Text("Actions")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    
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
                
                if person.defaultSpiceLevel == nil && person.dietaryRestrictions.isEmpty {
                    Text("No preferences set")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .italic()
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
        
        // Create updated person node
        let updatedPerson = PersonNode(
            id: person.id,
            label: person.label,
            position: person.position,
            velocity: person.velocity,
            radius: person.radius,
            name: editedName,
            defaultSpiceLevel: editedSpiceLevel,
            dietaryRestrictions: editedRestrictions
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
}
