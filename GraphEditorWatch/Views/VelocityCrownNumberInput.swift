//
//  VelocityCrownNumberInput.swift
//  GraphEditor
//
//  Velocity-based Digital Crown numeric input with automatic precision adjustment
//

import SwiftUI

@available(watchOS 10.0, *)
struct VelocityCrownNumberInput: View {
    @Binding var value: Double
    @State private var displayValue: Double = 0.0
    @State private var lastRotationTime: Date = Date()
    @State private var rotationVelocity: Double = 0.0
    @State private var currentIncrement: Double = 0.01
    @State private var accumulatedRotation: Double = 0.0
    
    // Velocity thresholds (rotations per second)
    private let slowThreshold: Double = 0.5
    private let mediumThreshold: Double = 2.0
    private let fastThreshold: Double = 5.0
    
    var body: some View {
        VStack(spacing: 8) {
            // Large number display
            Button(action: toggleSign) {
                Text(formattedValue)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.3))
                    )
            }
            .buttonStyle(.plain)
            
            // Increment indicator
            Text(incrementLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                )
        }
        .digitalCrownRotation(
            $accumulatedRotation,
            from: -Double.greatestFiniteMagnitude,
            through: Double.greatestFiniteMagnitude,
            by: 0.01,
            sensitivity: .medium,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .focusable(true)
        .onChange(of: accumulatedRotation) { oldValue, newValue in
            handleRotation(oldValue: oldValue, newValue: newValue)
        }
        .onAppear {
            displayValue = value
            print("🔢 VelocityCrownNumberInput appeared with value: \(value)")
        }
        .onDisappear {
            value = displayValue
            print("🔢 VelocityCrownNumberInput disappearing with value: \(displayValue)")
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { gesture in
                    if gesture.translation.height > 50 || gesture.translation.width > 50 {
                        resetToZero()
                    }
                }
        )
    }
    
    private var formattedValue: String {
        if abs(displayValue) >= 1000 {
            return String(format: "%.0f", displayValue)
        } else if abs(displayValue) >= 100 {
            return String(format: "%.1f", displayValue)
        } else {
            return String(format: "%.2f", displayValue)
        }
    }
    
    private var incrementLabel: String {
        if currentIncrement >= 100 {
            return "±\(Int(currentIncrement))"
        } else if currentIncrement >= 1 {
            return "±\(String(format: "%.0f", currentIncrement))"
        } else {
            return "±\(String(format: "%.2f", currentIncrement))"
        }
    }
    
    private func handleRotation(oldValue: Double, newValue: Double) {
        print("🔢 Crown rotation: \(oldValue) → \(newValue)")
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastRotationTime)
        let rotationDelta = abs(newValue - oldValue)
        
        // Calculate velocity (rotations per second)
        if timeDelta > 0 {
            rotationVelocity = rotationDelta / timeDelta
        }
        
        // Adjust increment based on velocity
        updateIncrement()
        
        // Apply the change
        let change = (newValue - oldValue) * currentIncrement / 0.01
        displayValue += change
        print("🔢 Display value updated to: \(displayValue) (increment: \(currentIncrement))")
        
        // Clamp to reasonable range
        displayValue = max(-1_000_000, min(1_000_000, displayValue))
        
        lastRotationTime = now
    }
    
    private func updateIncrement() {
        let newIncrement: Double
        
        if rotationVelocity > fastThreshold {
            // Fast rotation: large increments
            newIncrement = 100.0
        } else if rotationVelocity > mediumThreshold {
            // Medium rotation: moderate increments
            newIncrement = 10.0
        } else if rotationVelocity > slowThreshold {
            // Slow-medium rotation: unit increments
            newIncrement = 1.0
        } else {
            // Very slow rotation: fine increments
            newIncrement = 0.01
        }
        
        // Provide haptic feedback on increment changes
        if newIncrement != currentIncrement {
            WKInterfaceDevice.current().play(.click)
            currentIncrement = newIncrement
        }
    }
    
    private func toggleSign() {
        print("🔢 Toggling sign from \(displayValue) to \(-displayValue)")
        displayValue = -displayValue
        WKInterfaceDevice.current().play(.click)
    }
    
    private func resetToZero() {
        print("🔢 Resetting to zero")
        displayValue = 0
        WKInterfaceDevice.current().play(.success)
    }
}
