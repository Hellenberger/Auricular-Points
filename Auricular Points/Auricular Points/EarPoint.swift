import Foundation
import CoreGraphics
import Combine   // 👈 required for ObservableObject / @Published


// MARK: - Data Model

public struct EarPoint: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let bodyPart: String
    /// normalized image coordinates in [0,1]; nil if not yet authored
    public let x: CGFloat?
    public let y: CGFloat?
}

public final class AuricularPointsModel: ObservableObject {
    @Published public var points: [EarPoint] = []
    @Published public var loadError: String?

    /// How close a tap must be to count as “on the point” (normalized units).
    public let tolerance: CGFloat = 0.04

    public init() {
        loadCSVFromBundle()  
    }


    // Load CSV from app bundle
    public func loadCSV(named resourceName: String) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "csv") else {
            self.loadError = "Couldn’t find \(resourceName).csv in the app bundle."
            return
        }
        loadCSV(from: url)
    }

    // Load CSV from arbitrary URL (e.g., macOS open panel)
    public func loadCSV(from url: URL) {
        do {
            let raw = try String(contentsOf: url, encoding: .utf8)
            let parsed = try Self.parseCSV(raw)
            self.points = parsed.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            if points.isEmpty {
                self.loadError = "CSV parsed but contained no rows.\n" +
                                 "Check header names and delimiter (comma/semicolon/tab)."
            } else {
                self.loadError = nil
            }
        } catch {
            self.loadError = "Failed reading CSV: \(error.localizedDescription)"
        }
    }
    
    public func loadCSVFromBundle(named name: String = "Auricular_Points") {
        loadCSV(named: name)
    }

    /// Header expected: name,bodyPart,x,y (x,y optional while authoring)
    public static func parseCSV(_ text: String) throws -> [EarPoint] {
        // Normalize endings + strip BOM
        var t = text.replacingOccurrences(of: "\r\n", with: "\n")
                    .replacingOccurrences(of: "\r", with: "\n")
        if t.hasPrefix("\u{feff}") { t.removeFirst() }

        // Simple comma splitter (no embedded commas in your file)
        func split(_ line: String) -> [String] {
            line.split(separator: ",", omittingEmptySubsequences: false).map {
                var s = String($0).trimmingCharacters(in: .whitespacesAndNewlines)
                if s.hasPrefix("\""), s.hasSuffix("\""), s.count >= 2 { s.removeFirst(); s.removeLast() }
                return s
            }
        }

        func toCGFloat(_ s: String) -> CGFloat? {
            guard let d = Double(s.trimmingCharacters(in: .whitespaces)) else { return nil }
            return CGFloat(d)
        }

        let lines = t.split(whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else { return [] }

        var out: [EarPoint] = []
        var startIndex = 0

        // Optional header? Detect and skip if first row looks like labels.
        let firstColsLower = split(lines[0]).map { $0.lowercased() }
        if firstColsLower.count >= 2 {
            let c0 = firstColsLower[0]
            if ["body part","bodypart","body_part","structure","name","label"].contains(c0) {
                startIndex = 1
            }
        }

        for raw in lines.dropFirst(startIndex) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.first == "#" { continue }

            var cols = split(trimmed)
            // Pad/trim to at least 3 columns: body, x, y
            while cols.count < 3 { cols.append("") }
            if cols.count > 3 { cols = Array(cols.prefix(3)) }

            let body = cols[0]
            if body.isEmpty { continue } // require a name/label

            let xVal = toCGFloat(cols[1])
            let yVal = toCGFloat(cols[2])

            // Use body part as both display name and bodyPart
            out.append(EarPoint(name: body, bodyPart: body, x: xVal, y: yVal))
        }

        return out
    }


    /// Nearest defined point to a normalized tap.
    public func nearestPoint(to tap: CGPoint) -> (point: EarPoint, distance: CGFloat)? {
        points.compactMap { p -> (EarPoint, CGFloat)? in
            guard let x = p.x, let y = p.y else { return nil }
            return (p, hypot(tap.x - x, tap.y - y))
        }
        .min { $0.1 < $1.1 }
    }
}
