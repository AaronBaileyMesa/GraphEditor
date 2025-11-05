//
//  UnifiedDatePicker.swift
//  GraphEditor
//
//  Created by handcart on 11/4/25.
//

import SwiftUI
import GraphEditorShared
@available(watchOS 10.0, *)

struct UnifiedDatePicker: View {
    @Binding var date: Date
    private let calendar = Calendar.current
    let initialComponent: DateComponent
    @State private var selectedComponent: DateComponent
    
    init(date: Binding<Date>, initialComponent: DateComponent = .month) {
        _date = date
        self.initialComponent = initialComponent
        _selectedComponent = State(initialValue: initialComponent)
    }
    
    enum DateComponent: String, CaseIterable {
        case year, month, day
    }
    
    var body: some View {
        TabView(selection: $selectedComponent) {  // Swipe or Crown to switch
            yearPicker.tag(DateComponent.year)
            monthPicker.tag(DateComponent.month)
            dayPicker.tag(DateComponent.day)
        }
        .tabViewStyle(.page)  // Enables swiping between components
        .frame(height: 100)  // Compact for watch
        .onChange(of: selectedComponent) { _ in
            WKInterfaceDevice.current().play(.click)  // Haptic feedback
        }
    }
    
    private var yearPicker: some View {
        Picker("Year", selection: Binding<Int>(
            get: { calendar.component(.year, from: date) },
            set: { newYear in updateDate(year: newYear) }
        )) {
            ForEach(1900...2100, id: \.self) { year in  // Reasonable range to reduce scrolling
                Text(String(year)).tag(year)
            }
        }
        .pickerStyle(.wheel)  // Crown-friendly
    }
    
    private var monthPicker: some View {
        Picker("Month", selection: Binding<Int>(
            get: { calendar.component(.month, from: date) },
            set: { newMonth in updateDate(month: newMonth) }
        )) {
            ForEach(1...12, id: \.self) { month in
                Text(DateFormatter().monthSymbols[month - 1]).tag(month)
            }
        }
        .pickerStyle(.wheel)
    }
    
    private var dayPicker: some View {
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 31
        return Picker("Day", selection: Binding<Int>(
            get: { calendar.component(.day, from: date) },
            set: { newDay in updateDate(day: newDay) }
        )) {
            ForEach(1...daysInMonth, id: \.self) { day in
                Text(String(day)).tag(day)
            }
        }
        .pickerStyle(.wheel)
    }
    
    private func updateDate(year: Int? = nil, month: Int? = nil, day: Int? = nil) {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        if let year = year { components.year = year }
        if let month = month { components.month = month }
        if let day = day { components.day = min(day, calendar.range(of: .day, in: .month, for: calendar.date(from: components)!)?.count ?? 31) }
        if let newDate = calendar.date(from: components) {
            date = newDate
        }
    }
}
