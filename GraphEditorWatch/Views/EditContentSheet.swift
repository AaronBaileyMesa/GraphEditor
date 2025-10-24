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
    @State private var selectedType: DataType? = nil  // Changed to optional DataType
    @State private var stringValue: String = ""
    @State private var dateValue: Date = Date()
    @State private var numberString: String = ""  // Changed to string for custom input
    @FocusState private var isSheetFocused: Bool
    @State private var editingIndex: Int?  // NEW: Track item being edited inline

    var body: some View {
        ScrollViewReader { proxy in
            List {
                contentsSection(proxy: proxy)
            }
            .navigationTitle("Contents")  // Changed to "Contents" as requested
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {  // Use toolbar for Save/Cancel with icons
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }.foregroundColor(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        addPendingContent()  // Add any pending input before saving
                        onSave(contents)
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
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
                if !newValue { isSheetFocused = true }  // Auto-recover focus
            }
            .interactiveDismissDisabled(true)  // Prevent accidental swipe-back
        }
    }

    private func contentsSection(proxy: ScrollViewProxy) -> some View {
        Section(
            header: DataTypeSegmentedControl(selectedType: $selectedType)  // Replaced header with segmented control
        ) {
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
            
            if let type = selectedType {  // Show inputs only if a type is selected
                if type == .string {
                    TextField("Enter text", text: $stringValue)
                } else if type == .date {
                    DatePicker("Date", selection: $dateValue, displayedComponents: .date)
                        .labelsHidden()
                } else if type == .number {
                    NumericKeypadView(text: $numberString)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))  // Reduce padding for compactness
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
                let numString = Binding<String>(
                    get: { String(num) },
                    set: { if let newNum = Double($0) { contents[index] = .number(newNum) } }
                )
                NumericKeypadView(text: numString)
            case .boolean(var bool):
                Toggle("Edit Boolean", isOn: Binding(get: { bool }, set: { bool = $0; contents[index] = .boolean(bool) }))
            }
            Button("Done") { editingIndex = nil }  // Exit edit mode
        }
    }
    
    // NEW: Add any pending new content before saving
    private func addPendingContent() {
        if let type = selectedType, let newContent = createNewContent(for: type) {
            contents.append(newContent)
            resetInputFields()
            selectedType = nil  // Hide after adding (optional; can remove if you want to keep open)
        }
    }
    
    // Helper to create new content (updated for DataType)
    private func createNewContent(for type: DataType) -> NodeContent? {
        switch type {
        case .string: return stringValue.isEmpty ? nil : .string(stringValue)
        case .date: return .date(dateValue)
        case .number:
            if let num = Double(numberString) {
                return .number(num)
            } else {
                return nil  // Or handle invalid input
            }
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
        numberString = ""  // Reset string instead
    }
}

struct NumericKeypadView: View {
    @Binding var text: String
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        VStack(spacing: 2) {
            Text(text.isEmpty ? "0" : text)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
                .lineLimit(1)
                .truncationMode(.tail)
            
            LazyVGrid(columns: columns, spacing: 2) {
                keypadButton("7") { appendDigit("7") }
                keypadButton("8") { appendDigit("8") }
                keypadButton("9") { appendDigit("9") }
                keypadButton("4") { appendDigit("4") }
                keypadButton("5") { appendDigit("5") }
                keypadButton("6") { appendDigit("6") }
                keypadButton("1") { appendDigit("1") }
                keypadButton("2") { appendDigit("2") }
                keypadButton("3") { appendDigit("3") }
                keypadButton(".") { appendDigit(".") }
                keypadButton("0") { appendDigit("0") }
                keypadButton("-") { toggleNegative() }
            }
            
            keypadButton("⌫", background: Color.red.opacity(0.2)) {
                deleteLastCharacter()
            }
            .font(.system(size: 10))
        }
        .font(.system(size: 10))
    }
    
    private func keypadButton(_ label: String, background: Color = Color.gray.opacity(0.1), action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 20)
                .background(background)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
    
    private func appendDigit(_ digit: String) {
        if digit == "." && text.contains(".") { return }
        text += digit
    }
    
    private func toggleNegative() {
        if text.hasPrefix("-") {
            text.removeFirst()
        } else if !text.isEmpty || text == "0" {
            text = "-" + text
        }
    }
    
    private func deleteLastCharacter() {
        if !text.isEmpty {
            text.removeLast()
        }
    }
}

// MARK: - Custom Segmented Control for Data Types (watchOS-compatible version, with toggle behavior)
struct DataTypeSegmentedControl: View {
    @Binding var selectedType: DataType?
   
    var body: some View {
        HStack(spacing: 4) {  // Compact spacing for watchOS
            ForEach(DataType.allCases) { type in
                Button {
                    if selectedType == type {
                        selectedType = nil  // Deselect and hide inputs
                    } else {
                        selectedType = type  // Select and show inputs
                    }
                } label: {
                    Group {
                        if type == .date {
                            Image(systemName: "calendar")
                        } else if type == .string {
                            Text("A")
                        } else {
                            Text("123")
                        }
                    }
                    .font(.caption2)  // Small font for watchOS
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedType == type ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundColor(selectedType == type ? .white : .primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)  // Avoid default button styling
            }
        }
        .frame(maxWidth: .infinity)  // Stretch to fill available width
    }
}

// MARK: - Enum for the three options
enum DataType: String, CaseIterable, Identifiable {
    case date = "date"
    case string = "string"
    case number = "number"
   
    var id: String { rawValue }
}
