//
//  MenuSectionView.swift
//  GraphEditorWatch
//
//  Reusable menu section component for node context menus
//

import SwiftUI
import GraphEditorShared

@available(iOS 16.0, watchOS 9.0, *)
struct MenuSectionView: View {
    let section: MenuSection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = section.title {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                MenuItemView(item: item)
            }
        }
        .padding(.vertical, 4)
    }
}

@available(iOS 16.0, watchOS 9.0, *)
struct MenuItemView: View {
    let item: MenuItem
    @State private var isSheetPresented = false

    var body: some View {
        switch item {
        case .text(let value):
            Text(value)
                .font(.body)
                .padding(.horizontal, 4)

        case .label(let key, let value):
            HStack {
                Text(key)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
            }
            .font(.body)
            .padding(.horizontal, 4)

        case .button(let title, let action):
            Button(action: action) {
                Text(title)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 4)

        case .buttonWithIcon(let title, let icon, let color, let action):
            Button(action: action) {
                Label(title, systemImage: icon)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
            .tint(color)
            .padding(.horizontal, 4)

        case .toggle(let title, let binding):
            Toggle(title, isOn: binding)
                .padding(.horizontal, 4)

        case .picker(let title, let selection, let options):
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .padding(.horizontal, 4)

        case .navigation(let title, let destination):
            NavigationLink {
                destination
            } label: {
                Text(title)
            }
            .padding(.horizontal, 4)

        case .sheet(let title, let icon, let content):
            Button {
                isSheetPresented = true
            } label: {
                if let icon = icon {
                    Label(title, systemImage: icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 4)
            .sheet(isPresented: $isSheetPresented) {
                content
            }

        case .divider:
            Divider()
                .padding(.vertical, 4)
        }
    }
}

#Preview("Menu Section Examples") {
    NavigationView {
        ScrollView {
            VStack(spacing: 20) {
                MenuSectionView(section: .info([
                    .text("Table: Dining Table"),
                    .text("8 seats"),
                    .text("4 occupied")
                ]))
                
                MenuSectionView(section: .actions([
                    .button("Edit Seating") { print("Edit") },
                    .button("Remove Table") { print("Remove") }
                ]))
                
                MenuSectionView(section: .properties([
                    .label("Type", "TableNode"),
                    .label("Mass", "30.0"),
                    .divider,
                    .toggle("Fixed Position", binding: .constant(true))
                ]))
            }
            .padding()
        }
        .navigationTitle("Menu Components")
    }
}
