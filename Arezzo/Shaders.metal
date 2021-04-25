//
//  Shaders.metal
//  Arezzo
//
//  Created by Max Harris on 6/26/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - line shaders

struct VertexOut {
    float4 position[[position]];
    float4 color;
};

struct Uniforms {
    float width;
    float height;
    float4x4 modelViewMatrix;
};

float2 screenSpaceToMetalSpace (float2 position, float width, float height) {
    return float2(
        (2.0f * position.x / width) - 2.0f,
        (-2.0f * position.y / height) + 2.0f
    );
}

vertex VertexOut line_segment_vertex(
    constant packed_float2 *vertex_array[[buffer(0)]],
    constant float4 *colors[[buffer(1)]],
    constant Uniforms &uniforms[[buffer(2)]],
    constant packed_float2 *points[[buffer(3)]],
    constant float *widths[[buffer(4)]],
    unsigned int vid[[vertex_id]],
    const uint instanceId [[instance_id]]
) {
    VertexOut vo;
    
    const float lineWidth = widths[0];

    const float4 color = colors[0];
    const float2 position = vertex_array[vid];

    float2 pointA = points[instanceId];
    float2 pointB = points[instanceId + 1];
    float2 xBasis = pointB - pointA;
    float2 yBasis = normalize(float2(-xBasis.y, xBasis.x));
    float2 point = pointA + xBasis * position.x + yBasis * lineWidth * position.y;

    vo.position = uniforms.modelViewMatrix * float4(screenSpaceToMetalSpace(point, uniforms.width, uniforms.height), 0.0, 1.0);
    vo.color = color;

    return vo;
}

vertex VertexOut line_cap_vertex(
    constant packed_float2 *vertex_array[[buffer(0)]],
    constant float4 *colors[[buffer(1)]],
    constant Uniforms &uniforms[[buffer(2)]],
    constant packed_float2 *points[[buffer(3)]],
    constant float *widths[[buffer(4)]],
    unsigned int vid[[vertex_id]],
    const uint instanceId [[instance_id]]
) {
    VertexOut vo;

    const float lineWidth = widths[0];
    const float4 color = colors[0];
    const float2 position = vertex_array[vid];

    float2 point = points[instanceId] + position * lineWidth;

    vo.position = uniforms.modelViewMatrix * float4(screenSpaceToMetalSpace(point, uniforms.width, uniforms.height), 0.0, 1.0);
    vo.color = color;

    return vo;
}

fragment half4 line_fragment(VertexOut params[[stage_in]])
{
    return half4(params.color);
}

// MARK: - portal shaders

typedef struct {
    vector_float2 position;
    vector_float2 textureCoordinate;
} PortalVertex;

typedef enum PortalVertexInputIndex {
    PortalVertexInputIndexVertices = 0,
    PortalVertexInputIndexViewportSize = 1,
} PortalVertexInputIndex;

typedef enum PortalTextureIndex {
    PortalTextureIndexBaseColor = 0,
} PortalTextureIndex;

typedef struct {
    float4 position [[position]];
    float2 textureCoordinate;
} PortalRasterizerData;

vertex PortalRasterizerData portal_vertex(uint vertexID [[vertex_id]],
             constant PortalVertex *vertexArray [[ buffer(PortalVertexInputIndexVertices)]],
             constant vector_uint2 * viewportSizePointer [[ buffer(PortalVertexInputIndexViewportSize) ]]){
    PortalRasterizerData out;
    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = vertexArray[vertexID].position.xy;

    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;

    return out;
}

fragment float4 portal_fragment(PortalRasterizerData in [[ stage_in ]],
                               texture2d<half> colorTexture [[ texture(PortalTextureIndexBaseColor)]]) {
    constexpr sampler textureSampler(mag_filter ::linear,
                                     min_filter :: linear);

    const half4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);

    return float4(colorSample);
}
