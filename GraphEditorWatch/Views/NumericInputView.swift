//
//  NumericInputView.swift
//  GraphEditor
//
//  Created with Claude on 2/7/26.
//

import SwiftUI
import WatchKit

@available(watchOS 10.0, *)
struct NumericInputView: View {
    @Binding var value: Double
    @State private var integerPart: Double = 0
    @State private var decimalPart: Double = 0
    @State private var isNegative: Bool = false
    @State private var editingMode: EditMode = .integer
    
    enum EditMode {
        case integer, decimal, sign
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Display current value
            displayValue()
            
            // Mode selector
            modeSelector()
            
            // Instructions
            instructionText()
        }
        .focusable(true)
        .digitalCrownRotation(
            crownBinding(),
            from: crownRange().min,
            through: crownRange().max,
            by: crownIncrement(),
            sensitivity: .medium,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .onAppear {
            decomposeValue()
        }
        .onChange(of: integerPart) { _, _ in updateValue() }
        .onChange(of: decimalPart) { _, _ in updateValue() }
        .onChange(of: isNegative) { _, _ in updateValue() }
    }
    
    // MARK: - Display
    
    private func displayValue() -> some View {
        Text(formatValue())
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(highlightColor())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func formatValue() -> String {
        let finalValue = (integerPart + decimalPart) * (isNegative ? -1 : 1)
        return String(format: "%.2f", finalValue)
    }
    
    private func highlightColor() -> Color {
        switch editingMode {
        case .integer: return .blue
        case .decimal: return .green
        case .sign: return .orange
        }
    }
    
    // MARK: - Mode Selector
    
    private func modeSelector() -> some View {
        HStack(spacing: 4) {
            modeButton("123", mode: .integer, icon: "number")
            modeButton(".00", mode: .decimal, icon: "smallcircle.filled.circle")
            modeButton("+/-", mode: .sign, icon: "plus.forwardslash.minus")
        }
    }
    
    private func modeButton(_ label: String, mode: EditMode, icon: String) -> some View {
        Button(action: {
            editingMode = mode
            WKInterfaceDevice.current().play(.click)
        }, label: {
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                Text(label)
                    .font(.system(size: 7, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(editingMode == mode ? Color.blue.opacity(0.3) : Color.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        })
        .buttonStyle(.plain)
    }
    
    // MARK: - Instructions
    
    private func instructionText() -> some View {
        Text(instructionMessage())
            .font(.system(size: 8))
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .lineLimit(2)
    }
    
    private func instructionMessage() -> String {
        switch editingMode {
        case .integer:
            return "Turn crown to adjust whole number"
        case .decimal:
            return "Turn crown to adjust decimal places"
        case .sign:
            return "Turn crown to toggle +/-"
        }
    }
    
    // MARK: - Digital Crown Configuration
    
    private func crownBinding() -> Binding<Double> {
        switch editingMode {
        case .integer:
            return $integerPart
        case .decimal:
            return $decimalPart
        case .sign:
            return Binding(
                get: { isNegative ? 1.0 : 0.0 },
                set: { isNegative = $0 >= 0.5 }
            )
        }
    }
    
    private func crownRange() -> (min: Double, max: Double) {
        switch editingMode {
        case .integer:
            return (0, 9999)
        case .decimal:
            return (0, 0.99)
        case .sign:
            return (0, 1)
        }
    }
    
    private func crownIncrement() -> Double {
        switch editingMode {
        case .integer:
            return 1.0
        case .decimal:
            return 0.01
        case .sign:
            return 1.0
        }
    }
    
    // MARK: - Value Management
    
    private func decomposeValue() {
        let absValue = abs(value)
        integerPart = floor(absValue)
        decimalPart = absValue - integerPart
        isNegative = value < 0
    }
    
    private func updateValue() {
        value = (integerPart + decimalPart) * (isNegative ? -1 : 1)
    }
}

// MARK: - Preview

#Preview("Numeric Input") {
    NumericInputView(value: .constant(42.50))
        .padding()
}
