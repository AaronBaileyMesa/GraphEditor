//
//  EnvironmentKeys.swift
//  GraphEditor
//
//  Created by handcart on 11/4/25.
//

import SwiftUI

private struct DisableCanvasFocusKey: EnvironmentKey {
    static let defaultValue: Bool = false  // Default: focus enabled
}

extension EnvironmentValues {
    var disableCanvasFocus: Bool {
        get { self[DisableCanvasFocusKey.self] }
        set { self[DisableCanvasFocusKey.self] = newValue }
    }
}
