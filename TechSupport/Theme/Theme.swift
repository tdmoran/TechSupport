import SwiftUI

// MARK: - Theme Mode

enum ThemeMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Theme Manager

@Observable
final class ThemeManager: @unchecked Sendable {
    @MainActor static let shared = ThemeManager()

    private static let userDefaultsKey = "selectedThemeMode"

    var mode: ThemeMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Self.userDefaultsKey)
        }
    }

    /// Resolved dark/light state taking system appearance into account.
    var isDark: Bool {
        switch mode {
        case .dark: return true
        case .light: return false
        case .system:
            if Thread.isMainThread {
                return NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            }
            return true // Fallback to dark if called off main thread
        }
    }

    var preferredColorScheme: ColorScheme? {
        mode.colorScheme
    }

    private init() {
        if let stored = UserDefaults.standard.string(forKey: Self.userDefaultsKey),
           let parsed = ThemeMode(rawValue: stored) {
            self.mode = parsed
        } else {
            self.mode = .dark
        }
    }
}

// MARK: - Theme

@MainActor
enum Theme {
    enum Colors {
        private static var isDark: Bool { ThemeManager.shared.isDark }

        // Base palette
        static var background: Color {
            isDark
                ? Color(nsColor: NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1))
                : Color(nsColor: NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1))
        }
        static var surface: Color {
            isDark
                ? Color(nsColor: NSColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1))
                : Color.white
        }
        static var surfaceHover: Color {
            isDark
                ? Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.19, alpha: 1))
                : Color(nsColor: NSColor(red: 0.92, green: 0.92, blue: 0.94, alpha: 1))
        }
        static var surfaceBorder: Color {
            isDark
                ? Color.white.opacity(0.06)
                : Color.black.opacity(0.08)
        }
        static var divider: Color {
            isDark
                ? Color.white.opacity(0.08)
                : Color.black.opacity(0.08)
        }

        // Accent — same teal for both themes
        static let accent = Color(nsColor: NSColor(red: 0.35, green: 0.72, blue: 0.82, alpha: 1))
        static var accentSubtle: Color {
            isDark
                ? Color(nsColor: NSColor(red: 0.35, green: 0.72, blue: 0.82, alpha: 0.15))
                : Color(nsColor: NSColor(red: 0.35, green: 0.72, blue: 0.82, alpha: 0.12))
        }

        // Text
        static var textPrimary: Color {
            isDark
                ? Color.white.opacity(0.92)
                : Color.black.opacity(0.85)
        }
        static var textSecondary: Color {
            isDark
                ? Color.white.opacity(0.50)
                : Color.black.opacity(0.50)
        }
        static var textTertiary: Color {
            isDark
                ? Color.white.opacity(0.30)
                : Color.black.opacity(0.28)
        }

        // Status — softer, less saturated
        static let statusGreen = Color(nsColor: NSColor(red: 0.35, green: 0.78, blue: 0.55, alpha: 1))
        static let statusYellow = Color(nsColor: NSColor(red: 0.90, green: 0.75, blue: 0.30, alpha: 1))
        static let statusRed = Color(nsColor: NSColor(red: 0.90, green: 0.40, blue: 0.40, alpha: 1))

        // Terminal background — matches exactly so it blends
        static var terminalBG: NSColor {
            ThemeManager.shared.isDark
                ? NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
                : NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
        }
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
