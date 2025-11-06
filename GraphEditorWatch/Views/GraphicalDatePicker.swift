//
//  GraphicalDatePicker.swift
//  GraphEditor
//
//  Created by handcart on 11/4/25.
//

import SwiftUI
import GraphEditorShared
@available(watchOS 10.0, *)

struct GraphicalDatePicker: View {
    @Binding var date: Date
    @State private var displayMonth: Date  // Keep as Date for display
    
    // NEW: Reference date for crown value (e.g., 1970-01-01)
    private let referenceDate = Date(timeIntervalSince1970: 0)
    
    // UPDATED: Computed Double binding for crown (months since reference), with clamping
    private var crownValue: Binding<Double> {
        Binding<Double>(
            get: { Calendar.current.dateComponents([.month], from: referenceDate, to: displayMonth).month.map(Double.init) ?? 0.0 },
            set: { newMonths in
                var newDate = Calendar.current.date(byAdding: .month, value: Int(newMonths), to: referenceDate) ?? referenceDate
                newDate = max(minDate, min(maxDate, newDate))  // Clamp to min/max
                displayMonth = newDate
            }
        )
    }
    
    private let calendar = Calendar.current
    private let daysOfWeek = DateFormatter().veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]  // Single letters
    
    init(date: Binding<Date>) {
        _date = date
        _displayMonth = State(initialValue: date.wrappedValue)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let cellSize = geometry.size.width / 7  // Responsive grid
            let weeks = numberOfWeeks  // NEW: Compute actual weeks for dynamic height
            let computedHeight = headerHeight(cellSize: cellSize) + weekdayHeight(cellSize: cellSize) + (CGFloat(weeks) * rowHeight(cellSize: cellSize)) + (CGFloat(weeks - 1) * 2)  // Dynamic calc with spacing
            ScrollView {  // NEW: Wrap for scrolling if too tall (e.g., 6 weeks)
                VStack(spacing: 2) {  // Reduced spacing for compactness
                    header(cellSize: cellSize)
                    calendarGrid(cellSize: cellSize)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(DragGesture(minimumDistance: 20)  // Swipe to change months
                    .onEnded { value in
                        if value.translation.width < -50 { nextMonth() }
                        if value.translation.width > 50 { previousMonth() }
                    }
                )
                .digitalCrownRotation(  // Attached to main VStack
                    crownValue,
                    from: monthsToMinDate,
                    through: monthsToMaxDate,
                    sensitivity: .high,
                    isContinuous: false,
                    isHapticFeedbackEnabled: false
                )
            }
            .frame(height: min(computedHeight, 180))  // NEW: Dynamic height, capped at 180 for watch constraints; scrolls if exceeded
            .scrollIndicators(.never)  // Hide indicators for clean look
            .scrollBounceBehavior(.basedOnSize)  // Minimal bounce
        }
    }
    
    // NEW: Helper to compute number of weeks (for dynamic height)
    private var numberOfWeeks: Int {
        let days = generateDays()
        return (days.count + 6) / 7  // Ceiling division for weeks
    }
    
    // NEW: Height helpers (estimates; adjust if needed based on testing)
    private func headerHeight(cellSize: CGFloat) -> CGFloat { cellSize / 2 }
    private func weekdayHeight(cellSize: CGFloat) -> CGFloat { cellSize / 2 }
    private func rowHeight(cellSize: CGFloat) -> CGFloat { cellSize }
    
    // UPDATED: Dynamic crown range (months from reference to min/max)
    private var monthsToMinDate: Double { Double(Calendar.current.dateComponents([.month], from: referenceDate, to: minDate).month ?? -1200) }
    private var monthsToMaxDate: Double { Double(Calendar.current.dateComponents([.month], from: referenceDate, to: maxDate).month ?? 1200) }
    
    private var minDate: Date { calendar.date(byAdding: .year, value: -100, to: Date()) ?? Date.distantPast }
    private var maxDate: Date { calendar.date(byAdding: .year, value: 100, to: Date()) ?? Date.distantFuture }
    
    // UPDATED: Arrows pushed to edges with Spacer, closer pairs (spacing:0), smaller font for text
    private func header(cellSize: CGFloat) -> some View {
        HStack(spacing: 0) {  // No overall spacing; use Spacer for edges
            HStack(spacing: 0) {  // Left pair close together
                Button(action: previousYear) {
                    Image(systemName: "chevron.left.2").padding(6)
                }
                .contentShape(Rectangle())
                .buttonStyle(PlainButtonStyle())
                
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left").padding(6)
                }
                .contentShape(Rectangle())
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()  // Push text to center
            
            Text(monthYearString)
                .font(.system(size: 10))  // Smaller font
                .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer()  // Push right pair to edge
            
            HStack(spacing: 0) {  // Right pair close together
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right").padding(6)
                }
                .contentShape(Rectangle())
                .buttonStyle(PlainButtonStyle())
                
                Button(action: nextYear) {
                    Image(systemName: "chevron.right.2").padding(6)
                }
                .contentShape(Rectangle())
                .buttonStyle(PlainButtonStyle())
            }
        }
        .font(.caption2)  // For arrows
        .padding(.horizontal, 2)
        .zIndex(1)
        //.focusSection()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Navigate months and years")
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"  // UPDATED: ISO format (e.g., "2025-12")
        return formatter.string(from: displayMonth)
    }
    
    private func calendarGrid(cellSize: CGFloat) -> some View {
        let days = generateDays()
        return VStack(spacing: 2) {  // Reduced spacing for compactness
            HStack(spacing: 0) {
                ForEach(Array(daysOfWeek.enumerated()), id: \.offset) { index, day in
                    Text(day).frame(width: cellSize, height: cellSize / 2).font(.caption2).foregroundColor(.gray)
                }
            }
            ForEach(0..<6) { week in  // Up to 6 weeks
                HStack(spacing: 0) {
                    ForEach(0..<7) { dayIndex in
                        let index = week * 7 + dayIndex
                        if index < days.count {  // Split: Check index first (non-optional Bool)
                            if let dayDate = days[index] {  // Now isolated optional binding
                                Button(action: { selectDay(dayDate) }) {
                                    Text("\(calendar.component(.day, from: dayDate))")
                                        .frame(width: cellSize, height: cellSize)
                                        .background(isSelected(dayDate) ? Color.blue : (isToday(dayDate) ? Color.green.opacity(0.3) : Color.clear))
                                        .clipShape(Circle())
                                        .foregroundColor(isCurrentMonth(dayDate) ? .primary : .gray)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(calendar.component(.day, from: dayDate)) \(monthYearString)")
                            } else {
                                Color.clear.frame(width: cellSize, height: cellSize)
                            }
                        } else {
                            Color.clear.frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
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
}
