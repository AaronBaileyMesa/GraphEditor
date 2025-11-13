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
    @State private var dateChanged: Bool = false  // NEW: Track if date was modified
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                contentsSection(proxy: proxy)
            }
            .navigationTitle("Contents")  // Changed to "Contents" as requested
            .navigationBarTitleDisplayMode(.inline)
            .focused($isSheetFocused)
            .environment(\.disableCanvasFocus, true)  // NEW: Disable canvas focus in this view and children
            .onChange(of: dateValue) { _, _ in
                dateChanged = true  // NEW: Set flag on any change (no add here)
            }
            .onChange(of: selectedType) { oldValue, _ in
                addPendingContent(for: oldValue)  // NEW: Add pending for previous type on switch
            }
            .onChange(of: isSheetFocused) { _, newValue in
                print("Sheet focus changed to: \(newValue)")
            }
            .onAppear {
                isSheetFocused = true
                if let node = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
                    contents = node.contents  // Load existing contents
                    Task { await viewModel.model.snapshot() }  // Pre-edit snapshot for undo (async to match model API)
                }
            }
            .onDisappear {
                print("onDisappear triggered - saving contents: \(contents)")  // Debug log
                addPendingContent(for: selectedType)  // Handle unsaved for current type
                onSave(contents)
            }
        }
    }
    
    private func contentsSection(proxy: ScrollViewProxy) -> some View {
        Section(footer: DataTypeSegmentedControl(selectedType: $selectedType)) {
            if contents.isEmpty {
                Text("No contents yet")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                ForEach(contents.indices, id: \.self) { index in
                    contentRow(at: index, proxy: proxy)
                }
            }

            if let type = selectedType {
                inputField(for: type)
            }
        }
    }

    // MARK: - Row View
    @ViewBuilder
    private func contentRow(at index: Int, proxy: ScrollViewProxy) -> some View {
        if editingIndex == index {
            inlineEditView(for: index)
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        contents.remove(at: index)
                        editingIndex = nil
                    }
                }
        } else {
            Text(displayText(for: contents[index]))
                .font(.caption)
                .onTapGesture {
                    editingIndex = index
                    proxy.scrollTo(index, anchor: .top)
                }
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        contents.remove(at: index)
                    }
                }
        }
    }

    // MARK: - Input Field
    @ViewBuilder
    private func inputField(for type: DataType) -> some View {
        switch type {
        case .string:
            TextField("Enter text", text: $stringValue)
                .focused($isSheetFocused)
                .onSubmit { addStringContent() }
        case .date:
            GraphicalDatePicker(date: $dateValue)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.gray.opacity(0.1))
                )
                .fixedSize(horizontal: false, vertical: true)
        case .number:
            NumericKeypadView(text: $numberString)
                .focused($isSheetFocused)
                .onSubmit { addNumberContent() }
        }
    }
    
    // UPDATED: Full implementation of inlineEditView with all types
    @ViewBuilder
    private func inlineEditView(for index: Int) -> some View {
        switch contents[index] {
        case .string(var value):
            TextField("Edit text", text: Binding(
                get: { value },
                set: { newValue in
                    contents[index] = .string(newValue)
                    value = newValue
                }
            ))
            .onSubmit {
                editingIndex = nil  // Exit edit on submit
            }
        case .date(var value):
            GraphicalDatePicker(date: Binding(
                get: { value },
                set: { newValue in
                    contents[index] = .date(newValue)
                    value = newValue
                }
            ))
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.gray.opacity(0.1))
            )
            .fixedSize(horizontal: false, vertical: true)
        case .number(var value):
            NumericKeypadView(text: Binding(
                get: { String(format: "%.2f", value) },
                set: { newValue in
                    if let num = Double(newValue) {
                        contents[index] = .number(num)
                        value = num
                    }
                }
            ))
            .onSubmit {
                editingIndex = nil  // Exit edit on submit
            }
        case .boolean(var value):
            Toggle(isOn: Binding(
                get: { value },
                set: { newValue in
                    contents[index] = .boolean(newValue)
                    value = newValue
                }
            )) {
                Text(value ? "True" : "False")
            }
            .toggleStyle(.switch)
        }
    }
    
    private func addStringContent() {
        if !stringValue.isEmpty {
            contents.append(.string(stringValue))
            resetInputFields()
        }
    }
    
    private func addDateContent() {
        if dateChanged {
            contents.append(.date(dateValue))
            resetInputFields()
            dateChanged = false
        }
    }
    
    private func addNumberContent() {
        if let number = parseNumber() {
            contents.append(.number(number))
            resetInputFields()
        }
    }
    
    private func addPendingContent(for type: DataType?) {
        guard let type = type else { return }
        switch type {
        case .string: addStringContent()
        case .date: addDateContent()
        case .number: addNumberContent()
        }
    }
    
    private func displayText(for content: NodeContent) -> String {
        switch content {
        case .string(let value): return value
        case .date(let value): return dateFormatter.string(from: value)
        case .number(let value): return String(format: "%.2f", value)
        case .boolean(let value): return value ? "True" : "False"
        }
    }
    
    private func parseNumber() -> Double? {
        if let number = Double(numberString) {
            return number
        } else {
            return nil  // Or handle invalid input
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

// ... (rest of the file: NumericKeypadView, DataTypeSegmentedControl, DataType enum, DateField enum — unchanged)

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
