//  WHAT: The words on a piece, read by the Vision framework's text recogniser at its fast level: the lines the voice
//        synthesis may quote as the designer's own samples, and what a client logo says.
//  PIN:  FAST, OPTIONAL, NO MODEL OF OURS. Fast recognition (no language correction) is cheap; `CRAFTED_OCR=0` turns it
//        off, and a piece with no words read is measured all the same.

import CoreGraphics
import Foundation
import Vision

public enum TextReader {
    public static var enabled: Bool { ProcessInfo.processInfo.environment["CRAFTED_OCR"] != "0" }

    /// The lines read off `image`, top first, each at least two characters.
    public static func lines(_ image: CGImage) -> [String] {
        guard enabled else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do { try handler.perform([request]) } catch { return [] }
        let observations = (request.results ?? []).sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
        return observations.compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
    }
}
