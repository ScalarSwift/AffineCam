import AVFoundation

actor CameraEngine: NSObject, EngineProvider {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let frameSource = FrameSource()
    private(set) var currentPosition: AVCaptureDevice.Position = .back
    
    nonisolated var frameStream: AsyncStream<CMSampleBuffer> {
        frameSource.stream
    }
    
    func start() async {
        guard await checkPermissions() else { return }
        
        session.beginConfiguration()
        session.sessionPreset = .high
        
        guard
            let videoDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: currentPosition
            ),
            let videoInput = try? AVCaptureDeviceInput(device: videoDevice)
        else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }
        
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        videoOutput.setSampleBufferDelegate(
            frameSource,
            queue: DispatchQueue(label: "com.affinecam.video", qos: .userInteractive)
        )
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        // Optional: keep the buffer in its native orientation and rotate in Metal only
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = false
            }
        }
        
        session.commitConfiguration()
        
        Task.detached {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    private func checkPermissions() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
            case .authorized:
                return true
            case .notDetermined:
                return await AVCaptureDevice.requestAccess(for: .video)
            default:
                return false
        }
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
