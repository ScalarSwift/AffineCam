import Metal

protocol MetalFilter {
    var label: String { get }
    func encode(
        to commandBuffer: MTLCommandBuffer,
        inputTexture: MTLTexture,
        outputTexture: MTLTexture
    )
}
