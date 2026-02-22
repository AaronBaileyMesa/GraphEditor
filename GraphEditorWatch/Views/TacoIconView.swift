//
//  TacoIconView.swift
//  GraphEditor
//
//  Custom taco icon rendering for TacoNode
//

import SwiftUI
import GraphEditorShared

/// Renders a visual representation of a taco based on protein and shell type
struct TacoIconView: View {
    let protein: ProteinType?
    let shell: ShellType?
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Taco shell and filling
            if let shell = shell {
                // For soft corn tortillas, show double layer (street taco style)
                if shell == .softCorn {
                    // Upper-left tortilla layer (front) - centered
                    TacoShellShape(shellType: shell)
                        .fill(shellColor(for: shell))
                        .overlay(
                            TacoShellShape(shellType: shell)
                                .stroke(Color.black.opacity(0.25), lineWidth: 1.5)
                        )
                        .frame(width: size, height: size)
                        .background(
                            // Bottom-right tortilla layer (back) - offset
                            TacoShellShape(shellType: shell)
                                .fill(shellColor(for: shell))
                                .overlay(
                                    TacoShellShape(shellType: shell)
                                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                                )
                                .frame(width: size, height: size)
                                .offset(x: size * 0.08, y: size * 0.08)
                        )
                        .overlay(
                            // Protein filling on top
                            Group {
                                if let protein = protein {
                                    TacoFillingShape(shellType: shell)
                                        .fill(proteinColor(for: protein))
                                        .frame(width: size * 0.75, height: size * 0.75)
                                }
                            }
                        )
                } else {
                    // Single shell with subtle border for other types
                    TacoShellShape(shellType: shell)
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                        .background(
                            TacoShellShape(shellType: shell)
                                .fill(shellColor(for: shell))
                        )
                        .frame(width: size, height: size)
                    
                    // Protein filling
                    if let protein = protein {
                        TacoFillingShape(shellType: shell)
                            .fill(proteinColor(for: protein))
                            .frame(width: size * 0.75, height: size * 0.75)
                    }
                }
            } else {
                // No shell specified - show emoji fallback
                Text("🌮")
                    .font(.system(size: size * 0.6))
            }
        }
    }
    
    // MARK: - Color Helpers
    
    private func shellColor(for shell: ShellType) -> Color {
        switch shell {
        case .crunchy:
            return Color(red: 0.95, green: 0.77, blue: 0.20) // Bright yellow/golden for crunchy
        case .softFlour:
            return Color(red: 0.96, green: 0.92, blue: 0.84) // Light beige for flour
        case .softCorn:
            return Color(red: 0.95, green: 0.85, blue: 0.55) // Warm yellow for corn
        }
    }
    
    private func proteinColor(for protein: ProteinType) -> Color {
        switch protein {
        case .beef:
            return Color(red: 0.50, green: 0.28, blue: 0.18) // Dark brown for beef
        case .chicken:
            return Color(red: 0.88, green: 0.78, blue: 0.62) // Lighter tan for chicken
        }
    }
}

// MARK: - Taco Shell Shape

/// Custom shape for taco shell - top-down view
struct TacoShellShape: Shape {
    let shellType: ShellType
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let centerX = width / 2
        let centerY = height / 2
        
        switch shellType {
        case .crunchy:
            // Crunchy: 6" × 3" (2:1 ratio) - crescent shape with flat top/bottom
            // Width is 2x height to match proportions
            let shellWidth = width * 0.8
            let shellHeight = shellWidth / 2  // 2:1 aspect ratio
            
            // Top flat edge
            path.move(to: CGPoint(x: centerX - shellWidth * 0.4, y: centerY - shellHeight * 0.5))
            path.addLine(to: CGPoint(x: centerX + shellWidth * 0.4, y: centerY - shellHeight * 0.5))
            
            // Right curved side
            path.addQuadCurve(
                to: CGPoint(x: centerX + shellWidth * 0.4, y: centerY + shellHeight * 0.5),
                control: CGPoint(x: centerX + shellWidth * 0.55, y: centerY)
            )
            
            // Bottom flat edge
            path.addLine(to: CGPoint(x: centerX - shellWidth * 0.4, y: centerY + shellHeight * 0.5))
            
            // Left curved side
            path.addQuadCurve(
                to: CGPoint(x: centerX - shellWidth * 0.4, y: centerY - shellHeight * 0.5),
                control: CGPoint(x: centerX - shellWidth * 0.55, y: centerY)
            )
            
        case .softFlour:
            // Soft flour: 8" diameter - largest circle
            let radius = width * 0.48
            path.addEllipse(in: CGRect(x: centerX - radius, y: centerY - radius, width: radius * 2, height: radius * 2))
            
        case .softCorn:
            // Soft corn: 5" diameter - smaller circle (5/8 = 0.625 of flour)
            let radius = width * 0.48 * 0.625
            path.addEllipse(in: CGRect(x: centerX - radius, y: centerY - radius, width: radius * 2, height: radius * 2))
        }
        
        return path
    }
}

// MARK: - Taco Filling Shape

/// Custom shape for taco filling (protein) - top-down view sitting inside shell
struct TacoFillingShape: Shape {
    let shellType: ShellType
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let centerX = width / 2
        let centerY = height / 2
        
        switch shellType {
        case .crunchy:
            // Crunchy filling: Sits between the flat top/bottom borders
            // Leaves shell visible on rounded sides
            let fillWidth = width * 0.8 * 0.6  // 60% of shell width
            let fillHeight = fillWidth / 2  // Maintain 2:1 ratio
            
            // Create oval filling shape (slightly rounded rectangle)
            let fillRect = CGRect(
                x: centerX - fillWidth * 0.5,
                y: centerY - fillHeight * 0.5,
                width: fillWidth,
                height: fillHeight
            )
            path.addEllipse(in: fillRect)
            
        case .softFlour:
            // Soft flour filling: Smaller circle inside, leaving shell border visible
            let shellRadius = width * 0.48
            let fillRadius = shellRadius * 0.56  // 56% of shell radius
            path.addEllipse(in: CGRect(x: centerX - fillRadius, y: centerY - fillRadius, width: fillRadius * 2, height: fillRadius * 2))
            
        case .softCorn:
            // Soft corn filling: Smaller circle inside
            let shellRadius = width * 0.48 * 0.625
            let fillRadius = shellRadius * 0.7  // 70% of shell radius
            path.addEllipse(in: CGRect(x: centerX - fillRadius, y: centerY - fillRadius, width: fillRadius * 2, height: fillRadius * 2))
        }
        
        return path
    }
}

// MARK: - Previews

#Preview("All Taco Combinations") {
    VStack(spacing: 20) {
        Text("Taco Icon Variations (Top-Down View)")
            .font(.headline)
            .foregroundColor(.white)
        
        // Beef Tacos
        VStack(spacing: 15) {
            Text("Beef")
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack(spacing: 20) {
                VStack {
                    TacoIconView(protein: .beef, shell: .crunchy, size: 60)
                    Text("Crunchy")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                VStack {
                    TacoIconView(protein: .beef, shell: .softFlour, size: 60)
                    Text("Soft Flour")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                VStack {
                    TacoIconView(protein: .beef, shell: .softCorn, size: 60)
                    Text("Soft Corn")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        
        // Chicken Tacos
        VStack(spacing: 15) {
            Text("Chicken")
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack(spacing: 20) {
                VStack {
                    TacoIconView(protein: .chicken, shell: .crunchy, size: 60)
                    Text("Crunchy")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                VStack {
                    TacoIconView(protein: .chicken, shell: .softFlour, size: 60)
                    Text("Soft Flour")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                VStack {
                    TacoIconView(protein: .chicken, shell: .softCorn, size: 60)
                    Text("Soft Corn")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        
        // No protein specified
        VStack(spacing: 15) {
            Text("Shell Only")
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack(spacing: 20) {
                VStack {
                    TacoIconView(protein: nil, shell: .crunchy, size: 60)
                    Text("Crunchy")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                VStack {
                    TacoIconView(protein: nil, shell: .softFlour, size: 60)
                    Text("Soft Flour")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                VStack {
                    TacoIconView(protein: nil, shell: .softCorn, size: 60)
                    Text("Soft Corn")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    .padding()
    .background(Color.black)
}

#Preview("Size Variations") {
    VStack(spacing: 20) {
        Text("Size Scaling Test")
            .font(.headline)
            .foregroundColor(.white)
        
        HStack(spacing: 20) {
            ForEach([20, 30, 40, 50, 60, 80], id: \.self) { size in
                VStack {
                    TacoIconView(protein: .beef, shell: .crunchy, size: CGFloat(size))
                    Text("\(size)pt")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    .padding()
    .background(Color.black)
}
