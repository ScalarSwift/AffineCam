import CoreMedia
import CoreImage

nonisolated actor OCRProcessor {
    private let recognizer = DigitRecognizer()
    private var isProcessing = false
    private var frameCounter = 0
    
    func submit(sampleBuffer: CMSampleBuffer,
                orientation: CGImagePropertyOrientation) async -> [String]? {
        frameCounter += 1
        guard frameCounter % 120 == 0, !isProcessing else { return nil }
        isProcessing = true
        defer { isProcessing = false }
        do {
            return try await recognizer.process(sampleBuffer: sampleBuffer, orientation: orientation)
        } catch {
            return []
        }
    }
}
