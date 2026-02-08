//
//  GraphicalDatePicker.swift
//  GraphEditor
//
//  Created by handcart on 11/4/25.
//

import SwiftUI
import GraphEditorShared
import WatchKit  // Added for screenBounds
@available(watchOS 10.0, *)

struct GraphicalDatePicker: View {
    @Binding var date: Date
    @State private var displayMonth: Date  // Keep as Date for display
    
    private let calendar = Calendar.current
    private let daysOfWeek = DateFormatter().veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]  // Single letters
    
    // NEW: Fixed cellSize based on device screen width (removes need for GeometryReader)
    private let cellSize: CGFloat = WKInterfaceDevice.current().screenBounds.width / 7.0
    
    init(date: Binding<Date>) {
        _date = date
        _displayMonth = State(initialValue: date.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            monthYearPicker()
            calendarGrid()
            actionButtons()
        }
        .gesture(DragGesture(minimumDistance: 30)  // Swipe to change months
            .onEnded { value in
                if value.translation.width < -50 { nextMonth() }
                if value.translation.width > 50 { previousMonth() }
            }
        )
    }
    
    // Height helpers
    private func weekdayHeight() -> CGFloat { cellSize * 0.35 }
    
    private var minDate: Date { calendar.date(byAdding: .year, value: -100, to: Date()) ?? Date.distantPast }
    private var maxDate: Date { calendar.date(byAdding: .year, value: 100, to: Date()) ?? Date.distantFuture }
    
    // Simplified month/year picker with steppers
    private func monthYearPicker() -> some View {
        HStack(spacing: 8) {
            // Month stepper
            HStack(spacing: 2) {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.caption2)
                        .padding(4)
                }
                .buttonStyle(.plain)
                
                Text(monthString)
                    .font(.system(size: 11, weight: .medium))
                    .frame(minWidth: 30)
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.2))
            .clipShape(Capsule())
            
            // Year stepper
            HStack(spacing: 2) {
                Button(action: previousYear) {
                    Image(systemName: "chevron.left")
                        .font(.caption2)
                        .padding(4)
                }
                .buttonStyle(.plain)
                
                Text(yearString)
                    .font(.system(size: 11, weight: .medium))
                    .frame(minWidth: 35)
                
                Button(action: nextYear) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.2))
            .clipShape(Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Select month and year: \(monthYearString)")
    }
    
    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: displayMonth)
    }
    
    private var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: displayMonth)
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayMonth)
    }
    
    private func calendarGrid() -> some View {
        let days = generateDays()
        let weekCount = numberOfWeeks(for: days)
        
        return VStack(spacing: 1) {  // Minimal spacing
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(Array(daysOfWeek.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .frame(width: cellSize, height: weekdayHeight())
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            // Date cells - only show needed weeks
            ForEach(0..<weekCount, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(0..<7) { dayIndex in
                        let index = week * 7 + dayIndex
                        if index < days.count, let dayDate = days[index] {
                            Button(action: { selectDay(dayDate) }) {
                                Text("\(calendar.component(.day, from: dayDate))")
                                    .font(.system(size: max(10, 11 * 0.8)))
                                    .frame(width: cellSize, height: cellSize * 0.9)
                                    .background(isSelected(dayDate) ? Color.blue : (isToday(dayDate) ? Color.green.opacity(0.3) : Color.clear))
                                    .clipShape(Circle())
                                    .foregroundColor(isCurrentMonth(dayDate) ? .primary : .gray)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(calendar.component(.day, from: dayDate)) \(monthYearString)")
                        } else {
                            Color.clear.frame(width: cellSize, height: cellSize * 0.9)
                        }
                    }
                }
            }
        }
    }
    
    // Calculate number of weeks needed for current month
    private func numberOfWeeks(for days: [Date?]) -> Int {
        return (days.count + 6) / 7  // Ceiling division
    }
    
    private func generateDays() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayMonth) else { return [] }  // Bind the Optional here
        
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start) - 1  // Compute as non-Optional after guard
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)  // Leading blanks
        let range = calendar.range(of: .day, in: .month, for: displayMonth) ?? (1..<2)  // Use Range<Int> (1..<2)
        days += range.map { day in calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) }
        
        while days.count % 7 != 0 { days.append(nil) }  // Trailing blanks
        return days
    }
    
    private func selectDay(_ newDate: Date) {
        date = newDate
        WKInterfaceDevice.current().play(.click)  // Gentler haptic
    }
    
    // UPDATED: Added clamping to min/max
    private func previousMonth() {
        if let new = calendar.date(byAdding: .month, value: -1, to: displayMonth), new >= minDate {
            displayMonth = new
        }
    }
    private func nextMonth() {
        if let new = calendar.date(byAdding: .month, value: 1, to: displayMonth), new <= maxDate {
            displayMonth = new
        }
    }
    
    // NEW: Year navigation with clamping
    private func previousYear() {
        if let new = calendar.date(byAdding: .year, value: -1, to: displayMonth), new >= minDate {
            displayMonth = new
        }
    }
    private func nextYear() {
        if let new = calendar.date(byAdding: .year, value: 1, to: displayMonth), new <= maxDate {
            displayMonth = new
        }
    }
    
    private func isSelected(_ dayDate: Date) -> Bool { calendar.isDate(dayDate, inSameDayAs: date) }
    private func isToday(_ dayDate: Date) -> Bool { calendar.isDateInToday(dayDate) }
    private func isCurrentMonth(_ dayDate: Date) -> Bool { calendar.isDate(dayDate, equalTo: displayMonth, toGranularity: .month) }
    
    // MARK: - Action Buttons
    private func actionButtons() -> some View {
        HStack(spacing: 6) {
            Button(action: {
                let today = Date()
                date = today
                displayMonth = today
                WKInterfaceDevice.current().play(.success)
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 9))
                    Text("Today")
                        .font(.system(size: 9, weight: .medium))
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(Color.blue.opacity(0.3))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Jump to today")
            
            Button(action: {
                displayMonth = date
                WKInterfaceDevice.current().play(.click)
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 9))
                    Text("Selected")
                        .font(.system(size: 9, weight: .medium))
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(Color.gray.opacity(0.3))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Return to selected date")
        }
        .padding(.top, 1)
    }
}
