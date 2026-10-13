import SwiftUI
import UIKit

struct Palette {
    let bg, line, text, dim, off, acc, sun, green, red, king, vwap, ink: Color
}

enum ThemeID: String, CaseIterable, Identifiable {
    case dark, discord, light, webapp
    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "Darker"
        case .discord: return "Discord"
        case .light: return "WebApp Light"
        case .webapp: return "WebApp Original"
        }
    }

    var scheme: ColorScheme { self == .light ? .light : .dark }

    var palette: Palette {
        switch self {
        case .dark:
            return Palette(bg: .hex(0x08080a), line: .hex(0x1e1e22), text: .hex(0xf4efe5), dim: .hex(0x8f8f97),
                           off: .hex(0x4a4a52), acc: .hex(0xc9a565), sun: .hex(0xc9a565), green: .hex(0x8ec98e),
                           red: .hex(0xc97e7e), king: .hex(0x8e8ec9), vwap: .hex(0x6d8eaa), ink: .hex(0x08080a))
        case .discord:
            return Palette(bg: .hex(0x313338), line: .hex(0x3f4147), text: .hex(0xf2f3f5), dim: .hex(0xb5bac1),
                           off: .hex(0x6d6f78), acc: .hex(0x5865f2), sun: .hex(0xf0b232), green: .hex(0x23a55a),
                           red: .hex(0xf23f43), king: .hex(0x949cf7), vwap: .hex(0x00a8fc), ink: .hex(0x111214))
        case .light:
            return Palette(bg: .hex(0xf5f3ee), line: .hex(0xe2ded4), text: .hex(0x1a1814), dim: .hex(0x5f5b54),
                           off: .hex(0xb8b3a8), acc: .hex(0x8b6f2c), sun: .hex(0x8b6f2c), green: .hex(0x3d7a3d),
                           red: .hex(0xa94442), king: .hex(0x5a5aa8), vwap: .hex(0x3f6a8f), ink: .hex(0xffffff))
        case .webapp:
            return Palette(bg: .hex(0x131316), line: .hex(0x232328), text: .hex(0xf4efe5), dim: .hex(0x8a8a92),
                           off: .hex(0x5a5a62), acc: .hex(0xc9a565), sun: .hex(0xc9a565), green: .hex(0x8ec98e),
                           red: .hex(0xc97e7e), king: .hex(0x8e8ec9), vwap: .hex(0x6d8eaa), ink: .hex(0x131316))
        }
    }
}

enum FontID: String, CaseIterable, Identifiable {
    case grotesk, archivo
    var id: String { rawValue }
    var title: String { self == .grotesk ? "Schibsted Grotesk" : "Archivo (thinkorswim style)" }
    var postScript: String { self == .grotesk ? "SchibstedGrotesk-Regular" : "Archivo-Regular" }
}

struct Style {
    let theme: ThemeID
    let fontID: FontID
    var p: Palette { theme.palette }

    func f(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Style.font(fontID, size, weight)
    }

    static func font(_ id: FontID, _ size: CGFloat, _ weight: Font.Weight) -> Font {
        let base: Font = UIFont(name: id.postScript, size: size) != nil
            ? .custom(id.postScript, size: size)
            : .system(size: size)
        return base.weight(weight).monospacedDigit()
    }
}

private struct StyleKey: EnvironmentKey {
    static let defaultValue = Style(theme: .dark, fontID: .grotesk)
}

extension EnvironmentValues {
    var style: Style {
        get { self[StyleKey.self] }
        set { self[StyleKey.self] = newValue }
    }
}

extension Color {
    static func hex(_ v: UInt32) -> Color {
        Color(.sRGB,
              red: Double((v >> 16) & 0xff) / 255,
              green: Double((v >> 8) & 0xff) / 255,
              blue: Double(v & 0xff) / 255,
              opacity: 1)
    }
}

// Shared pieces: square chips, filled result boxes, hairline rows.

struct Chip: View {
    @Environment(\.style) private var s
    let label: String
    let fill: Color
    var body: some View {
        Text(label)
            .font(s.f(11, .bold))
            .foregroundStyle(s.p.ink)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(fill)
    }
}

struct ResultBox: View {
    @Environment(\.style) private var s
    let label: String
    let fill: Color?
    var minWidth: CGFloat = 84
    var body: some View {
        Text(label)
            .font(s.f(15, .bold))
            .foregroundStyle(fill == nil ? s.p.dim : s.p.ink)
            .frame(minWidth: minWidth, minHeight: 36)
            .padding(.horizontal, 6)
            .background(fill ?? .clear)
            .overlay(Rectangle().stroke(fill == nil ? s.p.line : .clear, lineWidth: 1))
    }
}

struct Hairline: View {
    @Environment(\.style) private var s
    var body: some View { Rectangle().fill(s.p.line).frame(height: 1) }
}

struct LabeledValue: View {
    @Environment(\.style) private var s
    let label: String
    let value: String
    var color: Color? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(s.f(12)).foregroundStyle(s.p.dim)
            Text(value).font(s.f(16, .semibold)).foregroundStyle(color ?? s.p.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionLabel: View {
    @Environment(\.style) private var s
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(s.f(13, .semibold)).tracking(1)
            .foregroundStyle(s.p.dim)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 4)
    }
}

func pct(_ v: Double?, digits: Int = 0) -> String {
    guard let v else { return "—" }
    return (v >= 0 ? "+" : "") + String(format: "%.\(digits)f%%", v)
}

func money(_ v: Double?) -> String {
    guard let v else { return "—" }
    return String(format: "$%.2f", v)
}

func titleCase(_ s: String?) -> String {
    (s ?? "").replacingOccurrences(of: "_", with: " ").capitalized
}
