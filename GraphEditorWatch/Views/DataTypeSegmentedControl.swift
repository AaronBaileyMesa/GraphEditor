//
//  DataTypeSegmentedControl.swift
//  GraphEditor
//
//  Created by handcart on 11/19/25.
//

import SwiftUI
import GraphEditorShared
@available(watchOS 10.0, *)

// MARK: - Custom Segmented Control for Data Types (watchOS-compatible version, with toggle behavior)
struct DataTypeSegmentedControl: View {
    @Binding var selectedType: DataType?
    
    var body: some View {
        HStack(spacing: 4) {  // Compact spacing for watchOS
            ForEach(DataType.allCases) { type in
                Button {
                    if selectedType == type {
                        selectedType = nil  // Deselect and hide inputs
                    } else {
                        selectedType = type  // Select and show inputs
                    }
                } label: {
                    Group {
                        if type == .date {
                            Image(systemName: "calendar")
                        } else if type == .string {
                            Text("A")
                        } else {
                            Text("123")
                        }
                    }
                    .font(.caption2)  // Small font for watchOS
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedType == type ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundColor(selectedType == type ? .white : .primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)  // Avoid default button styling
            }
        }
        .frame(maxWidth: .infinity)  // Stretch to fill available width
    }
}
