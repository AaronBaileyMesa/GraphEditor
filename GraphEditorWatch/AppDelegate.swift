//
//  AppDelegate.swift  // Optional rename for clarity
//  GraphEditorWatch
//
//  Created by handcart on 8/11/25.
//

import WatchKit
import Foundation

class AppDelegate: NSObject, WKApplicationDelegate {
    func didEnterBackground() {
        NotificationCenter.default.post(name: .graphSimulationPause, object: nil)
    }
    
    func willEnterForeground() {
        NotificationCenter.default.post(name: .graphSimulationResume, object: nil)
    }
}

// Define custom notifications (add to a shared file like AppConstants.swift if you prefer)
extension Notification.Name {
    static let graphSimulationPause = Notification.Name("GraphSimulationPause")
    static let graphSimulationResume = Notification.Name("GraphSimulationResume")
}
