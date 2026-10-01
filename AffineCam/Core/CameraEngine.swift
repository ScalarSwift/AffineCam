import AVFoundation
import os

actor CameraEngine: NSObject, EngineProvider {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private nonisolated let frameSource = FrameSource()
    
    private let logger = Logger(subsystem: "AffineCam", category: "CameraEngine")
    
    private(set) var currentPosition: AVCaptureDevice.Position = .back
    
    func start(frameInbox: FrameInbox) async {
        frameSource.frameInbox = frameInbox
        do {
            try await configureSessionIfNeeded()
            if !session.isRunning {
                session.startRunning()
                logger.info("Capture session started")
            }
        } catch {
            logger.error("Failed to start camera session: \(error.localizedDescription)")
        }
    }
    
    func stop() async {
        if session.isRunning { session.stopRunning() }
    }
    
    private func configureSessionIfNeeded() async throws {
        guard await checkPermissions() else {
            throw CameraError.notAuthorized
        }
        guard session.inputs.isEmpty, session.outputs.isEmpty else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: currentPosition
            )
        else { throw CameraError.deviceUnavailable }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw CameraError.inputCreationFailed
        }
        
        guard session.canAddInput(videoInput) else {
            throw CameraError.addInputFailed
        }
        session.addInput(videoInput)
        
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(
            frameSource,
            queue: DispatchQueue(label: "com.affinecam.video", qos: .userInteractive)
        )
        
        guard session.canAddOutput(videoOutput) else {
            throw CameraError.addOutputFailed
        }
        session.addOutput(videoOutput)
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
    
    /// AVFoundation delegate object called on the capture queue.
    /// It only forwards frames into `FrameInbox`; it does not own UI or mutable shared rendering state.
    private nonisolated final class FrameSource: NSObject,
                                                 AVCaptureVideoDataOutputSampleBufferDelegate,
                                                 @unchecked Sendable {
        var frameInbox: FrameInbox?
        
        func captureOutput(
            _ output: AVCaptureOutput,
            didOutput sampleBuffer: CMSampleBuffer,
            from connection: AVCaptureConnection
        ) { frameInbox?.enqueue(sampleBuffer) }
    }
    
    enum CameraError: Error, LocalizedError {
        case notAuthorized
        case deviceUnavailable
        case inputCreationFailed
        case addInputFailed
        case addOutputFailed
        
        var errorDescription: String? {
            switch self {
                case .notAuthorized:
                    return "Camera permission was denied."
                case .deviceUnavailable:
                    return "No suitable camera device is available."
                case .inputCreationFailed:
                    return "Failed to create camera input."
                case .addInputFailed:
                    return "Failed to add camera input to session."
                case .addOutputFailed:
                    return "Failed to add video output to session."
            }
        }
    }
}
