import UIKit
import Vision

@MainActor
enum TextRecognizer {
    static func recognize(_ image: UIImage) throws -> String {
        guard let cgImage = image.cgImage else {
            throw AppError.unknown("Couldn't read text from that image.")
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: "\n")
    }
}
