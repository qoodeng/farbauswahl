import AppKit

struct ColorValue: Codable, Equatable, Identifiable {
    let id: UUID
    let r: Double  // 0–1 sRGB
    let g: Double
    let b: Double

    init(r: Double, g: Double, b: Double, id: UUID = UUID()) {
        self.r = r.clamped(to: 0...1)
        self.g = g.clamped(to: 0...1)
        self.b = b.clamped(to: 0...1)
        self.id = id
    }

    // Graceful decoding: handles old library.json files that had extra fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.r = (try? container.decode(Double.self, forKey: .r)) ?? 0
        self.g = (try? container.decode(Double.self, forKey: .g)) ?? 0
        self.b = (try? container.decode(Double.self, forKey: .b)) ?? 0
    }

    init(hex: String) {
        var h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        // Expand 3-digit shorthand: "F0A" → "FF00AA"
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        guard h.count == 6, h.allSatisfy({ $0.isHexDigit }) else {
            self.init(r: 0, g: 0, b: 0)
            return
        }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            r: Double((rgb >> 16) & 0xFF) / 255.0,
            g: Double((rgb >> 8) & 0xFF) / 255.0,
            b: Double(rgb & 0xFF) / 255.0
        )
    }

    var nsColor: NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    // MARK: - Integer components

    var r255: Int { Int(round(r * 255)) }
    var g255: Int { Int(round(g * 255)) }
    var b255: Int { Int(round(b * 255)) }

    // MARK: - Hex

    var hex: String {
        String(format: "#%02X%02X%02X", r255, g255, b255)
    }

    // MARK: - HSL

    var hsl: (h: Double, s: Double, l: Double) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        let l = (maxC + minC) / 2.0

        guard delta > 0.00001 else { return (0, 0, l) }

        let s = l > 0.5 ? delta / (2.0 - maxC - minC) : delta / (maxC + minC)
        var h: Double
        if maxC == r {
            h = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxC == g {
            h = (b - r) / delta + 2
        } else {
            h = (r - g) / delta + 4
        }
        h *= 60
        if h < 0 { h += 360 }
        return (h, s, l)
    }

    // MARK: - HSB (HSV)

    var hsb: (h: Double, s: Double, b: Double) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC

        let brightness = maxC
        guard delta > 0.00001 else { return (0, 0, brightness) }

        let saturation = delta / maxC
        var hue: Double
        if maxC == r {
            hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxC == g {
            hue = (b - r) / delta + 2
        } else {
            hue = (r - g) / delta + 4
        }
        hue *= 60
        if hue < 0 { hue += 360 }
        return (hue, saturation, brightness)
    }

    // MARK: - Linear RGB

    private func srgbToLinear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    static func linearToSrgb(_ c: Double) -> Double {
        c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1.0 / 2.4) - 0.055
    }

    var linearR: Double { srgbToLinear(r) }
    var linearG: Double { srgbToLinear(g) }
    var linearB: Double { srgbToLinear(b) }

    // MARK: - OKLAB

    var oklab: (L: Double, a: Double, b: Double) {
        let lr = linearR, lg = linearG, lb = linearB

        let l_ = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
        let m_ = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
        let s_ = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb

        let l_cbrt = cbrt(l_)
        let m_cbrt = cbrt(m_)
        let s_cbrt = cbrt(s_)

        let L = 0.2104542553 * l_cbrt + 0.7936177850 * m_cbrt - 0.0040720468 * s_cbrt
        let a = 1.9779984951 * l_cbrt - 2.4285922050 * m_cbrt + 0.4505937099 * s_cbrt
        let b = 0.0259040371 * l_cbrt + 0.7827717662 * m_cbrt - 0.8086757660 * s_cbrt

        return (L, a, b)
    }

    // MARK: - OKLCH

    var oklch: (L: Double, C: Double, h: Double) {
        let lab = oklab
        let C = sqrt(lab.a * lab.a + lab.b * lab.b)
        var h = atan2(lab.b, lab.a) * 180.0 / .pi
        if h < 0 { h += 360 }
        return (lab.L, C, h)
    }

    // MARK: - Display P3

    var displayP3: (r: Double, g: Double, b: Double) {
        let nsP3 = nsColor.usingColorSpace(.displayP3) ?? nsColor
        return (nsP3.redComponent, nsP3.greenComponent, nsP3.blueComponent)
    }

    /// Colors are always normalized to sRGB on pick, so this is always false.
    /// The gamut status bar shows the display's capability instead.
    var isOutOfSRGB: Bool { false }

    // MARK: - Relative luminance (WCAG 2.1)

    var relativeLuminance: Double {
        0.2126 * linearR + 0.7152 * linearG + 0.0722 * linearB
    }

    // MARK: - OKLAB conversion

    static func fromOklab(L: Double, a: Double, b: Double) -> ColorValue {
        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b

        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        let lr = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let lg = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let lb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        return ColorValue(
            r: linearToSrgb(lr.clamped(to: 0...1)),
            g: linearToSrgb(lg.clamped(to: 0...1)),
            b: linearToSrgb(lb.clamped(to: 0...1))
        )
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
