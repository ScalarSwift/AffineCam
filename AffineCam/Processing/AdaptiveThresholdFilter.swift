import Metal

nonisolated struct AdaptiveThresholdFilter: MetalFilter {
    let label = "AdaptiveThreshold"
    private let pipelineState: MTLComputePipelineState

    init(device: MTLDevice) throws {
        guard let library = device.makeDefaultLibrary(),
            let function = library.makeFunction(name: "adaptiveThreshold")
        else {
            throw NSError(
                domain: "MetalFilter",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "KernelNotFound"]
            )
        }
        self.pipelineState = try device.makeComputePipelineState(function: function)
    }

    func encode(
        to commandBuffer: any MTLCommandBuffer,
        inputTexture: any MTLTexture,
        outputTexture: any MTLTexture
    ) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(outputTexture, index: 1)

        let w = pipelineState.threadExecutionWidth
        let h = max(1, pipelineState.maxTotalThreadsPerThreadgroup / w)
        let threadsPerThreadGroup = MTLSize(width: w, height: h, depth: 1)
        let threadgroups = MTLSize(
            width: (outputTexture.width + w - 1) / w,
            height: (outputTexture.height + h - 1) / h,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadGroup)
        encoder.endEncoding()
    }
}
