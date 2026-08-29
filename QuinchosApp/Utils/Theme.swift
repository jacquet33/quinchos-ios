import SwiftUI
import UIKit

// MARK: - Color Palette

extension Color {
    static let appPrimary = Color(hex: "e85d04")
    static let appPrimaryDark = Color(hex: "c44b03")
    static let appBackground = Color(hex: "0f0f14")
    static let appSurface = Color(hex: "1a1a24")
    static let appSurfaceLight = Color(hex: "252535")
    static let appCard = Color(hex: "1e1e2e")
    static let appBorder = Color(hex: "2a2a3a")
    static let appTextPrimary = Color(hex: "f0f0f5")
    static let appTextSecondary = Color(hex: "9ca3af")
    static let appTextMuted = Color(hex: "6b7280")
    static let appSuccess = Color(hex: "10b981")
    static let appWarning = Color(hex: "f59e0b")
    static let appError = Color(hex: "ef4444")
    static let appStar = Color(hex: "fbbf24")
    static let estadoPendiente = Color(hex: "f59e0b")
    static let estadoConfirmada = Color(hex: "10b981")
    static let estadoCancelada = Color(hex: "ef4444")
    static let estadoCompletada = Color(hex: "6366f1")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Formatting

extension Int {
    var formattedPrecio: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "es_AR")
        return "$\(formatter.string(from: NSNumber(value: self)) ?? "\(self)")"
    }
}

// MARK: - Cerrar teclado

@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil, from: nil, for: nil
    )
}
