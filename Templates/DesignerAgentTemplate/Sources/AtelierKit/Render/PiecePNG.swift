import Foundation

/// What a piece's PNG carries besides its pixels: the spec it was drawn from (`piece-spec`), and who designed the style
/// (`Author`, `Copyright`, `Description`, `Software`), each in an uncompressed `iTXt` chunk before `IEND`. One file is
/// the picture, its credit and what redraws it. (After PlateAgent's PlatePNG.)
public enum PiecePNG {
    public static let keyword = "piece-spec"
    private static let signature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

    /// `png` with each `(keyword, text)` in an `iTXt` chunk before its end.
    public static func embedding(_ texts: [(String, String)], in png: Data) -> Data {
        guard png.starts(with: signature), let end = chunkOffset(of: "IEND", in: png) else { return png }
        var chunks = Data()
        for (keyword, text) in texts {
            var body = Data(keyword.utf8.prefix(79))
            body.append(contentsOf: [0, 0, 0, 0, 0])   // keyword end, not compressed, method, no language, no translation
            body.append(Data(text.utf8))
            let typed = Data("iTXt".utf8) + body
            chunks.append(bigEndian(UInt32(body.count)))
            chunks.append(typed)
            chunks.append(bigEndian(crc32(typed)))
        }
        var out = png
        out.insert(contentsOf: chunks, at: end)
        return out
    }

    /// The text a PNG carries under `keyword`, if it carries one.
    public static func embedded(_ keyword: String = PiecePNG.keyword, in png: Data) -> String? {
        guard png.starts(with: signature) else { return nil }
        var offset = 8
        let bytes = [UInt8](png)
        while offset + 12 <= bytes.count {
            let length = Int(UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3]))
            let type = String(decoding: bytes[(offset + 4)..<(offset + 8)], as: UTF8.self)
            let start = offset + 8, end = start + length
            guard end + 4 <= bytes.count else { return nil }
            if type == "iTXt" {
                let body = Array(bytes[start..<end])
                if let nul = body.firstIndex(of: 0), String(decoding: body[..<nul], as: UTF8.self) == keyword {
                    var i = nul + 3
                    for _ in 0..<2 { while i < body.count, body[i] != 0 { i += 1 }; i += 1 }
                    return i <= body.count ? String(decoding: body[i...], as: UTF8.self) : nil
                }
            }
            if type == "IEND" { return nil }
            offset = end + 4
        }
        return nil
    }

    private static func chunkOffset(of type: String, in png: Data) -> Int? {
        let bytes = [UInt8](png)
        var offset = 8
        while offset + 12 <= bytes.count {
            let length = Int(UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3]))
            if String(decoding: bytes[(offset + 4)..<(offset + 8)], as: UTF8.self) == type { return offset }
            offset += 12 + length
        }
        return nil
    }

    private static func bigEndian(_ value: UInt32) -> Data { withUnsafeBytes(of: value.bigEndian) { Data($0) } }

    private static let table: [UInt32] = (0..<256).map { n in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 == 1 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for byte in data { c = table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }
}
