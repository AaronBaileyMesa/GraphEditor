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
    
    // NEW: Computed Double binding for crown (months since reference)
    private var crownValue: Binding<Double> {
        Binding<Double>(
            get: { Calendar.current.dateComponents([.month], from: referenceDate, to: displayMonth).month.map(Double.init) ?? 0.0 },
            set: { newMonths in
                displayMonth = Calendar.current.date(byAdding: .month, value: Int(newMonths), to: referenceDate) ?? referenceDate
            }
        )
    }
    
    private let calendar = Calendar.current
    private let daysOfWeek = DateFormatter().shortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
    
    init(date: Binding<Date>) {
        _date = date
        _displayMonth = State(initialValue: date.wrappedValue)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let cellSize = geometry.size.width / 7  // Responsive grid
            VStack(spacing: 4) {
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
        }
        .frame(height: 150)
        .digitalCrownRotation(
            crownValue,
            from: -1200.0,  // ~100 years back (12*100)
            through: 1200.0,  // ~100 years forward
            sensitivity: .high,
            isContinuous: false,
            isHapticFeedbackEnabled: true,
            onChange: { event in
                updateFromCrown(event.offset)  // UPDATED: Pass event.offset (Double) from DigitalCrownEvent
            }
        )
    }
    
    private var minDate: Date { calendar.date(byAdding: .year, value: -100, to: Date()) ?? Date.distantPast }
    private var maxDate: Date { calendar.date(byAdding: .year, value: 100, to: Date()) ?? Date.distantFuture }
    
    private func header(cellSize: CGFloat) -> some View {
        HStack {
            Button(action: previousMonth) { Image(systemName: "chevron.left") }
            Text(monthYearString).font(.caption).frame(maxWidth: .infinity)
            Button(action: nextMonth) { Image(systemName: "chevron.right") }
        }
        .font(.caption2)
        .padding(.horizontal, 4)
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayMonth)
    }
    
    private func calendarGrid(cellSize: CGFloat) -> some View {
        let days = generateDays()
        return VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
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
        WKInterfaceDevice.current().play(.success)  // Haptic on select
    }
    
    private func previousMonth() { displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth }
    private func nextMonth() { displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth }
    
    private func updateFromCrown(_ value: Double) {
        let months = Int(value)
        displayMonth = calendar.date(byAdding: .month, value: months, to: referenceDate) ?? displayMonth
    }
    
    private func isSelected(_ dayDate: Date) -> Bool { calendar.isDate(dayDate, inSameDayAs: date) }
    private func isToday(_ dayDate: Date) -> Bool { calendar.isDateInToday(dayDate) }
    private func isCurrentMonth(_ dayDate: Date) -> Bool { calendar.isDate(dayDate, equalTo: displayMonth, toGranularity: .month) }
}
