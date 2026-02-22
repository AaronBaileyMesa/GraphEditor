//
//  MonogramGenerator.swift
//  GraphEditor
//
//  Helper for generating monogram images from names
//

import Foundation
import UIKit

/// Generates monogram images for person nodes
struct MonogramGenerator {
    
    /// Generate a monogram image from a name
    static func generateMonogram(from name: String) -> Data? {
        // Get initials
        let initials = getInitials(from: name)
        
        // Create a 100x100 image using Core Graphics
        let size = CGSize(width: 100, height: 100)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        // Choose a background color based on the name
        let backgroundColor = colorForName(name)
        context.setFillColor(backgroundColor.cgColor)
        
        // Fill circle
        let rect = CGRect(origin: .zero, size: size)
        context.fillEllipse(in: rect)
        
        // Flip the coordinate system for text drawing
        // Core Graphics has origin at bottom-left, UIKit expects top-left
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // Draw initials
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 40, weight: .medium),
            .foregroundColor: UIColor.white
        ]
        
        let attributedString = NSAttributedString(string: initials, attributes: attributes)
        let stringSize = attributedString.size()
        let stringRect = CGRect(
            x: (size.width - stringSize.width) / 2,
            y: (size.height - stringSize.height) / 2,
            width: stringSize.width,
            height: stringSize.height
        )
        
        // Save the graphics state
        UIGraphicsPushContext(context)
        attributedString.draw(in: stringRect)
        UIGraphicsPopContext()
        
        // Create image from context
        guard let cgImage = context.makeImage() else {
            return nil
        }
        
        let image = UIImage(cgImage: cgImage)
        return image.pngData()
    }
    
    // MARK: - Helper Methods
    
    /// Extract initials from a name
    private static func getInitials(from name: String) -> String {
        // Split the name into components
        let components = name.split(separator: " ").map(String.init)
        
        var initials = ""
        
        // Get first character of first word
        if let firstWord = components.first, let firstChar = firstWord.first {
            initials.append(firstChar)
        }
        
        // Get first character of last word (if different from first)
        if components.count > 1, let lastWord = components.last, let lastChar = lastWord.first {
            initials.append(lastChar)
        }
        
        // If we don't have any initials, use a default
        return initials.isEmpty ? "?" : initials.uppercased()
    }
    
    /// Generate a consistent color for a name
    private static func colorForName(_ name: String) -> UIColor {
        // Hash the name to get a consistent color
        let hash = abs(name.hashValue)
        
        // Use a palette of nice colors
        let colors: [UIColor] = [
            UIColor(red: 0.26, green: 0.54, blue: 0.98, alpha: 1.0), // Blue
            UIColor(red: 0.40, green: 0.71, blue: 0.38, alpha: 1.0), // Green
            UIColor(red: 0.93, green: 0.42, blue: 0.36, alpha: 1.0), // Red
            UIColor(red: 0.61, green: 0.35, blue: 0.71, alpha: 1.0), // Purple
            UIColor(red: 0.99, green: 0.59, blue: 0.20, alpha: 1.0), // Orange
            UIColor(red: 0.26, green: 0.63, blue: 0.70, alpha: 1.0), // Teal
            UIColor(red: 0.91, green: 0.30, blue: 0.58, alpha: 1.0), // Pink
            UIColor(red: 0.44, green: 0.50, blue: 0.56, alpha: 1.0)  // Gray
        ]
        
        return colors[hash % colors.count]
    }
}
