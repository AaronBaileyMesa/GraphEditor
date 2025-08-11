//
//  ExtensionDelegate.swift
//  GraphEditor
//
//  Created by handcart on 8/11/25.
//


// ExtensionDelegate.swift
import WatchKit
import Foundation

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    func applicationDidEnterBackground() {
        NotificationCenter.default.post(name: .graphSimulationPause, object: nil)
    }
    
    func applicationWillEnterForeground() {
        NotificationCenter.default.post(name: .graphSimulationResume, object: nil)
    }
}

// Define custom notifications (add to a shared file like AppConstants.swift if you prefer)
extension Notification.Name {
    static let graphSimulationPause = Notification.Name("GraphSimulationPause")
    static let graphSimulationResume = Notification.Name("GraphSimulationResume")
}