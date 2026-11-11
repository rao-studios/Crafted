import Foundation

/// Text from a piece, made safe to place in the page, and numbers as CSS writes them. (After PlateAgent's PlateHTML.)
public enum PieceHTML {
    public static func escape(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for ch in text {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(ch)
            }
        }
        return out
    }

    /// Escaped, with a model's `**word**` drawn as emphasis and its line breaks kept.
    public static func inline(_ text: String) -> String {
        var html = escape(text)
        while let open = html.range(of: "**"), let close = html.range(of: "**", range: open.upperBound..<html.endIndex) {
            html.replaceSubrange(open.lowerBound..<close.upperBound, with: "<strong>" + html[open.upperBound..<close.lowerBound] + "</strong>")
        }
        return html.replacingOccurrences(of: "\n", with: "<br>")
    }

    /// A number as CSS writes it: whole when it is whole, one decimal otherwise.
    public static func n(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }

    /// A small number to four places, trailing zeros dropped: tracking in em, leading.
    public static func n4(_ value: Double) -> String {
        var text = String(format: "%.4f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text == "-0" ? "0" : text
    }
}
