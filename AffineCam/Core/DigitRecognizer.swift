import CoreImage
import Vision

nonisolated struct DigitRecognizer: Sendable {

    func process(sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) async throws
        -> [String]
    {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return [] }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(
            cvPixelBuffer: imageBuffer,
            orientation: orientation,
            options: [:]
        )
        try handler.perform([request])
        
        return (request.results ?? [])
            .compactMap { observ in observ.topCandidates(1).first }
            .filter { $0.confidence > 0.6 }
            .map { $0.string.filter(\.isNumber) }
            .filter { $0.count >= 2 }
    }
}
