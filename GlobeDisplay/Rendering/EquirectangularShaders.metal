#include <metal_stdlib>
using namespace metal;

// Must match the Swift-side Uniforms struct in RenderEngine.swift
struct Uniforms {
    float rotationOffset;   // normalized 0.0–1.0
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Generates a full-screen quad from the vertex ID — no vertex buffer needed.
vertex VertexOut equirect_vertex(uint vertexID [[vertex_id]]) {
    // Triangle strip order: bottom-left, bottom-right, top-left, top-right
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };
    // UV origin at top-left (Metal/texel convention)
    float2 uvs[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = uvs[vertexID];
    return out;
}

fragment float4 equirect_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> baseTexture [[texture(0)]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    // address::repeat handles date-line wraparound automatically
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::repeat
    );

    float2 uv = in.texCoord;
    uv.x = uv.x + uniforms.rotationOffset;

    return baseTexture.sample(textureSampler, uv);
}
