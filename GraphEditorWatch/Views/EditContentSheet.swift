//
//  EditContentSheet.swift
//  GraphEditor
//
//  Created by handcart on 9/19/25.
//

import SwiftUI
import GraphEditorShared

struct EditContentSheet: View {
    let selectedID: NodeID
    let viewModel: GraphViewModel
    let onSave: ([NodeContent]) -> Void  // Updated: Now saves an array
    @Environment(\.dismiss) private var dismiss  // NEW: For explicit dismiss
    @State private var contents: [NodeContent] = []  // State for the list
    @State private var selectedType: String = "String"  // For new item picker
    @State private var stringValue: String = ""
    @State private var dateValue: Date = Date()
    @State private var numberValue: Double = 0.0
    @FocusState private var isSheetFocused: Bool  // Focus state
    
    var body: some View {
        NavigationView {  // NEW: Wrap in NavigationView for watchOS stability
            VStack {
                // List for editing existing contents (reorderable, deletable)
                List {
                    ForEach(contents.indices, id: \.self) { index in
                        HStack {
                            Text(self.displayText(for: contents[index]))
                            Spacer()
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                contents.remove(at: index)
                            }
                        }
                    }
                    .onMove { indices, newOffset in
                        contents.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
                .frame(maxHeight: 200)  // Limit height for watchOS
                
                // Picker and input for adding new item
                Picker("Add Type", selection: $selectedType) {
                    Text("String").tag("String")
                    Text("Date").tag("Date")
                    Text("Number").tag("Number")
                }
                if selectedType == "String" {
                    TextField("Enter text", text: $stringValue).frame(maxWidth: .infinity)
                } else if selectedType == "Date" {
                    DatePicker("Select date", selection: $dateValue, displayedComponents: .date)
                } else if selectedType == "Number" {
                    TextField("Enter number", value: $numberValue, format: .number)
                }
                
                // Add button
                Button("Add") {
                    let newContent: NodeContent? = {
                        switch selectedType {
                        case "String": return stringValue.isEmpty ? nil : .string(stringValue)
                        case "Date": return .date(dateValue)
                        case "Number": return .number(numberValue)
                        default: return nil
                        }
                    }()
                    if let content = newContent {
                        contents.append(content)
                        resetInputFields()  // Clear inputs after adding
                    }
                }
                
                // Save and Cancel buttons
                HStack {
                    Button("Cancel") {
                        dismiss()  // Explicit dismiss
                    }
                    .foregroundColor(.red)
                    
                    Button("Save") {
                        onSave(contents)
                        dismiss()  // Dismiss after save
                    }
                }
            }
            .navigationTitle("Edit Contents")  // NEW: Title for NavigationView
            .navigationBarTitleDisplayMode(.inline)  // Compact for watchOS
            .focused($isSheetFocused)
            .onAppear {
                isSheetFocused = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {  // Slightly longer delay
                    isSheetFocused = true
                }
                print("EditContentSheet appeared")  // Debug
                // Load existing contents
                if let node = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
                    contents = node.contents
                }
            }
            .onChange(of: isSheetFocused) { oldValue, newValue in
                print("Sheet focus changed: \(newValue)")  // Debug
                if !newValue {
                    isSheetFocused = true  // Auto-recover
                }
            }
            .onDisappear {
                print("EditContentSheet disappeared")  // Debug why/when it dismisses
            }
        }
        .interactiveDismissDisabled(true)  // Prevent swipe dismiss
    }
    
    // Helper to display content in list
    private func displayText(for content: NodeContent) -> String {
        switch content {
        case .string(let str): return "String: \(str.prefix(20))"
        case .date(let date): return "Date: \(dateFormatter.string(from: date))"  // Fixed: Use string(from:)
        case .number(let num): return "Number: \(num)"
        case .boolean(let bool): return "Boolean: \(bool ? "True" : "False")"  // NEW: Handle boolean
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    private func resetInputFields() {
        stringValue = ""
        dateValue = Date()
        numberValue = 0.0
    }
}
