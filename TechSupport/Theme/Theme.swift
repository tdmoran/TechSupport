import SwiftUI

enum Theme {
    enum Colors {
        // Base palette — warm-tinted dark
        static let background = Color(nsColor: NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1))
        static let surface = Color(nsColor: NSColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1))
        static let surfaceHover = Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.19, alpha: 1))
        static let surfaceBorder = Color.white.opacity(0.06)
        static let divider = Color.white.opacity(0.08)

        // Accent — soft teal instead of harsh blue
        static let accent = Color(nsColor: NSColor(red: 0.35, green: 0.72, blue: 0.82, alpha: 1))
        static let accentSubtle = Color(nsColor: NSColor(red: 0.35, green: 0.72, blue: 0.82, alpha: 0.15))

        // Text
        static let textPrimary = Color.white.opacity(0.92)
        static let textSecondary = Color.white.opacity(0.50)
        static let textTertiary = Color.white.opacity(0.30)

        // Status — softer, less saturated
        static let statusGreen = Color(nsColor: NSColor(red: 0.35, green: 0.78, blue: 0.55, alpha: 1))
        static let statusYellow = Color(nsColor: NSColor(red: 0.90, green: 0.75, blue: 0.30, alpha: 1))
        static let statusRed = Color(nsColor: NSColor(red: 0.90, green: 0.40, blue: 0.40, alpha: 1))

        // Terminal background — matches exactly so it blends
        static let terminalBG = NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
    }

    enum Fonts {
        static let title = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let heading = Font.system(size: 12, weight: .semibold)
        static let body = Font.system(size: 13)
        static let caption = Font.system(size: 11, weight: .medium)
        static let captionMono = Font.system(size: 11, weight: .medium, design: .monospaced)
        static let monospaced = Font.system(size: 12, design: .monospaced)
        static let metricValue = Font.system(size: 22, weight: .bold, design: .rounded)
        static let metricUnit = Font.system(size: 11, weight: .regular, design: .rounded)
        static let tabLabel = Font.system(size: 12, weight: .medium)
    }

    enum Spacing {
        static let xxsmall: CGFloat = 2
        static let xsmall: CGFloat = 4
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 24
    }

    enum CornerRadius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
        static let pill: CGFloat = 100
    }
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    var padding: CGFloat = Theme.Spacing.large

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .fill(Theme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .strokeBorder(Theme.Colors.surfaceBorder, lineWidth: 1)
                    )
            )
    }
}

struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = Theme.CornerRadius.medium

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Theme.Colors.surfaceBorder, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle(padding: CGFloat = Theme.Spacing.large) -> some View {
        modifier(CardStyle(padding: padding))
    }

    func glassBackground(cornerRadius: CGFloat = Theme.CornerRadius.medium) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}
