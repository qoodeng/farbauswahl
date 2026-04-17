import Foundation

enum ColorFormat: String, CaseIterable, Codable {
    case hex = "Hex"
    case tailwind = "TW"
    case cssVar = "CSS"
    case swiftUI = "Swift"
    case rgb = "RGB"
    case hsl = "HSL"
    case hsb = "HSB"
    case oklch = "OKLCH"

    var label: String { rawValue }

    var shortLabel: String {
        switch self {
        case .hex: "HEX"
        case .tailwind: "TW"
        case .cssVar: "CSS"
        case .swiftUI: "SWIFT"
        case .rgb: "RGB"
        case .hsl: "HSL"
        case .hsb: "HSB"
        case .oklch: "OKLCH"
        }
    }

    func format(_ color: ColorValue) -> String {
        switch self {
        case .hex:
            return color.hex
        case .rgb:
            return "rgb(\(color.r255), \(color.g255), \(color.b255))"
        case .hsl:
            let (h, s, l) = color.hsl
            return String(format: "hsl(%.0f, %.0f%%, %.0f%%)", h, s * 100, l * 100)
        case .hsb:
            let (h, s, b) = color.hsb
            return String(format: "hsb(%.0f, %.0f%%, %.0f%%)", h, s * 100, b * 100)
        case .oklch:
            let (L, C, h) = color.oklch
            return String(format: "oklch(%.2f %.2f %.0f)", L, C, h)
        case .tailwind:
            return TailwindColors.shared.nearest(to: color)?.name ?? color.hex
        case .cssVar:
            if let token = TailwindColors.shared.nearest(to: color) {
                return "var(--color-\(token.name))"
            }
            return "var(--color-custom)"
        case .swiftUI:
            return String(format: "Color(red: %.2f, green: %.2f, blue: %.2f)", color.r, color.g, color.b)
        }
    }
}

struct FormattedColor {
    let color: ColorValue
    let values: [(format: ColorFormat, label: String, value: String)]
    let colorName: String?
    let p3: String

    init(color: ColorValue) {
        self.color = color
        self.values = ColorFormat.allCases.map { fmt in
            (format: fmt, label: fmt.shortLabel, value: fmt.format(color))
        }
        self.colorName = ColorNames.shared.nearest(to: color)?.name
        let p3 = color.displayP3
        self.p3 = String(format: "color(display-p3 %.3f %.3f %.3f)", p3.r, p3.g, p3.b)
    }
}
