#include <metal_stdlib>
using namespace metal;

kernel void passthrough(
                        texture2d<float, access::sample> inTexture  [[texture(0)]],
                        texture2d<float, access::write>  outTexture [[texture(1)]],
                        constant int &orientation [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]
                        ) {
    uint outW = outTexture.get_width();
    uint outH = outTexture.get_height();
    
    if (gid.x >= outW || gid.y >= outH) return;
    
    float2 srcSize = float2(inTexture.get_width(), inTexture.get_height());
    float2 dstSize = float2(outW, outH);
    
    float2 dispSize = (orientation < 2)
    ? float2(srcSize.y, srcSize.x)
    : float2(srcSize.x, srcSize.y);
    
    float scale = max(dstSize.x / dispSize.x, dstSize.y / dispSize.y);
    
    float2 dstPx = float2(gid) + 0.5;
    
    float2 dispPx = (dstPx - dstSize * 0.5) / scale + dispSize * 0.5;
    
    float2 srcPx;
    
    switch (orientation) {
        case 0:
            srcPx = float2(dispPx.y, srcSize.y - dispPx.x);
            break;
        case 1:
            srcPx = float2(srcSize.x - dispPx.y, dispPx.x);
            break;
        case 2:
            srcPx = float2(srcSize.x - dispPx.x, srcSize.y - dispPx.y);
            break;
        default:
            srcPx = dispPx;
            break;
    }
    
    float2 uv = srcPx / srcSize;
    
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    outTexture.write(inTexture.sample(s, uv), gid);
}

// New Kernel for OCR Pre-processing
kernel void adaptiveThreshold(
                              texture2d<float, access::read> inTexture [[texture(0)]],
                              texture2d<float, access::write> outTexture [[texture(1)]],
                              uint2 gid [[thread_position_in_grid]]
                              ) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;
    
    // Radius for local mean calculation
    const int radius = 4;
    float sum = 0.0;
    float count = 0.0;
    
    // Local statistics calculation (Mechanical Sympathy: note the memory access patterns)
    for (int i = -radius; i <= radius; i++) {
        for (int j = -radius; j <= radius; j++) {
            uint2 samplePos = uint2(clamp(int(gid.x) + i, 0, int(inTexture.get_width() - 1)),
                                    clamp(int(gid.y) + j, 0, int(inTexture.get_height() - 1)));
            float3 col = inTexture.read(samplePos).rgb;
            sum += dot(col, float3(0.299, 0.587, 0.114)); // Grayscale conversion
            count += 1.0;
        }
    }
    
    float localMean = sum / count;
    float currentPixel = dot(inTexture.read(gid).rgb, float3(0.299, 0.587, 0.114));
    
    // Binarization: Black text (0.0) on White background (1.0)
    float result = (currentPixel < (localMean - 0.02)) ? 0.0 : 1.0;
    outTexture.write(float4(float3(result), 1.0), gid);
}
