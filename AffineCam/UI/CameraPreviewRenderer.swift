import AVFoundation
import MetalKit
import os

/// Owns Metal rendering resources and reads frames from `FrameInbox`.
/// Shared across SwiftUI/MTKView and camera pipeline; mutable frame state lives in `FrameInbox`.
/// `draw(in:)` is MainActor-isolated because it touches `MTKView`.
nonisolated final class CameraPreviewRenderer: @unchecked Sendable {
    private let logger = Logger(subsystem: "AffineCam", category: "CameraPreviewRenderer")
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLComputePipelineState
    let frameInbox = FrameInbox()

    private(set) var device: MTLDevice
    private var textureCache: CVMetalTextureCache

    init(shaderFunctionName: String = "passthrough") throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RendererError.noMetalDevice
        }
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue

        var cache: CVMetalTextureCache?
        let cacheStatus = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        guard cacheStatus == kCVReturnSuccess, let cache else {
            throw RendererError.textureCacheCreationFailed(cacheStatus)
        }
        self.textureCache = cache

        guard let library = device.makeDefaultLibrary(),
            let function = library.makeFunction(name: shaderFunctionName)
        else {
            throw RendererError.shaderFunctionNotFound(shaderFunctionName)
        }

        do {
            self.pipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            throw RendererError.pipelineCreationFailed(error)
        }

        logger.info("CameraPreviewRenderer initialized")
    }

    @MainActor func draw(in view: MTKView) throws {
        guard let drawable = view.currentDrawable else { return }

        guard let sampleBuffer = frameInbox.latest(),
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        var cvTexture: CVMetalTexture?
        let textureStatus = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            imageBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        guard textureStatus == kCVReturnSuccess,
            let cvTexture,
            let inputTexture = CVMetalTextureGetTexture(cvTexture)
        else { throw RendererError.textureCreationFailed(textureStatus) }

        guard let commandBuffer = commandQueue.makeCommandBuffer()
        else { throw RendererError.commandBufferCreationFailed }


        guard let encoder = commandBuffer.makeComputeCommandEncoder()
        else { throw RendererError.commandEncoderCreationFailed }

        var orientationIndex = Self.orientationIndex(
            for: view.window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .portrait
        )
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(drawable.texture, index: 1)
        encoder.setBytes(&orientationIndex, length: MemoryLayout<Int32>.size, index: 0)

        let w = pipelineState.threadExecutionWidth
        let h = max(1, pipelineState.maxTotalThreadsPerThreadgroup / w)

        let threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
        let threadgroups = MTLSize(
            width: (drawable.texture.width + w - 1) / w,
            height: (drawable.texture.height + h - 1) / h,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private static func orientationIndex(for orientation: UIInterfaceOrientation) -> Int32 {
        switch orientation {
        case .portrait:
            return 0
        case .portraitUpsideDown:
            return 1
        case .landscapeLeft:
            return 2
        case .landscapeRight:
            return 3
        default:
            return 0
        }
    }

    enum RendererError: Error, LocalizedError {
        case noMetalDevice
        case commandQueueCreationFailed
        case textureCacheCreationFailed(CVReturn)
        case shaderFunctionNotFound(String)
        case pipelineCreationFailed(Error)
        case textureCreationFailed(CVReturn)
        case commandBufferCreationFailed
        case commandEncoderCreationFailed

        var errorDescription: String? {
            switch self {
            case .noMetalDevice:
                return "Metal is not available on this device."
            case .commandQueueCreationFailed:
                return "Failed to create Metal command queue."
            case .textureCacheCreationFailed(let status):
                return "Failed to create CVMetalTextureCache. Status: \(status)"
            case .shaderFunctionNotFound(let name):
                return "Metal shader function '\(name)' was not found."
            case .pipelineCreationFailed(let error):
                return "Failed to create compute pipeline: \(error.localizedDescription)"
            case .textureCreationFailed(let status):
                return "Failed to create Metal texture from camera frame. Status: \(status)"
            case .commandBufferCreationFailed:
                return "Failed to create Metal command buffer."
            case .commandEncoderCreationFailed:
                return "Failed to create Metal compute command encoder."
            }
        }
    }
}
