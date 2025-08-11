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
    @WKExtensionDelegateAdaptor(ExtensionDelegate.self) private var delegate: ExtensionDelegate  // Use adaptor here

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
