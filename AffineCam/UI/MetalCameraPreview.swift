import MetalKit
import SwiftUI
import CoreMedia
import os

struct MetalCameraPreview: UIViewRepresentable {
    let coordinator: Coordinator
    
    func makeCoordinator() -> Coordinator {
        coordinator
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero, device: context.coordinator.renderer.device)
        mtkView.framebufferOnly = false
        mtkView.autoResizeDrawable = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.delegate = context.coordinator
        mtkView.contentMode = .scaleAspectFill
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        let scale = uiView.window?.windowScene?.screen.nativeScale
        ?? uiView.traitCollection.displayScale
        
        let targetSize = CGSize(
            width: uiView.bounds.width * scale,
            height: uiView.bounds.height * scale
        )
        
        if targetSize.width > 0,
           targetSize.height > 0,
           uiView.drawableSize != targetSize {
            uiView.drawableSize = targetSize
        }
    }
    
    final class Coordinator: NSObject, MTKViewDelegate {
        let renderer: CameraPreviewRenderer
        private let logger = Logger(subsystem: "AffineCam", category: "PreviewCoordinator")
        
        init(renderer: CameraPreviewRenderer) {
            self.renderer = renderer
        }
        
        func draw(in view: MTKView) {
            do {
                try renderer.draw(in: view)
            } catch {
                logger.error("Draw failed: \(error.localizedDescription)")
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    }
}
