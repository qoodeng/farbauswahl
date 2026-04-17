import Foundation

/// Loads ~30K named colors from meodai/color-names and provides fast nearest-match lookup
/// using Euclidean distance in OKLAB space.
final class ColorNames {
    static let shared = ColorNames()

    struct NamedColor {
        let name: String
        let hex: String
        let color: ColorValue
        let oklab: (L: Double, a: Double, b: Double)
        let isGoodName: Bool
    }

    private var colors: [NamedColor] = []
    private(set) var isLoaded = false

    private init() {}

    func load() {
        guard !isLoaded else { return }
        guard let url = Bundle.module.url(forResource: "colornames", withExtension: "csv") else {
            FileHandle.standardError.write(Data("[Farbauswahl] colornames.csv not found in bundle\n".utf8))
            return
        }
        guard let data = try? String(contentsOf: url, encoding: .utf8) else {
            FileHandle.standardError.write(Data("[Farbauswahl] Failed to read colornames.csv\n".utf8))
            return
        }

        let lines = data.split(separator: "\n").dropFirst() // skip header
        colors.reserveCapacity(lines.count)

        for line in lines {
            let cols = line.split(separator: ",", maxSplits: 2)
            guard cols.count >= 2 else { continue }
            let name = String(cols[0])
            let hex = String(cols[1]).trimmingCharacters(in: .whitespaces)
            let isGood = cols.count > 2 && String(cols[2]).trimmingCharacters(in: CharacterSet.whitespaces) == "x"
            let cv = ColorValue(hex: hex)
            colors.append(NamedColor(
                name: name,
                hex: hex,
                color: cv,
                oklab: cv.oklab,
                isGoodName: isGood
            ))
        }

        isLoaded = true
        FileHandle.standardError.write(Data("[Farbauswahl] Loaded \(colors.count) color names\n".utf8))
    }

    struct Match {
        let name: String
        let hex: String
        let deltaE: Double
        let isExact: Bool
    }

    /// Find the nearest named color using Euclidean ΔE in OKLAB.
    func nearest(to color: ColorValue, count: Int = 1) -> Match? {
        nearestMatches(to: color, count: count).first
    }

    /// Find the N nearest named colors.
    func nearestMatches(to color: ColorValue, count: Int = 3) -> [Match] {
        guard isLoaded else { return [] }
        let lab = color.oklab

        // Linear scan — ~30K entries, each iteration is 3 subtracts + 3 multiplies + 1 add.
        // Under 1ms on any modern Mac. No need for a kd-tree.
        var best: [(index: Int, dist: Double)] = []

        for (i, nc) in colors.enumerated() {
            let dL = lab.L - nc.oklab.L
            let da = lab.a - nc.oklab.a
            let db = lab.b - nc.oklab.b
            let dist = dL * dL + da * da + db * db // skip sqrt for comparison

            if best.count < count {
                best.append((i, dist))
                best.sort { $0.dist < $1.dist }
            } else if dist < best.last!.dist {
                best[best.count - 1] = (i, dist)
                best.sort { $0.dist < $1.dist }
            }
        }

        return best.map { entry in
            let nc = colors[entry.index]
            let de = sqrt(entry.dist)
            return Match(name: nc.name, hex: nc.hex, deltaE: de, isExact: de < 0.001)
        }
    }
}
