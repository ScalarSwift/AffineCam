import CoreMedia
import CoreMotion

@MainActor
@Observable
class CameraViewModel {
    private let engine: any EngineProvider
    var currentFrame: CMSampleBuffer?

    init() {
        #if targetEnvironment(simulator)
            self.engine = MockCameraEngine()
        #else
            self.engine = CameraEngine()
        #endif
    }

    func startSession() {
        Task {
            await engine.start()
            for await frame in engine.frameStream {
                self.currentFrame = frame
            }
        }
    }
}
