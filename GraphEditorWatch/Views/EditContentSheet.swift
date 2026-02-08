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
    @Environment(\.scenePhase) private var scenePhase
    @State private var contents: [NodeContent] = []
    @State private var selectedType: DataType?
    @State private var selectedComponent: DateField?
    @State private var stringValue: String = ""
    @State private var dateValue: Date = Date()
    @State private var numberString: String = ""  // Changed to string for custom input
    @State private var editingIndex: Int?  // NEW: Track item being edited inline
    @State private var dateChanged: Bool = false  // NEW: Track if date was modified
    @State private var hasNavigated: Bool = false  // Track if we've navigated away
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    contentsSection(proxy: proxy)
                }
                .navigationTitle("Contents")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .onChange(of: dateValue) { _, _ in
                dateChanged = true
            }
            .onChange(of: selectedType) { oldValue, newValue in
                print("📋 Type changed from \(String(describing: oldValue)) to \(String(describing: newValue))")
                addPendingContent(for: oldValue)
            }
            .onAppear {
                print("📋 EditContentSheet appeared for node: \(selectedID)")
                if let node = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
                    contents = node.contents
                    print("📋 Loaded \(contents.count) contents")
                    Task { await viewModel.model.snapshot() }
                } else {
                    print("⚠️ Node not found!")
                }
            }
            .onDisappear {
                // Only save if we haven't navigated to a child view
                if !hasNavigated {
                    print("📋 EditContentSheet disappearing - saving \(contents.count) contents")
                    addPendingContent(for: selectedType)
                    onSave(contents)
                } else {
                    print("📋 EditContentSheet temporarily hidden (navigation)")
                    hasNavigated = false  // Reset for when we come back
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        print("📋 Save button tapped")
                        addPendingContent(for: selectedType)
                        onSave(contents)
                        dismiss()
                    }
                }
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
            NavigationLink {
                SimpleCrownNumberInput(value: Binding(
                    get: { Double(numberString) ?? 0.0 },
                    set: { newValue in
                        numberString = String(format: "%.2f", newValue)
                        print("📋 Number updated to: \(numberString)")
                    }
                ))
                .onAppear {
                    hasNavigated = true
                }
            } label: {
                HStack {
                    Text("Enter number")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(numberString.isEmpty ? "0.00" : numberString)
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func inlineEditView(for index: Int) -> some View {
        switch contents[index] {
        case .string:
            return AnyView(stringEditView(for: index))
        case .date:
            return AnyView(dateEditView(for: index))
        case .number:
            return AnyView(numberEditView(for: index))
        case .boolean:
            return AnyView(booleanEditView(for: index))
        }
    }
    
    @ViewBuilder
    private func stringEditView(for index: Int) -> some View {
        if case .string(var value) = contents[index] {
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
        }
    }

    @ViewBuilder
    private func dateEditView(for index: Int) -> some View {
        if case .date(var value) = contents[index] {
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
        }
    }

    @ViewBuilder
    private func numberEditView(for index: Int) -> some View {
        if case .number(var value) = contents[index] {
            NavigationLink {
                SimpleCrownNumberInput(value: Binding(
                    get: { value },
                    set: { newValue in
                        contents[index] = .number(newValue)
                        value = newValue
                        editingIndex = nil  // Exit edit when done
                    }
                ))
                .onAppear {
                    hasNavigated = true
                }
            } label: {
                HStack {
                    Text("Edit number")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.2f", value))
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
    }

    @ViewBuilder
    private func booleanEditView(for index: Int) -> some View {
        if case .boolean(var value) = contents[index] {
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
