//
//  DebugHierarchyModifier.swift
//  GraphEditorWatch
//
//  Improved for watchOS with logging and depth limit.
//

import SwiftUI
import os  // For Logger, matching your project
import Foundation

extension View {
    /// Applies a modifier that logs the view hierarchy recursively.
    func debugViewHierarchy(prefix: String = "", maxDepth: Int = 10) -> some View {
        modifier(DebugHierarchyModifier(prefix: prefix, maxDepth: maxDepth))
    }
}

struct DebugHierarchyModifier: ViewModifier {
    let prefix: String
    let maxDepth: Int
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "viewhierarchy")
    
    init(prefix: String, maxDepth: Int) {
            self.prefix = prefix
            self.maxDepth = maxDepth
            print("Debug modifier initialized")  // Simplified for clarity
            Self.logger.debug("DebugHierarchyModifier initialized with prefix: \(prefix)")
        }
        
        func body(content: Content) -> some View {
            print("Entering modifier body – starting hierarchy collection")  // NEW: Confirm entry
            Self.logger.debug("Debug modifier body applied")
            var hierarchyLines: [String] = []
            logHierarchy(of: content, prefix: prefix, depth: 0, lines: &hierarchyLines)
            exportToFile(lines: hierarchyLines)
            print("Exiting modifier body – export attempted")  // NEW: Confirm completion
            return content
        }
    
    // UPDATED: Add `lines` inout param for collection; append instead of print/log
    private func logHierarchy(of view: any View, prefix: String, depth: Int, lines: inout [String]) {
        if depth > maxDepth {
            print("WARNING: Max depth reached: \(depth)")  // Keep
            Self.logger.warning("Max depth reached: \(depth) – stopping recursion")
            lines.append("WARNING: Max depth reached: \(depth)")  // NEW: Append to file too
            return
        }
        
        let typeDesc = String(describing: type(of: view))
        print("\(prefix)\(typeDesc)")  // Keep console print
        lines.append("\(prefix)\(typeDesc)")  // NEW: Collect for file
        
        Self.logger.debug("\(prefix)\(String(describing: type(of: view)))")
        
        let mirror = Mirror(reflecting: view)
        var currentMirror: Mirror? = mirror
        
        while let mirror = currentMirror {
            // Body (computed, but check if accessible)
            if let body = mirror.descendant("body") as? any View {
                logHierarchy(of: body, prefix: prefix + "  | ", depth: depth + 1, lines: &lines)
            }
            
            // Content for modifiers like ModifiedContent
            if let content = mirror.descendant("content") as? any View {
                logHierarchy(of: content, prefix: prefix + "  > ", depth: depth + 1, lines: &lines)
            }
            
            // Tree for _VariadicView_Tree
            if let tree = mirror.descendant("tree") as? any View {
                logHierarchy(of: tree, prefix: prefix + "  | ", depth: depth + 1, lines: &lines)
            }
            
            // Value for TupleView/Group
            if let value = mirror.descendant("value") {
                let valueMirror = Mirror(reflecting: value)
                for child in valueMirror.children {
                    if let childView = child.value as? any View {
                        logHierarchy(of: childView, prefix: prefix + "  - ", depth: depth + 1, lines: &lines)
                    }
                }
            }
            
            // Children arrays
            if let children = mirror.descendant("children") as? [any View] {
                for child in children {
                    logHierarchy(of: child, prefix: prefix + "  - ", depth: depth + 1, lines: &lines)
                }
            }
            
            // Fallback for storage or other properties
            if let storage = mirror.descendant("storage") as? any View {
                logHierarchy(of: storage, prefix: prefix + "  * ", depth: depth + 1, lines: &lines)
            }
            
            currentMirror = mirror.superclassMirror
        }
    }
    
    // NEW: Helper to write collected lines to file
    private func exportToFile(lines: [String]) {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            Self.logger.error("Failed to get documents directory")
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileURL = documentsURL.appendingPathComponent("viewHierarchy-\(timestamp).txt")
        
        let content = lines.joined(separator: "\n")
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Exported hierarchy to: \(fileURL.path)")  // Console confirmation
            Self.logger.debug("Exported hierarchy to \(fileURL.path)")
        } catch {
            Self.logger.error("Failed to write hierarchy file: \(error.localizedDescription)")
        }
    }
}
