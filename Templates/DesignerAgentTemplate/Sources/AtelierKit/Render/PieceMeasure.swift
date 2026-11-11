import Foundation

/// What WebKit answered about a page once its type was fitted, and what that means as sentences the model can act
/// on: a zone whose words do not fit even at the floor (blaming its longest blocks), a block wider than its box, a
/// block past the page's edge.
public enum PieceMeasure {
    public struct Raw: Codable, Sendable, Equatable {
        public struct Overflow: Codable, Sendable, Equatable {
            public struct Held: Codable, Sendable, Equatable { public let id: String; public let chars: Int }
            public let zone: String
            public let page: Int
            public let axis: String
            public let block: String
            public let scroll: Double
            public let client: Double
            public let blocks: [Held]
        }

        public struct Outside: Codable, Sendable, Equatable {
            public let id: String
            public let left: Double
            public let top: Double
            public let right: Double
            public let bottom: Double
        }

        public struct Probe: Codable, Sendable, Equatable {
            public let family: String
            public let colour: String
            public let background: String
            public let size: Double
            public let weight: String

            /// The first family of the computed stack, unquoted.
            public var firstFamily: String {
                (family.split(separator: ",").first.map(String.init) ?? family).trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            }
        }

        public var width: Double
        public var height: Double
        /// How far the page's type grew to fill it.
        public var grow: Double
        public var overflow: [Overflow]
        public var outside: [Outside]
        public var fits: [String: Double]
        public var probes: [String: Probe]
        public var loaded: [String]

        public static let empty = Raw(width: 0, height: 0, grow: 1, overflow: [], outside: [], fits: [:], probes: [:], loaded: [])
    }

    public static func raw(_ json: String) -> Raw {
        (try? JSONDecoder().decode(Raw.self, from: Data(json.utf8))) ?? .empty
    }

    /// The page's measure as findings, naming blocks as the model wrote them.
    public static func findings(_ raw: Raw, piece: Piece) -> [PieceFinding] {
        var found: [PieceFinding] = []
        for item in raw.overflow {
            if item.axis == "width", let (page, index, block) = locate(item.block, piece) {
                let fits = max(Int(Double(longestWord(block).count) * item.client / max(item.scroll, 1)), 3)
                found.append(PieceFinding(.overflow, Piece.element(page, index), numbers: [Int(item.scroll), Int(item.client)],
                                          "\(Piece.describe(page: page, block: index, block)) has a word too wide for its space even set small (\(Int(item.scroll)) px in \(Int(item.client))): use shorter words, about \(fits) letters at most."))
                continue
            }
            guard item.axis == "height" else { continue }
            let over = item.scroll - item.client
            // Blame the blocks that say the most, until their share of the page covers what ran over.
            let held = item.blocks.sorted { $0.chars > $1.chars }
            let total = max(Double(item.blocks.map(\.chars).reduce(0, +)), 1)
            let share = min(max(over / max(item.scroll, 1), 0.05), 0.8)
            var named: [String] = []
            for h in held.prefix(2) {
                guard let (page, index, block) = locate(h.id, piece) else { continue }
                let cut = max(Int((Double(h.chars) * share * (Double(h.chars) / total) * 1.2).rounded()), 8)
                named.append("\(Piece.describe(page: page, block: index, block)) by about \(cut) characters")
            }
            let place = item.zone == "hero" ? "the headline's space" : "its space"
            found.append(PieceFinding(.overflow, "page:\(item.page):zone:\(item.zone)", numbers: [Int(item.scroll), Int(item.client)],
                                      "page \(item.page) runs \(Int(over)) px past \(place) even with its type set at \(Int(PieceScripts.floor * 100))%: "
                                        + (named.isEmpty ? "say less on it." : "cut " + named.joined(separator: " and ") + ".")))
        }
        for item in raw.outside {
            if let (page, index, block) = locate(item.id, piece) {
                found.append(PieceFinding(.outside, Piece.element(page, index), numbers: [Int(item.left), Int(item.right)],
                                          "\(Piece.describe(page: page, block: index, block)) runs past the page's edge: shorten it."))
            }
        }
        return found
    }

    /// "2:3" → page 1 (zero-based), block 2, and the block.
    static func locate(_ id: String, _ piece: Piece) -> (Int, Int, PieceBlock)? {
        let parts = id.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, piece.pages.indices.contains(parts[0] - 1), piece.pages[parts[0] - 1].blocks.indices.contains(parts[1] - 1) else { return nil }
        return (parts[0] - 1, parts[1] - 1, piece.pages[parts[0] - 1].blocks[parts[1] - 1])
    }

    static func longestWord(_ block: PieceBlock) -> String {
        block.words.split(whereSeparator: \.isWhitespace).map(String.init).max { $0.count < $1.count } ?? ""
    }
}
