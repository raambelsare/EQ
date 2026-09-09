import SwiftUI

/// MacEQ Precision Audio Design Tokens
/// Dark graphite chassis with amber/copper accents and monospaced telemetry readouts.
public enum DesignSystem {
    public enum Colors {
        // Core Chassis & Backgrounds
        public static let bgDeep = Color(red: 0.05, green: 0.05, blue: 0.06)          // #0D0D0F
        public static let bgPanel = Color(red: 0.08, green: 0.08, blue: 0.09)         // #141417
        public static let bgElement = Color(red: 0.12, green: 0.12, blue: 0.14)       // #1F1F24
        
        // Borders & Subtle Dividers
        public static let borderSubtle = Color(red: 0.18, green: 0.18, blue: 0.20)    // #2E2E33
        public static let borderActive = Color(red: 0.30, green: 0.30, blue: 0.34)    // #4D4D57
        public static let gridLine = Color(red: 0.15, green: 0.15, blue: 0.17)        // #26262B
        
        // Accents
        public static let amber = Color(red: 0.98, green: 0.35, blue: 0.15)           // #FA5926 (Primary Accent)
        public static let amberGlow = Color(red: 0.98, green: 0.35, blue: 0.15, opacity: 0.25)
        public static let copper = Color(red: 0.85, green: 0.50, blue: 0.30)          // Secondary accent
        public static let cyan = Color(red: 0.20, green: 0.80, blue: 0.90)            // Secondary curve accent
        
        // Signal & Telemetry States
        public static let meterGreen = Color(red: 0.20, green: 0.85, blue: 0.45)      // Normal signal
        public static let meterYellow = Color(red: 0.95, green: 0.75, blue: 0.20)     // Caution (-6 to -3 dBFS)
        public static let meterAmber = Color(red: 0.98, green: 0.45, blue: 0.15)      // Danger (-3 to 0 dBFS)
        public static let meterClip = Color(red: 0.95, green: 0.20, blue: 0.20)       // Clip Overload (Red)
        
        // Typography
        public static let textPrimary = Color(red: 0.92, green: 0.92, blue: 0.94)
        public static let textSecondary = Color(red: 0.55, green: 0.55, blue: 0.60)
        public static let textMuted = Color(red: 0.38, green: 0.38, blue: 0.42)
    }
    
    public enum Typography {
        public static let readoutFont = Font.system(size: 11, weight: .medium, design: .monospaced)
        public static let labelFont = Font.system(size: 10, weight: .semibold, design: .default)
        public static let titleFont = Font.system(size: 14, weight: .bold, design: .default)
        public static let headerFont = Font.system(size: 12, weight: .semibold, design: .monospaced)
    }
    
    public enum Layout {
        public static let cornerRadius: CGFloat = 6.0
        public static let panelPadding: CGFloat = 12.0
    }
}
