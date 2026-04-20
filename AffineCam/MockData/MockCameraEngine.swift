import AVFoundation
import CoreMedia
import UIKit

actor MockCameraEngine: EngineProvider {
    private let frameSource = MockFrameSource()
    nonisolated var frameStream: AsyncStream<CMSampleBuffer> {
        frameSource.stream
    }

    func start() async {
        Task.detached(priority: .userInitiated) {
            await self.frameSource.startMocking()
        }
    }

    private nonisolated final class MockFrameSource: @unchecked Sendable {
        private var continuation: AsyncStream<CMSampleBuffer>.Continuation?
        let stream: AsyncStream<CMSampleBuffer>

        init() {
            let (stream, continuation) = AsyncStream.makeStream(of: CMSampleBuffer.self)
            self.stream = stream
            self.continuation = continuation
        }

        func startMocking() async {
            while true {
                generateFakeFrame()
                try? await Task.sleep(nanoseconds: 33_333_333)
            }
        }

        private func generateFakeFrame() {
            let (width, height) = (640, 480)
            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_32BGRA,
                nil,
                &pixelBuffer
            )
            guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
                return
            }

            CVPixelBufferLockBaseAddress(buffer, [])
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer),
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            )
            if let ctx = context {
                ctx.setFillColor(UIColor.systemBlue.cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
                let text = NSAttributedString(
                    string: "\(Date().timeIntervalSince1970)",
                    attributes: [
                        .foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 30),
                    ]
                )
                let line = CTLineCreateWithAttributedString(text)
                ctx.textPosition = CGPoint(x: 50, y: 200)
                CTLineDraw(line, ctx)
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])

            var sampleBuffer: CMSampleBuffer?
            var timing = CMSampleTimingInfo(
                duration: CMTime(value: 1, timescale: 30),
                presentationTimeStamp: CMTime(
                    value: Int64(Date().timeIntervalSince1970 * 1000),
                    timescale: 1000
                ),
                decodeTimeStamp: .invalid
            )
            var formatDesc: CMFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: buffer,
                formatDescriptionOut: &formatDesc
            )
            if let format = formatDesc {
                CMSampleBufferCreateReadyWithImageBuffer(
                    allocator: kCFAllocatorDefault,
                    imageBuffer: buffer,
                    formatDescription: format,
                    sampleTiming: &timing,
                    sampleBufferOut: &sampleBuffer
                )
            }
            if let sb = sampleBuffer { continuation?.yield(sb) }
        }
    }
}
