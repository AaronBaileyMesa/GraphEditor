//
//  TacoNodeMenuView.swift
//  GraphEditorWatch
//
//  Menu view for configuring a single taco
//

import SwiftUI
import WatchKit
import GraphEditorShared

@available(watchOS 10.0, *)
struct TacoNodeMenuView: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void
    @Binding var selectedNodeID: NodeID?
    
    @State private var selectedProtein: ProteinType?
    @State private var selectedShell: ShellType?
    @State private var selectedToppings: [String] = []
    
    // Common toppings
    private let commonToppings = [
        "Lettuce", "Tomatoes", "Cheese", "Sour Cream",
        "Guacamole", "Salsa", "Onions", "Cilantro",
        "Jalapeños", "Hot Sauce"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                Text("🌮 Taco Configuration")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 4)
                
                // Protein Section
                proteinSection
                
                // Shell Section
                shellSection
                
                // Toppings Section
                toppingsSection
                
                // Actions
                actionsSection
            }
            .padding(8)
        }
        .navigationTitle("Taco Menu")
        .onAppear {
            loadTacoNode()
        }
    }
    
    // MARK: - Sections
    
    private var proteinSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Protein")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)
            
            ForEach(ProteinType.allCases, id: \.self) { protein in
                Button {
                    selectedProtein = protein
                    saveChanges()
                } label: {
                    HStack(spacing: 4) {
                        Text(proteinEmoji(for: protein))
                        Text(protein.rawValue.capitalized)
                            .font(.caption)
                        Spacer()
                        if selectedProtein == protein {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .tint(selectedProtein == protein ? .green : .gray)
            }
        }
    }
    
    private var shellSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Shell Type")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)
            
            ForEach(ShellType.allCases, id: \.self) { shell in
                Button {
                    selectedShell = shell
                    saveChanges()
                } label: {
                    HStack(spacing: 4) {
                        Text(shell.displayName)
                            .font(.caption)
                        Spacer()
                        if selectedShell == shell {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .tint(selectedShell == shell ? .green : .gray)
            }
        }
    }
    
    private var toppingsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Toppings")
                .font(.subheadline.bold())
                .padding(.bottom, 2)
            
            ForEach(commonToppings, id: \.self) { topping in
                HStack(spacing: 4) {
                    Text(topping)
                        .font(.caption)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { selectedToppings.contains(topping) },
                        set: { isOn in
                            if isOn {
                                addTopping(topping)
                            } else {
                                removeTopping(topping)
                            }
                        }
                    ))
                    .labelsHidden()
                }
                .padding(.vertical, 1)
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 4) {
            Text("Actions")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)
            
            Button {
                deleteNode()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.caption)
                    Text("Delete")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
    
    // MARK: - Helpers
    
    private func proteinEmoji(for protein: ProteinType) -> String {
        switch protein {
        case .beef: return "🥩"
        case .chicken: return "🍗"
        }
    }
    
    private func loadTacoNode() {
        guard let nodeID = selectedNodeID,
              let tacoNode = viewModel.model.nodes.first(where: { $0.id == nodeID })?.unwrapped as? TacoNode else {
            return
        }
        
        selectedProtein = tacoNode.protein
        selectedShell = tacoNode.shell
        selectedToppings = tacoNode.toppings
    }
    
    private func saveChanges() {
        guard let nodeID = selectedNodeID,
              let index = viewModel.model.nodes.firstIndex(where: { $0.id == nodeID }),
              var tacoNode = viewModel.model.nodes[index].unwrapped as? TacoNode else {
            return
        }
        
        tacoNode = tacoNode
            .with(protein: selectedProtein)
            .with(shell: selectedShell)
            .with(toppings: selectedToppings)
        
        viewModel.model.nodes[index] = AnyNode(tacoNode)
        WKInterfaceDevice.current().play(.click)
    }
    
    private func addTopping(_ topping: String) {
        if !selectedToppings.contains(topping) {
            selectedToppings.append(topping)
            saveChanges()
        }
    }
    
    private func removeTopping(_ topping: String) {
        selectedToppings.removeAll { $0 == topping }
        saveChanges()
        WKInterfaceDevice.current().play(.click)
    }
    
    private func deleteNode() {
        guard let id = selectedNodeID else { return }
        
        Task { @MainActor in
            await viewModel.model.deleteNode(withID: id)
            viewModel.setSelectedNode(nil)
            onDismiss()
        }
    }
}
