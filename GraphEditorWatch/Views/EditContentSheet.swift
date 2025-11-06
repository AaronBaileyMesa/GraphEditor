//
//  EditContentSheet.swift
//  GraphEditor
//
//  Created by handcart on 9/19/25.
//

import SwiftUI
import GraphEditorShared
@available(watchOS 10.0, *)

struct EditContentSheet: View {
    let selectedID: NodeID
    let viewModel: GraphViewModel
    let onSave: ([NodeContent]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var contents: [NodeContent] = []
    @State private var selectedType: DataType?
    @State private var selectedComponent: DateField?
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addPendingContent()  // Add any pending input before saving
                        onSave(contents)
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
            .focused($isSheetFocused)
            .environment(\.disableCanvasFocus, true)  // NEW: Disable canvas focus in this view and children
            .onAppear {
                isSheetFocused = true
                if let node = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
                    contents = node.contents
                }
            }
            .onChange(of: isSheetFocused) { _, newValue in
                print("Sheet focus changed to: \(newValue)")
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
                                editingIndex = index  // Enter edit mode on tap
                                proxy.scrollTo(index, anchor: .top)  // Scroll to edited item
                            }
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    contents.remove(at: index)
                                }
                            }
                    }
                }
            }
            
            if let type = selectedType {
                switch type {
                case .string:
                    TextField("Enter text", text: $stringValue)
                        .focused($isSheetFocused)
                        .onSubmit { addStringContent() }
                case .date:
                    GraphicalDatePicker(date: $dateValue)  // INTEGRATED: Custom picker for date input
                        .frame(height: 150)  // Match picker height
                        .onChange(of: dateValue) { _, _ in addDateContent() }  // Auto-add on change (optional)
                case .number:
                    NumericKeypadView(text: $numberString)
                        .focused($isSheetFocused)
                        .onSubmit { addNumberContent() }
                }
            }
        }
    }
    
    // UPDATED: Full implementation of inlineEditView with GraphicalDatePicker integration
    private func inlineEditView(for index: Int) -> some View {
        let binding = Binding<NodeContent>(
            get: { contents[index] },
            set: { contents[index] = $0 }
        )
        
        return Group {
            switch binding.wrappedValue {
            case .string(let str):
                TextField("Edit text", text: Binding(
                    get: { str },
                    set: { binding.wrappedValue = .string($0) }
                ))
                .focused($isSheetFocused)
            case .date(let dateVal):
                GraphicalDatePicker(date: Binding(  // INTEGRATED: Use custom picker for date editing
                    get: { dateVal },
                    set: { binding.wrappedValue = .date($0) }
                                                 ))
                .frame(height: 150)  // Ensure it fits in the list row
                .onChange(of: selectedComponent) { _, newComponent in
                    // Optional: Handle focus on specific date parts (e.g., jump to year/month/day)
                    if let component = newComponent {
                        print("Focusing on \(component.description)")
                        // Add logic to scroll/highlight in GraphicalDatePicker if extended
                    }
                }
            case .number(let num):
                TextField("Edit number", value: Binding<Double?>(  // FIXED: Use optional Double? for if-let in setter
                    get: { num },
                    set: { if let value = $0 { binding.wrappedValue = .number(value) } }
                                                                ), format: .number)
                .focused($isSheetFocused)
            case .boolean(let boolVal):
                Toggle("Edit boolean", isOn: Binding(
                    get: { boolVal },
                    set: { binding.wrappedValue = .boolean($0) }
                ))
            }
        }
        .onTapGesture {
            // Optional: Set selectedComponent for date if tapped (e.g., default to .day)
            if case .date = binding.wrappedValue {
                selectedComponent = .day
            }
        }
    }
    
    // FIXED: Define missing add*Content functions (append to contents and reset states)
    private func addStringContent() {
        if !stringValue.isEmpty {
            contents.append(.string(stringValue))
            stringValue = ""
        }
        selectedType = nil  // Reset selection
    }
    
    private func addDateContent() {
        contents.append(.date(dateValue))
        dateValue = Date()  // Reset to current date
        selectedType = nil
    }
    
    private func addNumberContent() {
        if let num = Double(numberString) {
            contents.append(.number(num))
            numberString = ""
        }
        selectedType = nil
    }
    
    // Helper: Display text for content (extracted for clarity)
    private func displayText(for content: NodeContent) -> String {
        switch content {
        case .string(let value): return value
        case .date(let value): return value.formatted(date: .abbreviated, time: .omitted)
        case .number(let value): return String(value)
        case .boolean(let value): return value ? "True" : "False"
        }
    }
    
    private func addPendingContent() {
        // Existing logic to add pending inputs (e.g., stringValue, dateValue, numberString)
        if let type = selectedType {
            switch type {
            case .string:
                if !stringValue.isEmpty {
                    contents.append(.string(stringValue))
                    stringValue = ""
                }
            case .date:
                contents.append(.date(dateValue))
            case .number:
                if let num = Double(numberString) {
                    contents.append(.number(num))
                    numberString = ""
                }
            }
            selectedType = nil  // Reset after adding
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
    case date
    case string
    case number
    
    var id: String { rawValue }
}

// MARK: - Enum for date fields (already present, but included for completeness)
enum DateField: Hashable {
    case year, month, day
    
    var description: String {  // NEW: Add this computed property
        switch self {
        case .year: return "year"
        case .month: return "month"
        case .day: return "day"
        }
    }
}
