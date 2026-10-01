import CoreImage
import CoreMedia

@MainActor
@Observable
final class CameraViewModel {
    private let renderer: CameraPreviewRenderer?
    private let engine: any EngineProvider
    
    private var cameraTask: Task<Void, Never>?
    private var ocrTask: Task<Void, Never>?

    var errorMessage: String?

    let previewCoordinator: MetalCameraPreview.Coordinator?

    var recognizedDigits: String = ""
    private let ocrProcessor = OCRProcessor()

    init() {
        #if targetEnvironment(simulator)
            self.engine = MockCameraEngine()
        #else
            self.engine = CameraEngine()
        #endif

        do {
            let renderer = try CameraPreviewRenderer()
            self.renderer = renderer
            previewCoordinator = MetalCameraPreview.Coordinator(renderer: renderer)

        } catch {
            self.renderer = nil
            self.previewCoordinator = nil
            self.errorMessage = error.localizedDescription
        }

    }

    func startSession() {
        guard let renderer else { return }
        if cameraTask == nil {
            cameraTask = Task { await engine.start(frameInbox: renderer.frameInbox) }
        }
        if ocrTask == nil {
            ocrTask = Task { await runOCRLoop(frameInbox: renderer.frameInbox) }
        }
    }
    
    func stopSession() {
        cameraTask?.cancel()
        cameraTask = nil
        ocrTask?.cancel()
        ocrTask = nil
        Task {
            await engine.stop()
        }
    }

    private func runOCRLoop(frameInbox: FrameInbox) async {
        while !Task.isCancelled {
            guard let sampleBuffer = frameInbox.latest() else {
                try? await Task.sleep(nanoseconds: 50_000_000)
                continue
            }
            let orientation = cameraBufferOrientationForVision()
            if let result = await ocrProcessor.submit(
                sampleBuffer: sampleBuffer,
                orientation: orientation
            ) {
                recognizedDigits = result.joined(separator: " ")
            }
            try? await Task.sleep(nanoseconds: 33_333_333)
        }
    }

    /// Orientation of the raw camera buffer from AVCapture.
    /// This is independent from UI/preview rotation (handled in Metal).
    private func cameraBufferOrientationForVision() -> CGImagePropertyOrientation {
        .right
    }
}
