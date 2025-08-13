//
//  GraphEditorWatch.swift
//  GraphEditorWatch Watch App
//
//  Created by handcart on 8/1/25.
//

import SwiftUI
import WatchKit

@main
struct GraphEditorWatch: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) private var delegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Force focus on the crown sequencer to resolve setup warnings
                    WKExtension.shared().visibleInterfaceController?.crownSequencer.focus()
                }
        }
    }
}
