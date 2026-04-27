import AVFoundation
import UIKit

actor MockCameraEngine: EngineProvider {
    private var mockTask: Task<Void, Never>?
    
    func start(frameInbox: FrameInbox) async {
        guard mockTask == nil else { return }
        
        mockTask = Task.detached(priority: .userInitiated) {
            let frameGenerator = MockFrameGenerator()
            
            while !Task.isCancelled {
                if let sampleBuffer = frameGenerator.makeFrame() {
                    frameInbox.enqueue(sampleBuffer)
                }
                
                try? await Task.sleep(nanoseconds: 33_333_333)
            }
        }
    }
    
    func stop() async {}
    
    /// Synthetic frame generator used in Simulator.
    /// Runs on a detached task and creates independent sample buffers, with no shared mutable state.
    private nonisolated final class MockFrameGenerator: @unchecked Sendable {
        func makeFrame() -> CMSampleBuffer? {
            let width = 640
            let height = 480
            
            var pixelBuffer: CVPixelBuffer?
            
            let attributes: [CFString: Any] = [
                kCVPixelBufferMetalCompatibilityKey: true,
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true,
                kCVPixelBufferIOSurfacePropertiesKey: [:]
            ]
            
            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_32BGRA,
                attributes as CFDictionary,
                &pixelBuffer
            )
            
            guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
                return nil
            }
            
            CVPixelBufferLockBaseAddress(buffer, [])
            defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
            
            guard let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer),
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
            ) else {
                return nil
            }
            
            context.setFillColor(UIColor.systemBlue.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            
            let text = NSAttributedString(
                string: "Mock \(Date().formatted(date: .omitted, time: .standard))",
                attributes: [
                    .foregroundColor: UIColor.white,
                    .font: UIFont.systemFont(ofSize: 30)
                ]
            )
            
            let line = CTLineCreateWithAttributedString(text)
            context.textPosition = CGPoint(x: 50, y: 200)
            CTLineDraw(line, context)
            
            var timing = CMSampleTimingInfo(
                duration: CMTime(value: 1, timescale: 30),
                presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
                decodeTimeStamp: .invalid
            )
            
            var formatDescription: CMFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: buffer,
                formatDescriptionOut: &formatDescription
            )
            
            guard let formatDescription else { return nil }
            
            var sampleBuffer: CMSampleBuffer?
            CMSampleBufferCreateReadyWithImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: buffer,
                formatDescription: formatDescription,
                sampleTiming: &timing,
                sampleBufferOut: &sampleBuffer
            )
            
            return sampleBuffer
        }
    }
}
