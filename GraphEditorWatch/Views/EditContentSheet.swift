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
    let onSave: ([NodeContent]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var contents: [NodeContent] = []
    @State private var selectedType: String = "String"
    @State private var stringValue: String = ""
    @State private var dateValue: Date = Date()
    @State private var numberValue: Double = 0.0
    @FocusState private var isSheetFocused: Bool
    @State private var editingIndex: Int?  // NEW: Track item being edited inline
    @State private var showAddSection: Bool = false  // NEW: Toggle add inputs visibility for compactness

    var body: some View {
        List {
            // Section 1: Prioritize contents list (editable, gesture-based)
            Section(header: Text("Contents").font(.subheadline)) {  // Compact header
                if contents.isEmpty {
                    Text("No contents yet").font(.caption).foregroundColor(.gray)  // Placeholder
                } else {
                    ForEach(contents.indices, id: \.self) { index in
                        if editingIndex == index {
                            // Inline edit mode (tap to enter)
                            inlineEditView(for: index)
                                .swipeActions {  // Moved inside ForEach, per row
                                    Button("Delete", role: .destructive) {
                                        contents.remove(at: index)  // Use captured index
                                        editingIndex = nil  // Reset if deleted while editing
                                    }
                                }
                        } else {
                            Text(displayText(for: contents[index]))
                                .font(.caption)  // Smaller font for compactness
                                .onTapGesture {
                                    editingIndex = index  // Tap to edit
                                }
                                .swipeActions {  // Moved inside ForEach, per row
                                    Button("Delete", role: .destructive) {
                                        contents.remove(at: index)  // Use captured index
                                    }
                                }
                        }
                    }
                    .onMove { indices, newOffset in
                        contents.move(fromOffsets: indices, toOffset: newOffset)  // Drag to reorder
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))  // Reduce padding for compactness

            // Section 2: Compact "Add New" (tappable to expand)
            Section {
                Button(action: { showAddSection.toggle() }) { 
                    Text(showAddSection ? "Hide Add" : "Add New...").font(.caption)
                }
                if showAddSection {
                    Picker("Type", selection: $selectedType) {
                        Text("String").tag("String")
                        Text("Date").tag("Date")
                        Text("Number").tag("Number")
                    }
                    .pickerStyle(.wheel)  // Changed to .wheel for watchOS compatibility (default on watchOS)
                    
                    if selectedType == "String" {
                        TextField("Enter text", text: $stringValue)
                    } else if selectedType == "Date" {
                        DatePicker("Date", selection: $dateValue, displayedComponents: .date)
                            .labelsHidden()  // Save space
                    } else if selectedType == "Number" {
                        TextField("Number", value: $numberValue, format: .number)
                    }
                    
                    Button("Add") {
                        if let newContent = createNewContent() {
                            contents.append(newContent)
                            resetInputFields()
                            showAddSection = false  // Auto-hide after add for compactness
                        }
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))  // Compact padding
        }
        .navigationTitle("Edit Contents")  // Keep for context
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {  // NEW: Use toolbar for Save/Cancel to free bottom space
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundColor(.red)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { onSave(contents); dismiss() }
            }
        }
        .focused($isSheetFocused)
        .onAppear {
            isSheetFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isSheetFocused = true }
            if let node = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
                contents = node.contents
            }
        }
        .onChange(of: isSheetFocused) { _, newValue in
            if !newValue { isSheetFocused = true }  // Auto-recover focus (helps prevent blur if focus-related)
        }
        .interactiveDismissDisabled(true)  // Prevent accidental swipe-back
    }
    
    // NEW: Inline edit view for an item (compact, type-specific)
    private func inlineEditView(for index: Int) -> some View {
        let content = contents[index]
        return Group {
            switch content {
            case .string(var str):
                TextField("Edit String", text: Binding(get: { str }, set: { str = $0; contents[index] = .string(str) }))
            case .date(var date):
                DatePicker("Edit Date", selection: Binding(get: { date }, set: { date = $0; contents[index] = .date(date) }), displayedComponents: .date)
                    .labelsHidden()
            case .number(var num):
                TextField("Edit Number", value: Binding(get: { num }, set: { num = $0; contents[index] = .number(num) }), format: .number)
            case .boolean(var bool):
                Toggle("Edit Boolean", isOn: Binding(get: { bool }, set: { bool = $0; contents[index] = .boolean(bool) }))
            }
            Button("Done") { editingIndex = nil }  // Exit edit mode
        }
    }
    
    // Helper to create new content (unchanged)
    private func createNewContent() -> NodeContent? {
        switch selectedType {
        case "String": return stringValue.isEmpty ? nil : .string(stringValue)
        case "Date": return .date(dateValue)
        case "Number": return .number(numberValue)
        default: return nil
        }
    }
    
    // Unchanged helpers: displayText, dateFormatter, resetInputFields
    private func displayText(for content: NodeContent) -> String {
        switch content {
        case .string(let str): return "String: \(str.prefix(20))"
        case .date(let date): return "Date: \(dateFormatter.string(from: date))"
        case .number(let num): return "Number: \(num)"
        case .boolean(let bool): return "Boolean: \(bool ? "True" : "False")"
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
