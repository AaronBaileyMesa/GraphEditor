//
//  MenuButton.swift
//  GraphEditorWatch
//
//  Created by handcart on 2025-10-23.
//

import SwiftUI
import WatchKit

struct MenuButton<LabelContent: View>: View {
    let action: () -> Void
    let label: () -> LabelContent
    let accessibilityIdentifier: String?
    let role: ButtonRole?
    
    init(
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> LabelContent,
        accessibilityIdentifier: String? = nil,
        role: ButtonRole? = nil
    ) {
        self.action = action
        self.label = label
        self.accessibilityIdentifier = accessibilityIdentifier
        self.role = role
    }
    
    var body: some View {
        Button(role: role) {
            WKInterfaceDevice.current().play(.click)
            action()
        } label: {
            label()
        }
        .font(.caption)
        .labelStyle(.titleAndIcon)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}
