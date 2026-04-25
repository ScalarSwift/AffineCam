import CoreMedia

@MainActor
@Observable
final class CameraViewModel {
    let renderer: CameraPreviewRenderer?
    private let engine: any EngineProvider

    var errorMessage: String?

    let previewCoordinator: MetalCameraPreview.Coordinator?

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
        Task { await engine.start(frameInbox: renderer.frameInbox) }
    }
}
