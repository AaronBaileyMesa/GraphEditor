//
//  FocusableView.swift
//  GraphEditor
//
//  Created by handcart on 10/14/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared
import os  // Added for logging

struct FocusableView<Content: View>: View {
    private static var logger: Logger {
        Logger(subsystem: "io.handcart.GraphEditor", category: "focusableview")  // Changed to computed static
    }
    
    let content: Content
    @Environment(\.disableCanvasFocus) private var disableCanvasFocus
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .id("GraphCanvasCrownTarget")
            .focusable(!disableCanvasFocus)  // Use legacy .focusable for watchOS crown compatibility; conditional
            .onAppear {
                #if DEBUG
                Self.logger.debug("FocusableView appeared. Disable flag: \(disableCanvasFocus)")
                #endif
            }
            // Removed .onChange forcing to avoid potential loops/termination; watchOS handles focus for crown
    }
}
