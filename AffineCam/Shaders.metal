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
