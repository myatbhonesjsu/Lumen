//
//  ColorExtensions.swift
//  Lumen
//
//  Adaptive colors for light and dark mode support
//

import SwiftUI

extension Color {
    // MARK: - Adaptive Background Colors

    /// Card background that adapts to light/dark mode
    static let cardBackground = Color(uiColor: .systemBackground)

    /// Secondary card background (slightly darker in light mode, lighter in dark mode)
    static let secondaryCardBackground = Color(uiColor: .secondarySystemBackground)

    /// Grouped background (main app background)
    static let appBackground = Color(uiColor: .systemGroupedBackground)

    /// Elevated card background (for cards that need to stand out)
    static let elevatedCardBackground = Color(uiColor: .tertiarySystemBackground)

    // MARK: - Adaptive Text Colors

    /// Primary text color (black in light mode, white in dark mode)
    static let primaryText = Color(uiColor: .label)

    /// Secondary text color (gray that adapts)
    static let secondaryText = Color(uiColor: .secondaryLabel)

    /// Tertiary text color (lighter gray that adapts)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)

    // MARK: - Adaptive Separator Colors

    /// Separator line color
    static let separator = Color(uiColor: .separator)

    // MARK: - Brand Colors (Consistent across modes)

    /// Primary yellow brand color
    static let brandYellow = Color.yellow

    /// Yellow for backgrounds/overlays (with reduced opacity)
    static func brandYellowBackground(opacity: Double = 0.1) -> Color {
        return Color.yellow.opacity(opacity)
    }

    // MARK: - Semantic Colors

    /// Success color (green)
    static let success = Color.green

    /// Warning color (orange)
    static let warning = Color.orange

    /// Error color (red)
    static let danger = Color.red

    /// Info color (blue)
    static let info = Color.blue

    // MARK: - Adaptive Shadow Colors

    /// Shadow color that works in both modes
    static var adaptiveShadow: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.3)
                : UIColor.black.withAlphaComponent(0.1)
        })
    }
}

// MARK: - Helper Extension for UIColor

extension UIColor {
    /// Creates a dynamic color that changes based on light/dark mode
    convenience init(light: UIColor, dark: UIColor) {
        self.init { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    }
}
