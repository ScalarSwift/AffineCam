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
    
    float2 srcSize = float2(inTexture.get_width(), inTexture.get_height());   // actual buffer size
    float2 dstSize = float2(outW, outH);                                      // drawable size
    
    // Size of the image as displayed after orientation is applied
    float2 dispSize = (orientation < 2)
    ? float2(srcSize.y, srcSize.x)   // portrait / upside-down portrait
    : float2(srcSize.x, srcSize.y);  // landscapes
    
    // Aspect-fill scale in PIXEL SPACE
    float scale = max(dstSize.x / dispSize.x, dstSize.y / dispSize.y);
    
    // Current output pixel in centered destination-pixel coordinates
    float2 dstPx = float2(gid) + 0.5;
    
    // Map output pixel -> displayed-image pixel coordinates
    float2 dispPx = (dstPx - dstSize * 0.5) / scale + dispSize * 0.5;
    
    // Convert displayed-image pixel coordinates -> source-texture pixel coordinates
    float2 srcPx;
    
    switch (orientation) {
        case 0: // portrait
            // displayed size = (srcH, srcW)
            srcPx = float2(dispPx.y, srcSize.y - dispPx.x);
            break;
            
        case 1: // portrait upside down
            srcPx = float2(srcSize.x - dispPx.y, dispPx.x);
            break;
            
        case 2: // landscape left
            srcPx = float2(srcSize.x - dispPx.x, srcSize.y - dispPx.y);
            break;
            
        default: // landscape right
            srcPx = dispPx;
            break;
    }
    
    // Convert source pixels -> normalized UV
    float2 uv = srcPx / srcSize;
    
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    outTexture.write(inTexture.sample(s, uv), gid);
}
