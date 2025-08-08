//
//  AppConstants.swift
//  GraphEditor
//
//  Created by handcart on 8/3/25.
//


import CoreGraphics

struct AppConstants {
    // Graph visuals
    static let nodeModelRadius: CGFloat = 10.0
    static let hitScreenRadius: CGFloat = 30.0
    static let tapThreshold: CGFloat = 10.0
    
    // Zooming
    static let numZoomLevels = 10
    static let defaultMinZoom: CGFloat = 0.2
    static let defaultMaxZoom: CGFloat = 5.0
}
