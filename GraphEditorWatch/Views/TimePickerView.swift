//
//  TimePickerView.swift
//  GraphEditor
//
//  Simple time picker for meal planning with hour/minute selection
//

import SwiftUI

@available(watchOS 10.0, *)
struct TimePickerView: View {
    @Binding var time: Date
    @Environment(\.dismiss) private var dismiss

    @State private var selectedHour: Int
    @State private var selectedMinute: Int

    init(time: Binding<Date>) {
        self._time = time
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time.wrappedValue)
        self._selectedHour = State(initialValue: components.hour ?? 18)
        self._selectedMinute = State(initialValue: components.minute ?? 0)
    }

    var body: some View {
        List {
            Section {
                // Hour picker
                Picker("Hour", selection: $selectedHour) {
                    ForEach(0..<24) { hour in
                        Text("\(hour)").tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 100)

                // Minute picker (15-minute increments)
                Picker("Minute", selection: $selectedMinute) {
                    ForEach([0, 15, 30, 45], id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 80)
            }

            Section {
                // Preview
                Text(timeString)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Section {
                Button("Set Time") {
                    updateTime()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Dinner Time")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let calendar = Calendar.current
        if let date = calendar.date(bySettingHour: selectedHour, minute: selectedMinute, second: 0, of: Date()) {
            return formatter.string(from: date)
        }
        return ""
    }

    private func updateTime() {
        let calendar = Calendar.current
        if let newTime = calendar.date(bySettingHour: selectedHour, minute: selectedMinute, second: 0, of: time) {
            time = newTime
        }
    }
}
