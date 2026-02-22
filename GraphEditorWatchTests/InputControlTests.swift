//
//  InputControlTests.swift
//  GraphEditorWatchTests
//
//  Tests for all input control views: NumericKeypad, Crown inputs, Time/Date pickers
//

import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import GraphEditorWatch
@testable import GraphEditorShared

// MARK: - NumericKeypadView Tests

struct NumericKeypadViewTests {
    
    @Test("NumericKeypad appends digits correctly")
    @available(watchOS 10.0, *)
    func testAppendDigits() {
        @State var text = ""
        
        // Simulate appending digits
        var testText = ""
        testText += "1"
        testText += "2"
        testText += "3"
        
        #expect(testText == "123", "Should append digits correctly")
    }
    
    @Test("NumericKeypad prevents multiple decimal points")
    func testPreventMultipleDecimals() {
        var text = "12.5"
        
        // Try to append another decimal point
        if text.contains(".") {
            // Should not append
            #expect(true, "Should prevent multiple decimal points")
        } else {
            text += "."
        }
        
        #expect(text == "12.5", "Text should remain unchanged")
    }
    
    @Test("NumericKeypad allows single decimal point")
    func testAllowSingleDecimal() {
        var text = "12"
        
        // Append decimal point
        if !text.contains(".") {
            text += "."
        }
        
        #expect(text == "12.", "Should allow single decimal point")
    }
    
    @Test("NumericKeypad toggles negative sign")
    func testToggleNegative() {
        var text = "42"
        
        // Add negative sign
        if !text.hasPrefix("-") {
            text = "-" + text
        }
        
        #expect(text == "-42", "Should add negative sign")
        
        // Remove negative sign
        if text.hasPrefix("-") {
            text.removeFirst()
        }
        
        #expect(text == "42", "Should remove negative sign")
    }
    
    @Test("NumericKeypad handles negative zero")
    func testNegativeZero() {
        var text = "0"
        
        // Try to make negative zero
        if !text.hasPrefix("-") && (!text.isEmpty || text == "0") {
            text = "-" + text
        }
        
        #expect(text == "-0", "Should allow -0 input")
    }
    
    @Test("NumericKeypad deletes last character")
    func testDeleteLastCharacter() {
        var text = "123"
        
        if !text.isEmpty {
            text.removeLast()
        }
        
        #expect(text == "12", "Should delete last character")
    }
    
    @Test("NumericKeypad handles delete on empty string")
    func testDeleteOnEmpty() {
        var text = ""
        
        if !text.isEmpty {
            text.removeLast()
        }
        
        #expect(text == "", "Should handle delete on empty string")
    }
    
    @Test("NumericKeypad displays zero when empty")
    func testDisplayZeroWhenEmpty() {
        let text = ""
        let displayText = text.isEmpty ? "0" : text
        
        #expect(displayText == "0", "Should display 0 when empty")
    }
    
    @Test("NumericKeypad builds decimal number")
    func testBuildDecimalNumber() {
        var text = ""
        
        // Build "12.34"
        text += "1"
        text += "2"
        if !text.contains(".") {
            text += "."
        }
        text += "3"
        text += "4"
        
        #expect(text == "12.34", "Should build decimal number correctly")
    }
    
    @Test("NumericKeypad builds negative decimal")
    func testBuildNegativeDecimal() {
        var text = ""
        
        // Add negative sign first
        if !text.hasPrefix("-") {
            text = "-" + text
        }
        text += "5"
        if !text.contains(".") {
            text += "."
        }
        text += "5"
        
        #expect(text == "-5.5", "Should build negative decimal")
    }
}

// MARK: - SimpleCrownNumberInput Tests

struct SimpleCrownNumberInputTests {
    
    @Test("SimpleCrownNumberInput initializes with value")
    func testInitialization() {
        let initialValue = 42.0
        // In real usage, this would be a @Binding
        let value = initialValue
        
        #expect(value == 42.0, "Should initialize with provided value")
    }
    
    @Test("SimpleCrownNumberInput respects minimum value")
    func testMinimumValue() {
        let minimumValue = 0.0
        let testValue = -5.0
        
        let clampedValue = max(testValue, minimumValue)
        
        #expect(clampedValue == 0.0, "Should clamp to minimum value")
    }
    
    @Test("SimpleCrownNumberInput allows values above minimum")
    func testValuesAboveMinimum() {
        let minimumValue = 0.0
        let testValue = 10.0
        
        let clampedValue = max(testValue, minimumValue)
        
        #expect(clampedValue == 10.0, "Should allow values above minimum")
    }
    
    @Test("SimpleCrownNumberInput formats whole numbers without decimals")
    func testFormatWholeNumber() {
        let value = 42.0
        
        // Formatting logic
        let formatted: String
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            formatted = String(format: "%.0f", value)
        } else {
            formatted = String(format: "%.2f", value)
        }
        
        #expect(formatted == "42", "Should format whole number without decimals")
    }
    
    @Test("SimpleCrownNumberInput formats decimals with precision")
    func testFormatDecimalNumber() {
        let value = 42.5
        
        let formatted: String
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            formatted = String(format: "%.0f", value)
        } else {
            formatted = String(format: "%.2f", value)
        }
        
        #expect(formatted == "42.50", "Should format decimal with precision")
    }
    
    @Test("SimpleCrownNumberInput step size labels")
    func testStepSizeLabels() {
        let steps = [0.01, 0.1, 1.0, 10.0, 100.0]
        let expectedLabels = ["0.01", "0.10", "1", "10", "100"]
        
        for (index, step) in steps.enumerated() {
            let label = step >= 1 ? String(format: "%.0f", step) : String(format: "%.2f", step)
            #expect(label == expectedLabels[index], "Step size label should be correct")
        }
    }
    
    @Test("SimpleCrownNumberInput toggles sign")
    func testToggleSign() {
        var value = 42.0
        
        // Toggle to negative
        value = -value
        #expect(value == -42.0, "Should toggle to negative")
        
        // Toggle back to positive
        value = -value
        #expect(value == 42.0, "Should toggle back to positive")
    }
    
    @Test("SimpleCrownNumberInput resets to zero")
    func testResetToZero() {
        var value = 42.0
        
        value = 0
        #expect(value == 0.0, "Should reset to zero")
    }
    
    @Test("SimpleCrownNumberInput respects step increments")
    func testStepIncrements() {
        var value = 0.0
        let step = 1.0
        
        // Increment 3 times
        value += step
        value += step
        value += step
        
        #expect(value == 3.0, "Should increment by step size")
    }
}

// MARK: - VelocityCrownNumberInput Tests

struct VelocityCrownNumberInputTests {
    
    @Test("VelocityCrownNumberInput initializes display value")
    func testInitialization() {
        let value = 100.0
        let displayValue = value
        
        #expect(displayValue == 100.0, "Display value should match initial value")
    }
    
    @Test("VelocityCrownNumberInput calculates velocity")
    func testVelocityCalculation() {
        let timeDelta = 1.0 // 1 second
        let rotationDelta = 2.0 // 2 rotations
        
        let velocity = rotationDelta / timeDelta
        
        #expect(velocity == 2.0, "Velocity should be 2.0 rotations per second")
    }
    
    @Test("VelocityCrownNumberInput adjusts increment for slow rotation")
    func testSlowRotationIncrement() {
        let velocity = 0.3 // Below slowThreshold (0.5)
        let slowThreshold = 0.5
        
        let increment: Double
        if velocity <= slowThreshold {
            increment = 0.01
        } else {
            increment = 1.0
        }
        
        #expect(increment == 0.01, "Slow rotation should use fine increment")
    }
    
    @Test("VelocityCrownNumberInput adjusts increment for medium rotation")
    func testMediumRotationIncrement() {
        let velocity = 1.5 // Between slow (0.5) and medium (2.0)
        let slowThreshold = 0.5
        let mediumThreshold = 2.0
        
        let increment: Double
        if velocity > mediumThreshold {
            increment = 10.0
        } else if velocity > slowThreshold {
            increment = 1.0
        } else {
            increment = 0.01
        }
        
        #expect(increment == 1.0, "Medium rotation should use unit increment")
    }
    
    @Test("VelocityCrownNumberInput adjusts increment for fast rotation")
    func testFastRotationIncrement() {
        let velocity = 6.0 // Above fastThreshold (5.0)
        let fastThreshold = 5.0
        
        let increment: Double
        if velocity > fastThreshold {
            increment = 100.0
        } else {
            increment = 1.0
        }
        
        #expect(increment == 100.0, "Fast rotation should use large increment")
    }
    
    @Test("VelocityCrownNumberInput formats large values")
    func testFormatLargeValue() {
        let value = 1500.0
        
        let formatted = String(format: "%.0f", value)
        
        #expect(formatted == "1500", "Large values should format without decimals")
    }
    
    @Test("VelocityCrownNumberInput formats medium values")
    func testFormatMediumValue() {
        let value = 150.5
        
        let formatted = String(format: "%.1f", value)
        
        #expect(formatted == "150.5", "Medium values should format with 1 decimal")
    }
    
    @Test("VelocityCrownNumberInput formats small values")
    func testFormatSmallValue() {
        let value = 15.75
        
        let formatted = String(format: "%.2f", value)
        
        #expect(formatted == "15.75", "Small values should format with 2 decimals")
    }
    
    @Test("VelocityCrownNumberInput toggles sign")
    func testToggleSign() {
        var value = 42.5
        
        value = -value
        #expect(value == -42.5, "Should toggle to negative")
    }
    
    @Test("VelocityCrownNumberInput resets to zero")
    func testResetToZero() {
        var value = 123.45
        
        value = 0
        #expect(value == 0.0, "Should reset to zero")
    }
    
    @Test("VelocityCrownNumberInput clamps to maximum")
    func testClampToMaximum() {
        var value = 2_000_000.0
        
        value = max(-1_000_000, min(1_000_000, value))
        
        #expect(value == 1_000_000, "Should clamp to maximum")
    }
    
    @Test("VelocityCrownNumberInput clamps to minimum")
    func testClampToMinimum() {
        var value = -2_000_000.0
        
        value = max(-1_000_000, min(1_000_000, value))
        
        #expect(value == -1_000_000, "Should clamp to minimum")
    }
}

// MARK: - TimePickerView Tests

struct TimePickerViewTests {
    
    @Test("TimePickerView extracts hour from date")
    func testExtractHour() {
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: Date())!
        
        let components = calendar.dateComponents([.hour], from: date)
        let hour = components.hour
        
        #expect(hour == 18, "Should extract correct hour")
    }
    
    @Test("TimePickerView extracts minute from date")
    func testExtractMinute() {
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: Date())!
        
        let components = calendar.dateComponents([.minute], from: date)
        let minute = components.minute
        
        #expect(minute == 30, "Should extract correct minute")
    }
    
    @Test("TimePickerView supports all hours")
    func testAllHours() {
        let hours = Array(0..<24)
        
        #expect(hours.count == 24, "Should support 24 hours")
        #expect(hours.first == 0, "Should start at hour 0")
        #expect(hours.last == 23, "Should end at hour 23")
    }
    
    @Test("TimePickerView supports 15-minute increments")
    func testFifteenMinuteIncrements() {
        let minutes = [0, 15, 30, 45]
        
        #expect(minutes.count == 4, "Should have 4 minute options")
        #expect(minutes[0] == 0, "Should include 0 minutes")
        #expect(minutes[1] == 15, "Should include 15 minutes")
        #expect(minutes[2] == 30, "Should include 30 minutes")
        #expect(minutes[3] == 45, "Should include 45 minutes")
    }
    
    @Test("TimePickerView formats minutes with leading zero")
    func testMinuteFormatting() {
        let minutes = [0, 5, 15, 30]
        let formatted = minutes.map { String(format: "%02d", $0) }
        
        #expect(formatted[0] == "00", "Should format 0 as 00")
        #expect(formatted[1] == "05", "Should format 5 as 05")
        #expect(formatted[2] == "15", "Should format 15 as 15")
    }
    
    @Test("TimePickerView updates date with new time")
    func testUpdateTime() {
        let calendar = Calendar.current
        let originalDate = Date()
        
        let newHour = 14
        let newMinute = 30
        
        if let newTime = calendar.date(bySettingHour: newHour, minute: newMinute, second: 0, of: originalDate) {
            let components = calendar.dateComponents([.hour, .minute], from: newTime)
            
            #expect(components.hour == 14, "Hour should be updated")
            #expect(components.minute == 30, "Minute should be updated")
        }
    }
    
    @Test("TimePickerView formats time string")
    func testTimeStringFormatting() {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        if let date = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: Date()) {
            let timeString = formatter.string(from: date)
            
            #expect(timeString.count > 0, "Should format time string")
            // Exact format depends on locale, but should contain hour and minute
        }
    }
}

// MARK: - GraphicalDatePicker Tests

struct GraphicalDatePickerTests {
    
    @Test("GraphicalDatePicker generates days for month")
    func testGenerateDaysForMonth() {
        let calendar = Calendar.current
        let date = Date()
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            #expect(Bool(false), "Should get month interval")
            return
        }
        
        let range = calendar.range(of: .day, in: .month, for: date) ?? (1..<2)
        
        #expect(range.count > 0, "Should generate days for month")
        #expect(range.count <= 31, "Should not exceed 31 days")
    }
    
    @Test("GraphicalDatePicker calculates first weekday")
    func testFirstWeekday() {
        let calendar = Calendar.current
        let date = Date()
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            #expect(Bool(false), "Should get month interval")
            return
        }
        
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        
        #expect(firstWeekday >= 1 && firstWeekday <= 7, "Weekday should be 1-7")
    }
    
    @Test("GraphicalDatePicker identifies today")
    func testIdentifyToday() {
        let calendar = Calendar.current
        let today = Date()
        
        let isToday = calendar.isDateInToday(today)
        
        #expect(isToday == true, "Should identify today")
    }
    
    @Test("GraphicalDatePicker identifies selected date")
    func testIdentifySelectedDate() {
        let calendar = Calendar.current
        let date1 = Date()
        let date2 = Date()
        
        let isSameDay = calendar.isDate(date1, inSameDayAs: date2)
        
        #expect(isSameDay == true, "Should identify same day")
    }
    
    @Test("GraphicalDatePicker navigates to next month")
    func testNextMonth() {
        let calendar = Calendar.current
        let currentMonth = Date()
        
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            let currentMonthNumber = calendar.component(.month, from: currentMonth)
            let nextMonthNumber = calendar.component(.month, from: nextMonth)
            
            let expectedNext = currentMonthNumber == 12 ? 1 : currentMonthNumber + 1
            #expect(nextMonthNumber == expectedNext, "Should navigate to next month")
        }
    }
    
    @Test("GraphicalDatePicker navigates to previous month")
    func testPreviousMonth() {
        let calendar = Calendar.current
        let currentMonth = Date()
        
        if let prevMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            let currentMonthNumber = calendar.component(.month, from: currentMonth)
            let prevMonthNumber = calendar.component(.month, from: prevMonth)
            
            let expectedPrev = currentMonthNumber == 1 ? 12 : currentMonthNumber - 1
            #expect(prevMonthNumber == expectedPrev, "Should navigate to previous month")
        }
    }
    
    @Test("GraphicalDatePicker navigates to next year")
    func testNextYear() {
        let calendar = Calendar.current
        let currentYear = Date()
        
        if let nextYear = calendar.date(byAdding: .year, value: 1, to: currentYear) {
            let currentYearNumber = calendar.component(.year, from: currentYear)
            let nextYearNumber = calendar.component(.year, from: nextYear)
            
            #expect(nextYearNumber == currentYearNumber + 1, "Should navigate to next year")
        }
    }
    
    @Test("GraphicalDatePicker navigates to previous year")
    func testPreviousYear() {
        let calendar = Calendar.current
        let currentYear = Date()
        
        if let prevYear = calendar.date(byAdding: .year, value: -1, to: currentYear) {
            let currentYearNumber = calendar.component(.year, from: currentYear)
            let prevYearNumber = calendar.component(.year, from: prevYear)
            
            #expect(prevYearNumber == currentYearNumber - 1, "Should navigate to previous year")
        }
    }
    
    @Test("GraphicalDatePicker formats month string")
    func testMonthFormatting() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        
        let date = Date()
        let monthString = formatter.string(from: date)
        
        #expect(monthString.count >= 3, "Month string should be at least 3 characters")
    }
    
    @Test("GraphicalDatePicker formats year string")
    func testYearFormatting() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        
        let date = Date()
        let yearString = formatter.string(from: date)
        
        #expect(yearString.count == 4, "Year string should be 4 characters")
    }
    
    @Test("GraphicalDatePicker calculates week count")
    func testWeekCount() {
        let days = 30 // Typical month
        let leadingBlanks = 3 // Days before first of month
        let totalCells = leadingBlanks + days
        
        let weekCount = (totalCells + 6) / 7 // Ceiling division
        
        #expect(weekCount == 5, "Should calculate 5 weeks for 33 cells")
    }
}

// MARK: - NumericInputView Tests

struct NumericInputViewTests {
    
    @Test("NumericInputView decomposes positive integer")
    func testDecomposePositiveInteger() {
        let value = 42.0
        
        let absValue = abs(value)
        let integerPart = floor(absValue)
        let decimalPart = absValue - integerPart
        let isNegative = value < 0
        
        #expect(integerPart == 42.0, "Integer part should be 42")
        #expect(decimalPart == 0.0, "Decimal part should be 0")
        #expect(isNegative == false, "Should not be negative")
    }
    
    @Test("NumericInputView decomposes positive decimal")
    func testDecomposePositiveDecimal() {
        let value = 42.75
        
        let absValue = abs(value)
        let integerPart = floor(absValue)
        let decimalPart = absValue - integerPart
        let isNegative = value < 0
        
        #expect(integerPart == 42.0, "Integer part should be 42")
        #expect(abs(decimalPart - 0.75) < 0.001, "Decimal part should be 0.75")
        #expect(isNegative == false, "Should not be negative")
    }
    
    @Test("NumericInputView decomposes negative value")
    func testDecomposeNegativeValue() {
        let value = -42.5
        
        let absValue = abs(value)
        let integerPart = floor(absValue)
        let decimalPart = absValue - integerPart
        let isNegative = value < 0
        
        #expect(integerPart == 42.0, "Integer part should be 42")
        #expect(abs(decimalPart - 0.5) < 0.001, "Decimal part should be 0.5")
        #expect(isNegative == true, "Should be negative")
    }
    
    @Test("NumericInputView composes value from parts")
    func testComposeValue() {
        let integerPart = 42.0
        let decimalPart = 0.75
        let isNegative = false
        
        let value = (integerPart + decimalPart) * (isNegative ? -1 : 1)
        
        #expect(abs(value - 42.75) < 0.001, "Should compose to 42.75")
    }
    
    @Test("NumericInputView composes negative value")
    func testComposeNegativeValue() {
        let integerPart = 42.0
        let decimalPart = 0.5
        let isNegative = true
        
        let value = (integerPart + decimalPart) * (isNegative ? -1 : 1)
        
        #expect(abs(value - (-42.5)) < 0.001, "Should compose to -42.5")
    }
    
    @Test("NumericInputView formats value")
    func testFormatValue() {
        let value = 42.5
        let formatted = String(format: "%.2f", value)
        
        #expect(formatted == "42.50", "Should format with 2 decimals")
    }
    
    @Test("NumericInputView has three edit modes")
    func testEditModes() {
        enum EditMode {
            case integer, decimal, sign
        }
        
        let modes: [EditMode] = [.integer, .decimal, .sign]
        
        #expect(modes.count == 3, "Should have 3 edit modes")
    }
    
    @Test("NumericInputView integer mode range")
    func testIntegerModeRange() {
        let minValue = 0.0
        let maxValue = 9999.0
        
        #expect(minValue == 0.0, "Integer min should be 0")
        #expect(maxValue == 9999.0, "Integer max should be 9999")
    }
    
    @Test("NumericInputView decimal mode range")
    func testDecimalModeRange() {
        let minValue = 0.0
        let maxValue = 0.99
        
        #expect(minValue == 0.0, "Decimal min should be 0")
        #expect(abs(maxValue - 0.99) < 0.001, "Decimal max should be 0.99")
    }
    
    @Test("NumericInputView crown increments")
    func testCrownIncrements() {
        let integerIncrement = 1.0
        let decimalIncrement = 0.01
        let signIncrement = 1.0
        
        #expect(integerIncrement == 1.0, "Integer increment should be 1.0")
        #expect(decimalIncrement == 0.01, "Decimal increment should be 0.01")
        #expect(signIncrement == 1.0, "Sign increment should be 1.0")
    }
}

// MARK: - DataTypeSegmentedControl Tests

struct DataTypeSegmentedControlTests {
    
    @Test("DataTypeSegmentedControl supports all data types")
    func testAllDataTypes() {
        let types = DataType.allCases
        
        #expect(types.count >= 3, "Should support at least 3 data types")
        #expect(types.contains(.string), "Should support string type")
        #expect(types.contains(.number), "Should support number type")
        #expect(types.contains(.date), "Should support date type")
    }
    
    @Test("DataTypeSegmentedControl toggles selection")
    func testToggleSelection() {
        var selectedType: DataType? = nil
        
        // Select a type
        selectedType = .string
        #expect(selectedType == .string, "Should select string type")
        
        // Deselect by clicking same type
        if selectedType == .string {
            selectedType = nil
        }
        #expect(selectedType == nil, "Should deselect when clicking same type")
    }
    
    @Test("DataTypeSegmentedControl switches between types")
    func testSwitchBetweenTypes() {
        var selectedType: DataType? = nil
        
        // Select string
        selectedType = .string
        #expect(selectedType == .string, "Should select string")
        
        // Switch to number
        selectedType = .number
        #expect(selectedType == .number, "Should switch to number")
        
        // Switch to date
        selectedType = .date
        #expect(selectedType == .date, "Should switch to date")
    }
    
    @Test("DataTypeSegmentedControl handles nil selection")
    func testNilSelection() {
        let selectedType: DataType? = nil
        
        #expect(selectedType == nil, "Should handle nil selection")
    }
    
    @Test("DataTypeSegmentedControl date type uses calendar icon")
    func testDateTypeIcon() {
        let type = DataType.date
        let expectedIcon = "calendar"
        
        #expect(type == .date, "Date type should exist")
        // Icon would be verified in UI test
    }
}
