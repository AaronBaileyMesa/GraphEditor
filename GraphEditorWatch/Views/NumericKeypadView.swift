//
//  NumericKeypadView.swift
//  GraphEditor
//
//  Created by handcart on 11/19/25.
//

import SwiftUI
import GraphEditorShared
@available(watchOS 10.0, *)

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
