//
//  EditContentSheet.swift
//  GraphEditor
//
//  Created by handcart on 9/19/25.
//

// EditContentSheet.swift

import SwiftUI
import GraphEditorShared

struct EditContentSheet: View {
    let selectedID: NodeID
    let viewModel: GraphViewModel
    let onSave: (NodeContent?) -> Void
    @State private var selectedType: String = "String"
    @State private var stringValue: String = ""
    @State private var dateValue: Date = Date()
    @State private var numberValue: Double = 0.0
    
    var body: some View {
        VStack {
            Picker("Type", selection: $selectedType) {
                Text("String").tag("String")
                Text("Date").tag("Date")
                Text("Number").tag("Number")
                Text("None").tag("None")
            }
            if selectedType == "String" {
                TextField("Enter text", text: $stringValue).frame(maxWidth: .infinity)
            } else if selectedType == "Date" {
                DatePicker("Select date", selection: $dateValue, displayedComponents: .date)
            } else if selectedType == "Number" {
                TextField("Enter number", value: $numberValue, format: .number)
            }
            Button("Save") {
                let newContent: NodeContent? = {
                    switch selectedType {
                    case "String": return stringValue.isEmpty ? nil : .string(stringValue)
                    case "Date": return .date(dateValue)
                    case "Number": return .number(numberValue)
                    default: return nil
                    }
                }()
                onSave(newContent)
            }
        }
        .onAppear {
            if let node = viewModel.model.nodes.first(where: { $0.id == selectedID }),
               let content = node.content {
                switch content {
                case .string(let str): selectedType = "String"; stringValue = str
                case .date(let date): selectedType = "Date"; dateValue = date
                case .number(let num): selectedType = "Number"; numberValue = num
                }
            }
        }
    }
}
