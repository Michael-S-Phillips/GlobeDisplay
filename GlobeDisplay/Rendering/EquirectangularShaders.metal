#include <metal_stdlib>
using namespace metal;

// Must match the Swift-side Uniforms struct in RenderEngine.swift
struct Uniforms {
    float rotationOffset;      // normalized 0.0–1.0
    float aspectRatio;         // drawableSize.height / drawableSize.width
    float projectionGamma;     // curve shape: 1=equidistant, 2=equisolid; higher = north less scrunched
    float projectionRadius;    // cs-space radius at which south pole appears (default 0.5 = inscribed circle)
    float brightness;          // output brightness multiplier (default 1.0)
    float flipHorizontal;      // 1.0 = mirror east/west (reverse longitude direction)
    float flipVertical;        // 1.0 = flip north/south (invert co-latitude)
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
    texture2d<float> baseTexture    [[texture(0)]],
    texture2d<float> overlayTexture [[texture(1)]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    // The MagicPlanet uses polar azimuthal equidistant projection:
    //   portrait center (0.5, 0.5) → north pole
    //   radial distance r = 0.5 from center → south pole (portrait edge midpoints)
    //   angle around center → longitude:
    //     right  (+x, θ=0)    → front of globe (prime meridian, u=0.5 in SOS)
    //     up     (-y, θ=-π/2) → east  (u=0.75)
    //     left   (-x, θ=±π)   → back  (u=0.0/1.0)
    //     down   (+y, θ=+π/2) → west  (u=0.25)
    //
    // s_address::repeat  — longitude wraps cleanly around the dateline
    // t_address::clamp_to_edge — portrait corners (r > 0.5) clamp to south pole
    //                           rather than repeating northern content
    constexpr sampler polarSampler(
        mag_filter::linear,
        min_filter::linear,
        s_address::repeat,
        t_address::clamp_to_edge
    );

    float2 c = in.texCoord - float2(0.5, 0.5);  // offset from display center

    // The display is non-square, so radius must be computed in physical units.
    // Scale each axis so the inscribed circle (radius = min_dimension/2) maps
    // to co-latitude 1.0 (south pole).  For landscape (W>H): sx > 1, sy = 1.
    // For portrait (H>W): sx = 1, sy > 1.
    float aspect = uniforms.aspectRatio;  // H / W
    float sx = max(1.0, 1.0 / aspect);
    float sy = max(1.0, aspect);
    float2 cs = float2(c.x * sx, c.y * sy);  // aspect-corrected coords

    // Co-latitude (texture V): 0 = north pole, 1 = south pole.
    float lat = pow(min(1.0, length(cs) / uniforms.projectionRadius), uniforms.projectionGamma);
    // Vertical flip: invert the co-latitude mapping.
    if (uniforms.flipVertical > 0.5) { lat = 1.0 - lat; }

    // Longitude (texture U): right = 0.5 (SOS prime meridian at front)
    float theta = atan2(cs.y, cs.x);
    // Horizontal flip: reverse the longitude direction (mirror east/west).
    float lonSign = (uniforms.flipHorizontal > 0.5) ? 1.0 : -1.0;
    float lon = fract(0.5 + lonSign * theta / (2.0 * M_PI_F) + uniforms.rotationOffset);

    // Overlay sampler: clamp both axes — markers don't wrap or repeat.
    constexpr sampler overlaySampler(
        mag_filter::linear,
        min_filter::linear,
        s_address::clamp_to_zero,
        t_address::clamp_to_zero
    );

    float2 uv = float2(lon, lat);
    float4 base    = baseTexture.sample(polarSampler, uv);
    float4 overlay = overlayTexture.sample(overlaySampler, uv);

    // Standard Porter-Duff "over" composite: overlay on top of base.
    float3 composited = mix(base.rgb, overlay.rgb, overlay.a);
    // Apply brightness (clamped to avoid over-saturation).
    composited = clamp(composited * uniforms.brightness, 0.0, 1.0);
    return float4(composited, 1.0);
}
