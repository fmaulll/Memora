import SwiftUI

extension Color {
    // MARK: - Dark Theme Color Scheme
    
    /// Main background (#151515)
    static let appBackground = Color(red: 0.08, green: 0.08, blue: 0.08)
    
    /// Cards, sheets, and elevated elements (#1E1E1E)
    static let appSurface = Color(red: 0.12, green: 0.12, blue: 0.12)
    
    /// Nested cards and secondary containers (#252525)
    static let appSecondarySurface = Color(red: 0.15, green: 0.15, blue: 0.15)
    
    /// Dividers and subtle outlines (#333333)
    static let appBorder = Color(red: 0.20, green: 0.20, blue: 0.20)
    
    // MARK: - Typography
    
    /// High-contrast primary text (#F5F5F5)
    static let appTextPrimary = Color(red: 0.96, green: 0.96, blue: 0.96)
    
    /// Muted secondary text and placeholders (#9A9A9A)
    static let appTextSecondary = Color(red: 0.60, green: 0.60, blue: 0.60)
    
    // MARK: - Brand & Status
    
    /// Primary brand action color (#FF7A00)
    static let appAccent = Color(red: 1.00, green: 0.48, blue: 0.00)
    
    /// Success states and positive indicators (#4CAF50)
    static let appSuccess = Color(red: 0.30, green: 0.69, blue: 0.31)
    
    /// Warning states and alerts (#FFB020)
    static let appWarning = Color(red: 1.00, green: 0.69, blue: 0.13)
    
    /// Error states and destructive actions (#E5484D)
    static let appError = Color(red: 0.90, green: 0.28, blue: 0.30)
    
    /// Informational indicators (#5B8CFF)
    static let appInfo = Color(red: 0.36, green: 0.55, blue: 1.00)
    
    // MARK: - Original Custom Dark Blue
    
    /// Custom ultra-dark blue hue (r: 0.04, g: 0.04, b: 0.13)
    static let appDarkBlue = Color(red: 0.04, green: 0.04, blue: 0.13)
}