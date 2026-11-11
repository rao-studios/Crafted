import Foundation

/// Colour arithmetic the kit needs and nothing more: a hex read and written, two colours mixed, relative luminance and
/// WCAG contrast, as the style's checks and the tests read them.
public enum PieceColour {
    /// "#abc", "abc", "#AABBCC" → (r, g, b) in 0…1; nil for anything else.
    public static func parse(_ hex: String) -> (r: Double, g: Double, b: Double)? {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        if text.count == 3 { text = text.map { "\($0)\($0)" }.joined() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    /// The hex as the page writes it: "#RRGGBB", upper case.
    public static func normal(_ hex: String) -> String {
        guard let (r, g, b) = parse(hex) else { return "#000000" }
        return format(r, g, b)
    }

    public static func format(_ r: Double, _ g: Double, _ b: Double) -> String {
        func byte(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }

    /// `a` moved `amount` of the way to `b`.
    public static func mix(_ a: String, _ b: String, _ amount: Double) -> String {
        guard let x = parse(a), let y = parse(b) else { return normal(a) }
        return format(x.r + (y.r - x.r) * amount, x.g + (y.g - x.g) * amount, x.b + (y.b - x.b) * amount)
    }

    /// WCAG relative luminance.
    public static func luminance(_ hex: String) -> Double {
        guard let (r, g, b) = parse(hex) else { return 0 }
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    /// WCAG contrast ratio, 1 to 21.
    public static func contrast(_ a: String, _ b: String) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// "rgb(244, 239, 230)" as WebKit computes a colour → "#F4EFE6"; nil when it is not one.
    public static func fromComputed(_ css: String) -> String? {
        let numbers = css.split { !"0123456789.".contains($0) }.compactMap { Double($0) }
        guard css.hasPrefix("rgb"), numbers.count >= 3 else { return nil }
        return format(numbers[0] / 255, numbers[1] / 255, numbers[2] / 255)
    }
}
