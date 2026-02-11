//
//  EnvironmentKeys.swift
//  GraphEditor
//
//  Created by handcart on 11/4/25.
//

import SwiftUI
import os

private struct DisableCanvasFocusKey: EnvironmentKey {
    static let defaultValue: Bool = false  // Default: focus enabled
}

extension EnvironmentValues {
    var disableCanvasFocus: Bool {
        get { self[DisableCanvasFocusKey.self] }
        set { self[DisableCanvasFocusKey.self] = newValue }
    }
}

// MARK: - Logger Extensions

extension Logger {
    /// Logs debug message only if verbose debug logging is enabled
    func conditionalDebug(_ message: String) {
        if AppConstants.verboseDebugLogging {
            self.debug("\(message)")
        }
    }

    /// Logs info message only if verbose debug logging is enabled
    func conditionalInfo(_ message: String) {
        if AppConstants.verboseDebugLogging {
            self.info("\(message)")
        }
    }
}
