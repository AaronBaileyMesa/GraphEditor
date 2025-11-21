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

struct CrownPositionKey: EnvironmentKey {
    static let defaultValue: Binding<Double> = .constant(10)  // fallback only
}

extension EnvironmentValues {
    var crownPosition: Binding<Double> {
        get { self[CrownPositionKey.self] }
        set { self[CrownPositionKey.self] = newValue }
    }
}
