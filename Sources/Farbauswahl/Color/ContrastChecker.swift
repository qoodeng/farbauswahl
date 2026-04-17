import Foundation

struct ContrastResult {
    let wcagRatio: Double
    let aaNormal: Bool      // 4.5:1
    let aaLarge: Bool       // 3:1
    let aaaNormal: Bool     // 7:1

    let apcaLc: Double
    let apcaBody: Bool      // |Lc| >= 60
    let apcaLarge: Bool     // |Lc| >= 45
    let apcaFine: Bool      // |Lc| >= 75

    let foreground: ColorValue
    let background: ColorValue

    var wcagRatioString: String {
        String(format: "%.2f : 1", wcagRatio)
    }

    var apcaLcString: String {
        String(format: "%.1f", apcaLc)
    }
}

enum ContrastChecker {

    // MARK: - WCAG 2.1

    static func wcagRatio(between a: ColorValue, and b: ColorValue) -> Double {
        let lum1 = a.relativeLuminance
        let lum2 = b.relativeLuminance
        let lighter = max(lum1, lum2)
        let darker = min(lum1, lum2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    // MARK: - APCA (Accessible Perceptual Contrast Algorithm)
    // Reference: https://github.com/Myndex/SAPC-APCA

    static func apcaLc(text: ColorValue, background: ColorValue) -> Double {
        // Estimated screen luminance using sRGB coefficients with APCA exponents
        let txtY = apca_sRGBtoY(r: text.r, g: text.g, b: text.b)
        let bgY = apca_sRGBtoY(r: background.r, g: background.g, b: background.b)

        // SAPC value
        let sapc: Double
        if bgY > txtY {
            // Normal polarity (dark text on light bg)
            let bClip = max(bgY, 0.0)
            let tClip = max(txtY, 0.0)
            sapc = (pow(bClip, 0.56) - pow(tClip, 0.57)) * 1.14
        } else {
            // Reverse polarity (light text on dark bg)
            let bClip = max(bgY, 0.0)
            let tClip = max(txtY, 0.0)
            sapc = (pow(bClip, 0.65) - pow(tClip, 0.62)) * 1.14
        }

        // Apply low-contrast clamp
        if abs(sapc) < 0.1 { return 0.0 }

        let Lc: Double
        if sapc > 0 {
            Lc = (sapc - 0.027) * 100.0
        } else {
            Lc = (sapc + 0.027) * 100.0
        }

        return Lc
    }

    private static func apca_sRGBtoY(r: Double, g: Double, b: Double) -> Double {
        // Linearize with 2.4 gamma (APCA uses simple gamma, not the piecewise sRGB)
        let rLin = pow(r.clamped(to: 0...1), 2.4)
        let gLin = pow(g.clamped(to: 0...1), 2.4)
        let bLin = pow(b.clamped(to: 0...1), 2.4)
        // APCA coefficients
        return 0.2126729 * rLin + 0.7151522 * gLin + 0.0721750 * bLin
    }

    // MARK: - Combined check

    static func check(foreground fg: ColorValue, background bg: ColorValue) -> ContrastResult {
        let ratio = wcagRatio(between: fg, and: bg)
        let lc = apcaLc(text: fg, background: bg)
        let absLc = abs(lc)

        return ContrastResult(
            wcagRatio: ratio,
            aaNormal: ratio >= 4.5,
            aaLarge: ratio >= 3.0,
            aaaNormal: ratio >= 7.0,
            apcaLc: lc,
            apcaBody: absLc >= 60,
            apcaLarge: absLc >= 45,
            apcaFine: absLc >= 75,
            foreground: fg,
            background: bg
        )
    }

    // MARK: - Auto-fix

    static func fix(_ color: ColorValue, against background: ColorValue, targetRatio: Double = 4.5) -> ColorValue? {
        let bgLum = background.relativeLuminance
        let lab = color.oklab
        let currentRatio = wcagRatio(between: color, and: background)
        if currentRatio >= targetRatio { return nil }

        let goingDarker = bgLum > 0.5
        var lo: Double, hi: Double
        if goingDarker {
            lo = 0.0; hi = lab.L
        } else {
            lo = lab.L; hi = 1.0
        }

        var best = color
        for _ in 0..<32 {
            let mid = (lo + hi) / 2.0
            let candidate = ColorValue.fromOklab(L: mid, a: lab.a, b: lab.b)
            let r = wcagRatio(between: candidate, and: background)
            if r >= targetRatio {
                best = candidate
                if goingDarker { lo = mid } else { hi = mid }
            } else {
                if goingDarker { hi = mid } else { lo = mid }
            }
        }

        return wcagRatio(between: best, and: background) >= targetRatio ? best : nil
    }
}
