import Foundation

/// A series as its payload file: `schema` first is not required by any reader, so the keys are sorted.
enum SeriesFile {
    static func data(_ series: TimeSeries) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(series)) ?? Data("{}".utf8)
    }
}
