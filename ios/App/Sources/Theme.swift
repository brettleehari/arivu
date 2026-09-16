// The palette, as role names rather than colours.
//
// The same three brand values and the same role names as android/app/.../ui/Theme.kt, so the two
// apps are the same product and the contrast table in leaves/design.md §10 describes both. Every
// role a component uses is set explicitly here; no system tint and no dynamic colour leaks in, on
// either platform.
//
// UNVERIFIED ON DEVICE: these hex values are copied from the Android theme, which has a computed
// contrast table (design.md §10). The iOS rendering has not been checked against that table on a
// screen — Design's W72 is exactly that check.
//
// spine: C11

import SwiftUI

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

enum Palette {
    // Brand (leaves/design.md §9). The same three hex values on both platforms.
    static let brandGreen = Color(light: 0x1F5C4A, dark: 0x1F5C4A)
    static let brandPaper = Color(light: 0xF5F1E6, dark: 0xF5F1E6)
    static let brandAmber = Color(light: 0xD98E04, dark: 0xD98E04)

    static let primary = Color(light: 0x1F5C4A, dark: 0x8FCFB6)
    static let onPrimary = Color(light: 0xFFFFFF, dark: 0x06251B)
    static let primaryContainer = Color(light: 0xD3E8DF, dark: 0x1F4A3C)
    static let onPrimaryContainer = Color(light: 0x0B2A20, dark: 0xD3E8DF)

    static let surface = Color(light: 0xFBFAF7, dark: 0x141513)
    static let onSurface = Color(light: 0x1B1C1A, dark: 0xE4E2DC)
    static let surfaceVariant = Color(light: 0xEDEBE5, dark: 0x2A2B28)
    static let onSurfaceVariant = Color(light: 0x4A4843, dark: 0xC9C6BE)

    static let outline = Color(light: 0x78766F, dark: 0x939089)
    static let outlineVariant = Color(light: 0xCAC7BF, dark: 0x48473F)

    static let error = Color(light: 0xB3261E, dark: 0xF2B8B5)
    static let errorContainer = Color(light: 0xF9DEDC, dark: 0x8C1D18)
    static let onErrorContainer = Color(light: 0x410E0B, dark: 0xF9DEDC)
}

enum Metrics {
    /// ≥ 48 pt, deliberately above the 44 pt HIG floor, so one number describes both apps
    /// (leaves/design.md §10).
    static let minTouchTarget: CGFloat = 48
    /// Send and Stop share one slot at one size, so the text field never jumps (§3).
    static let sendSlotWidth: CGFloat = 88
    static let sendSlotHeight: CGFloat = 56
    /// Bubbles cap and wrap; the list follows the last line of a long reply, not its top.
    static let bubbleMaxWidth: CGFloat = 560
    static let userBubbleLeadingInset: CGFloat = 40
    static let replyBubbleTrailingInset: CGFloat = 24
}
