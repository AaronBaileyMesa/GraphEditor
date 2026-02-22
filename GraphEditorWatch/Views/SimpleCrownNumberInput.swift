//
//  SimpleCrownNumberInput.swift
//  GraphEditor
//
//  Simple numeric input using native watchOS patterns
//

import SwiftUI

@available(watchOS 10.0, *)
struct SimpleCrownNumberInput: View {
    @Binding var value: Double
    let minimumValue: Double
    @State private var workingValue: Double
    @State private var step: Double = 1.0
    @Environment(\.dismiss) private var dismiss
    
    init(value: Binding<Double>, minimumValue: Double = -.infinity) {
        self._value = value
        self.minimumValue = minimumValue
        self._workingValue = State(initialValue: max(value.wrappedValue, minimumValue))
    }
    
    var body: some View {
        List {
            Section {
                // Native stepper with value display
                Stepper(value: $workingValue, in: minimumValue...Double.greatestFiniteMagnitude, step: step) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Value")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(formattedValue)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            Section {
                HStack(spacing: 12) {
                    // Step Size
                    NavigationLink(destination: stepSizePicker) {
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 16))
                            Text(stepLabel)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    // Toggle Sign
                    Button(action: {
                        workingValue = -workingValue
                    }, label: {
                        VStack(spacing: 2) {
                            Image(systemName: "plus.forwardslash.minus")
                                .font(.system(size: 16))
                            Text("Sign")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    })
                    .buttonStyle(.bordered)
                    
                    // Reset
                    Button(action: {
                        workingValue = 0
                    }, label: {
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 16))
                            Text("Zero")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    })
                    .buttonStyle(.bordered)
                }
            }
            
            Section {
                Button("Done") {
                    value = max(workingValue, minimumValue)
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.blue)
            }
        }
        .navigationTitle("Number")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: value) { _, newValue in
            workingValue = newValue
            print("🔢 SimpleCrownNumberInput synced to new value: \(newValue)")
        }
    }
    
    private var stepSizePicker: some View {
        List {
            Picker("Step Size", selection: $step) {
                Text("0.01").tag(0.01)
                Text("0.1").tag(0.1)
                Text("1").tag(1.0)
                Text("10").tag(10.0)
                Text("100").tag(100.0)
            }
            .pickerStyle(.inline)
        }
        .navigationTitle("Step Size")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var stepLabel: String {
        if step >= 1 {
            return String(format: "%.0f", step)
        } else {
            return String(format: "%.2f", step)
        }
    }
    
    private var formattedValue: String {
        // Check if value is a whole number
        if workingValue.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", workingValue)
        }
        
        // Has decimals - show only necessary precision
        let absVal = abs(workingValue)
        if absVal >= 10 {
            return String(format: "%.2f", workingValue)
        } else if absVal >= 0.1 {
            return String(format: "%.3f", workingValue)
        } else if absVal >= 0.001 {
            return String(format: "%.5f", workingValue)
        } else {
            return String(format: "%.7f", workingValue)
        }
    }
}
