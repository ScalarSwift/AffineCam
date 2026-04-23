import CoreMedia
import MetalKit
import SwiftUI

struct MetalView: UIViewRepresentable {
    let frame: CMSampleBuffer?
    
    func makeUIView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("This device does not support Metal")
        }
        
        let mtkView = MTKView()
        mtkView.device = device
        mtkView.framebufferOnly = false
        mtkView.autoResizeDrawable = false
        mtkView.contentMode = .scaleAspectFill
        mtkView.delegate = context.coordinator
        
        context.coordinator.setup(device: device)
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.enqueue(frame: frame)
        
        let scale = uiView.window?.windowScene?.screen.nativeScale
        ?? uiView.traitCollection.displayScale
        let targetSize = CGSize(
            width: uiView.bounds.width * scale,
            height: uiView.bounds.height * scale
        )
        
        if uiView.drawableSize != targetSize, targetSize.width > 0, targetSize.height > 0 {
            uiView.drawableSize = targetSize
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var currentFrame: CMSampleBuffer?
        
        private var commandQueue: MTLCommandQueue?
        private var textureCache: CVMetalTextureCache?
        private var pipelineState: MTLComputePipelineState?
        
        func setup(device: MTLDevice) {
            guard commandQueue == nil else { return }
            
            commandQueue = device.makeCommandQueue()
            CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
            
            let library = device.makeDefaultLibrary()
            if let function = library?.makeFunction(name: "passthrough") {
                pipelineState = try? device.makeComputePipelineState(function: function)
            }
        }
        
        func enqueue(frame: CMSampleBuffer?) {
            currentFrame = frame
        }
        
        func draw(in view: MTKView) {
            guard
                let buffer = currentFrame,
                let imageBuffer = CMSampleBufferGetImageBuffer(buffer),
                let drawable = view.currentDrawable,
                let pipeline = pipelineState,
                let queue = commandQueue,
                let cache = textureCache
            else { return }
            
            let uiOrientation = view.window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .portrait
            var orientationIndex: Int32
            
            switch uiOrientation {
                case .portrait:
                    orientationIndex = 0
                case .portraitUpsideDown:
                    orientationIndex = 1
                case .landscapeLeft:
                    orientationIndex = 2
                case .landscapeRight:
                    orientationIndex = 3
                default:
                    orientationIndex = 0
            }
            
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            
            var cvTexture: CVMetalTexture?
            let status = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                cache,
                imageBuffer,
                nil,
                .bgra8Unorm,
                width,
                height,
                0,
                &cvTexture
            )
            
            guard
                status == kCVReturnSuccess,
                let cvTexture,
                let inTexture = CVMetalTextureGetTexture(cvTexture),
                let commandBuffer = queue.makeCommandBuffer(),
                let encoder = commandBuffer.makeComputeCommandEncoder()
            else { return }
            
            let outTexture = drawable.texture
            
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(inTexture, index: 0)
            encoder.setTexture(outTexture, index: 1)
            encoder.setBytes(&orientationIndex, length: MemoryLayout<Int32>.size, index: 0)
            
            let w = pipeline.threadExecutionWidth
            let h = max(1, pipeline.maxTotalThreadsPerThreadgroup / w)
            let threadsPerGroup = MTLSize(width: w, height: h, depth: 1)
            let threadgroups = MTLSize(
                width: (outTexture.width + w - 1) / w,
                height: (outTexture.height + h - 1) / h,
                depth: 1
            )
            
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    }
}
