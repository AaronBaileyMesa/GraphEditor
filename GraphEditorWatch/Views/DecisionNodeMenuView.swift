//
//  DecisionNodeMenuView.swift
//  GraphEditorWatch
//
//  Menu view for DecisionNode with choice selection and navigation
//

import SwiftUI
import WatchKit
import GraphEditorShared

@available(watchOS 10.0, *)
struct DecisionNodeMenuView: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void
    @Binding var selectedNodeID: NodeID?
    
    @State private var decisionNode: DecisionNode?
    @State private var choices: [ChoiceNode] = []
    @State private var numericValue: Double = 0
    @State private var showNumericInput: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let decision = decisionNode {
                    // Progress Section
                    progressIndicator(for: decision)
                    
                    // Question Section
                    Text(decision.question)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 4)
                    
                    // Input based on type
                    switch decision.inputType {
                    case .singleChoice, .multiChoice:
                        choicesSection(decision: decision)
                    case .numeric:
                        numericSection(decision: decision)
                    }
                    
                    // Navigation Section
                    if isAnswered(decision) {
                        navigationSection(decision: decision)
                    }
                    
                    // Actions Section
                    Text("Actions")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    
                    actionButton("Close", icon: "xmark.circle.fill", color: .gray) {
                        onDismiss()
                    }
                }
            }
            .padding(8)
        }
        .onAppear {
            loadDecisionAndChoices()
        }
        .onChange(of: selectedNodeID) { _, _ in
            loadDecisionAndChoices()
        }
    }
    
    // MARK: - Choices Section
    
    @ViewBuilder
    private func choicesSection(decision: DecisionNode) -> some View {
        VStack(spacing: 6) {
            Text(decision.inputType == .multiChoice ? "Select all that apply:" : "Choose one:")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(choices, id: \.id) { choice in
                choiceButton(choice: choice, decision: decision)
            }
        }
    }
    
    @ViewBuilder
    private func choiceButton(choice: ChoiceNode, decision: DecisionNode) -> some View {
        Button {
            Task {
                await selectChoice(choice.id, in: decision.id)
            }
        } label: {
            HStack {
                Image(systemName: choice.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(choice.isSelected ? .green : .gray)
                Text(choice.choiceText)
                    .font(.body)
                Spacer()
            }
            .padding(10)
            .background(choice.isSelected ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Numeric Section
    
    @ViewBuilder
    private func numericSection(decision: DecisionNode) -> some View {
        Button {
            showNumericInput = true
        } label: {
            Text("\(Int(decision.numericValue ?? 0))")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showNumericInput) {
            NumericInputSheet(value: $numericValue, decision: decision, viewModel: viewModel) {
                loadDecisionAndChoices()
            }
        }
        .onChange(of: showNumericInput) { _, isShowing in
            if !isShowing {
                // Sheet was dismissed - reload to get updated values
                loadDecisionAndChoices()
            }
        }
    }
    
    // MARK: - Navigation Section
    
    @ViewBuilder
    private func navigationSection(decision: DecisionNode) -> some View {
        let nextDecision = viewModel.model.getNextDecision(after: decision.id)
        
        VStack(spacing: 8) {
            Text("Navigation")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let next = nextDecision {
                actionButton("Next Question", icon: "arrow.right.circle.fill", color: .blue) {
                    selectedNodeID = next.id
                }
            } else {
                VStack(spacing: 8) {
                    Text("✓ Decision tree complete")
                        .font(.caption)
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                    
                    actionButton("Generate Preferences", icon: "checkmark.circle.fill", color: .green) {
                        Task {
                            await generatePreferences()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    @ViewBuilder
    private func progressIndicator(for decision: DecisionNode) -> some View {
        let rootDecision = findRootDecision(from: decision.id)
        let (answered, total) = countDecisions(from: rootDecision?.id ?? decision.id)
        
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "list.number")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text("\(answered) of \(total) answered")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            ProgressView(value: Double(answered), total: Double(total))
                .tint(.blue)
                .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 8)
    }
    
    /// Counts total decisions and answered decisions in the tree starting from a root decision
    private func countDecisions(from rootID: NodeID) -> (answered: Int, total: Int) {
        var currentID: NodeID? = rootID
        var visited: Set<NodeID> = []
        var totalCount = 0
        var answeredCount = 0
        
        while let decisionID = currentID, !visited.contains(decisionID) {
            visited.insert(decisionID)
            
            guard let node = viewModel.model.nodes.first(where: { $0.id == decisionID }),
                  let decision = node.unwrapped as? DecisionNode else {
                break
            }
            
            totalCount += 1
            if isAnswered(decision) {
                answeredCount += 1
            }
            
            // Move to next decision via precedes edge
            currentID = viewModel.model.getNextDecision(after: decisionID)?.id
        }
        
        return (answeredCount, totalCount)
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
    
    // MARK: - Data Loading
    
    private func loadDecisionAndChoices() {
        guard let nodeID = selectedNodeID,
              let node = viewModel.model.nodes.first(where: { $0.id == nodeID }),
              let decision = node.unwrapped as? DecisionNode else {
            return
        }
        
        decisionNode = decision
        numericValue = decision.numericValue ?? 0
        
        // Load child choices via hierarchy edges
        let choiceIDs = viewModel.model.edges
            .filter { $0.from == nodeID && $0.type == .hierarchy }
            .map { $0.target }
        
        choices = choiceIDs.compactMap { childID in
            viewModel.model.nodes.first(where: { $0.id == childID })?.unwrapped as? ChoiceNode
        }
    }
    
    // MARK: - Actions
    
    private func selectChoice(_ choiceID: NodeID, in decisionID: NodeID) async {
        _ = await viewModel.model.selectChoice(choiceID, in: decisionID)
        loadDecisionAndChoices()
        
        // Auto-advance for single choice if there's a next decision
        if let decision = decisionNode, decision.inputType == .singleChoice {
            if let nextDecision = viewModel.model.getNextDecision(after: decisionID) {
                // Small delay for visual feedback
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                selectedNodeID = nextDecision.id
            }
        }
    }
    
    private func isAnswered(_ decision: DecisionNode) -> Bool {
        switch decision.inputType {
        case .numeric:
            return decision.numericValue != nil
        case .singleChoice:
            return decision.selectedChoiceID != nil
        case .multiChoice:
            return !decision.selectedChoiceIDs.isEmpty
        }
    }
    
    // MARK: - Preference Generation
    
    /// Finds the root decision (first in the tree) by walking backwards through precedes edges
    private func findRootDecision(from currentID: NodeID) -> DecisionNode? {
        var current = currentID
        var visited: Set<NodeID> = []
        
        // Walk backwards until we find a decision with no incoming precedes edge
        while !visited.contains(current) {
            visited.insert(current)
            
            // Look for a precedes edge that points TO this decision
            if let incomingEdge = viewModel.model.edges.first(where: {
                $0.type == .precedes && $0.target == current
            }) {
                // Found a predecessor, keep going back
                current = incomingEdge.from
            } else {
                // No predecessor found - this is the root
                break
            }
        }
        
        // Get the decision node at this ID
        guard let node = viewModel.model.nodes.first(where: { $0.id == current }),
              let decision = node.unwrapped as? DecisionNode else {
            return nil
        }
        
        return decision
    }
    
    /// Generates a PreferenceNode from the completed decision tree
    private func generatePreferences() async {
        guard let currentDecisionID = selectedNodeID else { return }
        
        // Find the root decision
        guard let rootDecision = findRootDecision(from: currentDecisionID) else {
            return
        }
        
        // Collect all decision results
        let results = viewModel.model.collectDecisionResults(startingFrom: rootDecision.id)
        
        // Extract guest count (should be the first numeric decision)
        let guestCount = Int(rootDecision.numericValue ?? 6)
        
        // Generate preference name based on choices
        let name = generatePreferenceName(from: results)
        
        // Create PreferenceNode at a position near the decision tree
        let position = CGPoint(
            x: rootDecision.position.x,
            y: rootDecision.position.y + 150
        )
        
        let preference = await viewModel.model.generatePreference(
            from: rootDecision.id,
            name: name,
            guestCount: guestCount,
            dinnerTime: Date(),
            at: position
        )
        
        // Navigate to the new preference node
        selectedNodeID = preference.id
    }
    
    /// Generates a human-readable name for the preference based on choices
    private func generatePreferenceName(from preferences: [String: PreferenceValue]) -> String {
        var components: [String] = []
        
        // Add protein if available
        if case .string(let protein) = preferences["protein"] {
            components.append(protein.capitalized)
        }
        
        // Add "Tacos" as the base
        components.append("Tacos")
        
        // Add spice level if available
        if case .string(let spice) = preferences["spiceLevel"] {
            components.append("(\(spice))")
        }
        
        return components.joined(separator: " ")
    }
}

// MARK: - Numeric Input Sheet

@available(watchOS 10.0, *)
struct NumericInputSheet: View {
    @Binding var value: Double
    let decision: DecisionNode
    let viewModel: GraphViewModel
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var workingValue: Double
    
    init(value: Binding<Double>, decision: DecisionNode, viewModel: GraphViewModel, onSave: @escaping () -> Void) {
        self._value = value
        self.decision = decision
        self.viewModel = viewModel
        self.onSave = onSave
        let minValue = decision.preferenceKey == "guestCount" ? 1.0 : 0.0
        self._workingValue = State(initialValue: max(value.wrappedValue, minValue))
    }
    
    var minimumValue: Double {
        decision.preferenceKey == "guestCount" ? 1 : 0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(decision.question)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Stepper(value: $workingValue, in: minimumValue...1000, step: 1) {
                VStack(spacing: 4) {
                    Text("Value")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(Int(workingValue))")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            .padding()
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Save") {
                    Task {
                        value = workingValue
                        let success = await viewModel.model.setNumericValue(workingValue, for: decision.id)
                        if success {
                            onSave()
                        }
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
