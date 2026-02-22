//
//  PreferenceNodeMenuView.swift
//  GraphEditorWatch
//
//  Menu view for PreferenceNode displaying collected preferences
//

import SwiftUI
import WatchKit
import GraphEditorShared

@available(watchOS 10.0, *)
struct PreferenceNodeMenuView: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void
    @Binding var selectedNodeID: NodeID?
    
    @State private var preferenceNode: PreferenceNode?
    @State private var showRawJSON: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let preference = preferenceNode {
                    // Header
                    Text(preference.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 4)
                    
                    // Summary Section
                    summarySection(preference: preference)
                    
                    // Toggle to show raw data
                    Toggle("Show Details", isOn: $showRawJSON)
                        .font(.caption)
                        .padding(.vertical, 4)
                    
                    if showRawJSON {
                        rawDataSection(preference: preference)
                    }
                    
                    // Actions Section
                    Text("Actions")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    
                    if let mealID = preference.mealNodeID {
                        actionButton("View Meal", icon: "fork.knife", color: .purple) {
                            selectedNodeID = mealID
                        }
                    }
                    
                    actionButton("Close", icon: "xmark.circle.fill", color: .gray) {
                        onDismiss()
                    }
                }
            }
            .padding(8)
        }
        .onAppear {
            loadPreference()
        }
    }
    
    // MARK: - Summary Section
    
    @ViewBuilder
    private func summarySection(preference: PreferenceNode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preferences")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 6) {
                preferenceRow(key: "Guests", value: "\(preference.guestCount)")
                
                preferenceRow(key: "Time", value: timeString(preference.dinnerTime))
                
                ForEach(Array(preference.preferences.keys.sorted()), id: \.self) { key in
                    if let value = preference.preferences[key] {
                        preferenceRow(key: key.capitalized, value: value.displayString)
                    }
                }
            }
            .padding(8)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(6)
        }
    }
    
    @ViewBuilder
    private func preferenceRow(key: String, value: String) -> some View {
        HStack {
            Text(key + ":")
                .font(.caption2)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
    
    // MARK: - Raw Data Section
    
    @ViewBuilder
    private func rawDataSection(preference: PreferenceNode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Raw Data")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("ID: \(preference.id.uuidString.prefix(8))...")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray)
                
                if let mealID = preference.mealNodeID {
                    Text("Meal: \(mealID.uuidString.prefix(8))...")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                if let recipeID = preference.baseRecipeID {
                    Text("Recipe: \(recipeID.uuidString.prefix(8))...")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                Text("Created: \(dateTimeString(preference.createdAt))")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
        }
    }
    
    // MARK: - Helper Functions
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func dateTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
    
    private func loadPreference() {
        guard let nodeID = selectedNodeID,
              let node = viewModel.model.nodes.first(where: { $0.id == nodeID }),
              let preference = node.unwrapped as? PreferenceNode else {
            return
        }
        
        preferenceNode = preference
    }
}
