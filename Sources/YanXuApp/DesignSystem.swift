import AppKit
import SwiftUI

private extension NSColor {
    convenience init(rgb: Int, alpha: CGFloat = 1) {
        self.init(
            calibratedRed: CGFloat((rgb >> 16) & 0xff) / 255,
            green: CGFloat((rgb >> 8) & 0xff) / 255,
            blue: CGFloat(rgb & 0xff) / 255,
            alpha: alpha
        )
    }
}

private extension Color {
    static func adaptive(light: Int, dark: Int) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return NSColor(rgb: match == .darkAqua ? dark : light)
        })
    }
}

extension Color {
    static let yanxuAccent = Color.adaptive(light: 0x4F78F6, dark: 0x7F9BFF)
    static let yanxuAccentStrong = Color.adaptive(light: 0x3F67E8, dark: 0x99AEFF)
    static let yanxuAccentSoft = Color.adaptive(light: 0xEAF0FF, dark: 0x26304B)
    static let yanxuCanvas = Color.adaptive(light: 0xFAFBFC, dark: 0x17191D)
    static let yanxuCard = Color.adaptive(light: 0xFFFFFF, dark: 0x202329)
    static let yanxuRaised = Color.adaptive(light: 0xF6F7F9, dark: 0x282C33)
    static let yanxuBorder = Color.adaptive(light: 0xE5E7EB, dark: 0x383D46)
    static let yanxuInk = Color.adaptive(light: 0x252A32, dark: 0xF1F3F6)
    static let yanxuMuted = Color.adaptive(light: 0x8B919B, dark: 0xA7ADB7)
    static let yanxuSidebar = Color.adaptive(light: 0xF7F8FA, dark: 0x1D2025)
    static let yanxuSidebarSelected = Color.yanxuAccentSoft
    static let yanxuDanger = Color.adaptive(light: 0xE05D5D, dark: 0xF18A8A)
    static let yanxuSuccess = Color.adaptive(light: 0x55B987, dark: 0x71D0A1)
    static let yanxuWarning = Color.adaptive(light: 0xE99A45, dark: 0xF0B269)
    static let yanxuViolet = Color.adaptive(light: 0x8068D8, dark: 0xAA98F0)
    static let yanxuWarningSoft = Color.adaptive(light: 0xFFF5E8, dark: 0x3A2E22)
    static let yanxuNeutralSoft = Color.adaptive(light: 0xF3F5F7, dark: 0x292D34)
    static let yanxuCalendarBlock = Color.adaptive(light: 0xDDE7FF, dark: 0x2B385C)
    static let yanxuAllDayBlock = Color.adaptive(light: 0xE8F5EF, dark: 0x243C32)
}

struct PageHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(2.2)
                .foregroundStyle(Color.yanxuAccent)
            Text(title)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.yanxuInk)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.yanxuMuted)
        }
    }
}

struct PrimaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 15)
            .frame(minHeight: 36)
            .background(Color.yanxuAccentStrong.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .shadow(color: Color.yanxuAccentStrong.opacity(configuration.isPressed ? 0 : 0.18), radius: 8, y: 4)
    }
}

struct QuietActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.yanxuAccentStrong)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(Color.yanxuAccentSoft.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct SecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.yanxuAccent)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(configuration.isPressed ? Color.yanxuAccentSoft : Color.yanxuCard, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.yanxuAccent.opacity(0.28), lineWidth: 1)
            }
    }
}

struct EditorFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .frame(minHeight: 38)
            .background(Color.yanxuRaised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.yanxuBorder, lineWidth: 1)
            }
    }
}

extension View {
    func editorField() -> some View { modifier(EditorFieldModifier()) }
}
