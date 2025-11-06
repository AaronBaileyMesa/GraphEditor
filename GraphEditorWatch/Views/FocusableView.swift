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
    @FocusState private var isFocused: Bool
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .id("CrownFocusableCanvas")
            .focused($isFocused)
            .onAppear {
                if !disableCanvasFocus {  // NEW: Only set if not disabled
                    isFocused = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused = true
                    }
                }
            }
            .onChange(of: isFocused) { oldValue, newValue in
                if disableCanvasFocus { return }  // NEW: Early exit if disabled
                #if DEBUG
                Self.logger.debug("Canvas focus changed: from \(oldValue) to \(newValue). Disable flag: \(disableCanvasFocus)")
                #endif
                if !newValue {
                    isFocused = true
                }
            }
    }
}
