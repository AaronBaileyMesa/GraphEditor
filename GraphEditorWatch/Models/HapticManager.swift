//
//  HapticManager.swift
//  GraphEditor
//
//  Manages haptic feedback for node interactions
//

import WatchKit
import GraphEditorShared

/// Manages haptic feedback for the graph editor
@available(watchOS 9.0, *)
public final class HapticManager {
    public static let shared = HapticManager()

    private init() {}

    /// Play haptic feedback for a given pattern
    public func play(_ pattern: HapticPattern?) {
        guard let pattern = pattern else { return }

        switch pattern {
        case .click:
            WKInterfaceDevice.current().play(.click)

        case .success:
            WKInterfaceDevice.current().play(.success)

        case .failure:
            WKInterfaceDevice.current().play(.failure)

        case .directionUp:
            WKInterfaceDevice.current().play(.directionUp)

        case .directionDown:
            WKInterfaceDevice.current().play(.directionDown)
        }
    }

    /// Play haptic for node tap
    public func playNodeTap(for node: any NodeProtocol) {
        play(node.typeDescriptor.haptics.tap)
    }

    /// Play haptic for long press
    public func playLongPress(for node: any NodeProtocol) {
        play(node.typeDescriptor.haptics.longPress)
    }

    /// Play haptic for drag start
    public func playDragStart(for node: any NodeProtocol) {
        play(node.typeDescriptor.haptics.drag)
    }

    /// Play haptic for drag end / drop
    public func playDragEnd(for node: any NodeProtocol) {
        play(node.typeDescriptor.haptics.drop)
    }

    /// Play haptic for state change
    public func playStateChange(for node: any NodeProtocol) {
        play(node.typeDescriptor.haptics.stateChange)
    }
}
