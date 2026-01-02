import SwiftUI

struct Theme {
    // MARK: - Colors (from STYLE_GUIDE.md)
    struct Colors {
        // Primary Robot Heart colors
        static let robotCream = Color(hex: "E8DCC8")      // Primary text, light UI elements
        static let robotBrown = Color(hex: "3D2817")      // Robot details, subtle accents
        
        // Sunset/Golden Hour Palette
        static let sunsetOrange = Color(hex: "D84315")    // Primary CTA (Burnt Orange)
        static let goldenYellow = Color(hex: "FFB300")    // Secondary accent, warmth
        static let deepRedOrange = Color(hex: "BF360C")   // Dramatic accent
        static let amber = Color(hex: "FF6F00")           // Mid-tone sunset
        
        // Secondary Palette
        static let turquoise = Color(hex: "4ECDC4")       // Turquoise Sky - active states, location
        static let dustyPink = Color(hex: "FF8B94")       // Soft accent, playfulness
        static let playaDust = Color(hex: "C4A57B")       // Neutral, disabled states
        static let ledMagenta = Color(hex: "E91E63")      // Stage lighting, alerts
        
        // Background colors (warm tones per style guide)
        static let backgroundDark = Color(hex: "1A1410")  // Deep Night - primary background
        static let backgroundMedium = Color(hex: "2A1F1A") // Warm Gray - cards, modals
        static let backgroundLight = Color(hex: "3A2F2A") // Elevated surfaces
        
        // Status colors
        static let connected = Color(hex: "4CAF50")       // Green
        static let disconnected = Color(hex: "F44336")    // Red
        static let warning = Color(hex: "FF9800")         // Orange
        static let emergency = Color(hex: "F44336")       // Red
        static let info = Color(hex: "4ECDC4")            // Turquoise Sky
        
        // Text opacity helpers
        static let textSecondary = robotCream.opacity(0.7)
        static let textDisabled = robotCream.opacity(0.4)
    }
    
    // MARK: - Typography (SF Pro Rounded per style guide)
    struct Typography {
        static let title1 = Font.system(size: 34, weight: .bold, design: .rounded)      // Major titles
        static let title2 = Font.system(size: 28, weight: .bold, design: .rounded)      // Screen titles
        static let headline = Font.system(size: 22, weight: .semibold, design: .rounded) // Section headers
        static let body = Font.system(size: 17, weight: .regular, design: .rounded)     // Primary text
        static let callout = Font.system(size: 16, weight: .medium, design: .rounded)   // Buttons, tabs
        static let caption = Font.system(size: 14, weight: .regular, design: .rounded)  // Timestamps, metadata
        static let footnote = Font.system(size: 12, weight: .regular, design: .rounded) // Fine print
        
        // Legacy aliases
        static let largeTitle = title1
        static let title = title2
    }
    
    // MARK: - Gradients (from COLOR_PALETTE.md)
    struct Gradients {
        static let sunset = LinearGradient(
            colors: [Color(hex: "FFB300"), Color(hex: "FF6F00"), Color(hex: "BF360C")],
            startPoint: .top,
            endPoint: .bottom
        )
        
        static let playa = LinearGradient(
            colors: [Color(hex: "4ECDC4"), Color(hex: "C4A57B")],
            startPoint: .top,
            endPoint: .bottom
        )
        
        static let darkMode = LinearGradient(
            colors: [Color(hex: "2A1F1A"), Color(hex: "1A1410")],
            startPoint: .top,
            endPoint: .bottom
        )
        
        static let goldenHour = LinearGradient(
            colors: [Colors.goldenYellow, Colors.sunsetOrange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 9999
    }
    
    // MARK: - Animations
    struct Animations {
        static let quick = Animation.easeInOut(duration: 0.2)
        static let standard = Animation.easeInOut(duration: 0.3)
        static let slow = Animation.easeInOut(duration: 0.5)
        static let heartbeat = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
        static let pulse = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
