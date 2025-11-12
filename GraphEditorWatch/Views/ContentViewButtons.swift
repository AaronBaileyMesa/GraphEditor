//
//  ContentViewButtons.swift
//  GraphEditor
//
//  Created by handcart on 11/12/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared
import os

struct AddNodeButton: View {
    let viewModel: GraphViewModel  // Pass viewModel for addNode call
    private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "addnodebutton")

    var body: some View {
        Button(action: {
            WKInterfaceDevice.current().play(.click)
#if DEBUG
            logger.debug("Add Node button tapped!")
#endif
            let randomPos = CGPoint(x: CGFloat.random(in: -100...100), y: CGFloat.random(in: -100...100))
            Task { await viewModel.addNode(at: randomPos) }  // Use passed viewModel
        }, label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(.green)
        })
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .frame(minWidth: 44, minHeight: 44)
        .padding(10)
        .background(Color.blue.opacity(0.2))  // TEMP: Visualize tappable area; remove later
    }
}

struct MenuToggleButton: View {
    @Binding var showMenu: Bool
    private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "menutogglebutton")

    var body: some View {
        Button(action: {
            WKInterfaceDevice.current().play(.click)
#if DEBUG
            logger.debug("Menu button tapped!")
#endif
            showMenu.toggle()
        }, label: {
            Image(systemName: showMenu ? "point.3.filled.connected.trianglepath.dotted" : "line.3.horizontal")
                .font(.system(size: 30))
                .foregroundColor(showMenu ? .green : .blue)
        })
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .frame(minWidth: 44, minHeight: 44)
        .padding(10)
        .background(Color.red.opacity(0.2))  // TEMP: Visualize; different color for distinction
        .accessibilityLabel("Menu")
    }
}
