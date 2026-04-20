import AVFoundation

actor CameraEngine: NSObject, EngineProvider {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let frameSource = FrameSource()

    nonisolated var frameStream: AsyncStream<CMSampleBuffer> {
        frameSource.stream
    }

    func start() async {
        guard await checkPermissions() else { return }
        session.beginConfiguration()
        guard
            let videoDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .front
            ), let videoInput = try? AVCaptureDeviceInput(device: videoDevice)
        else { return }
        if session.canAddInput(videoInput) { session.addInput(videoInput) }

        videoOutput.setSampleBufferDelegate(
            frameSource,
            queue: DispatchQueue(label: "com.affinecam.video", qos: .userInteractive)
        )
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        session.commitConfiguration()

        Task.detached {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    private func checkPermissions() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            await AVCaptureDevice.requestAccess(for: .video)
        }
        return status == .authorized
    }

    private nonisolated final class FrameSource: NSObject,
        AVCaptureVideoDataOutputSampleBufferDelegate,
        @unchecked Sendable
    {
        let stream: AsyncStream<CMSampleBuffer>
        private var continuation: AsyncStream<CMSampleBuffer>.Continuation?

        override init() {
            let (stream, continuation) = AsyncStream.makeStream(of: CMSampleBuffer.self)
            self.stream = stream
            self.continuation = continuation
            super.init()
        }

        func captureOutput(
            _ output: AVCaptureOutput,
            didOutput sampleBuffer: CMSampleBuffer,
            from connection: AVCaptureConnection
        ) {
            continuation?.yield(sampleBuffer)
        }
    }
}
