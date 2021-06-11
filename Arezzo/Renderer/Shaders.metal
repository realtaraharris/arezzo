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
    float4x4 modelViewMatrix;
    float aspectRatio;
};

vertex VertexOut line_segment_vertex(
    constant packed_float2 *segment_vertices[[buffer(0)]],
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
    const float2 position = segment_vertices[vid];

    float2 pointA = points[instanceId];
    float2 pointB = points[instanceId + 1];
    float2 xBasis = pointB - pointA;
    float2 yBasis = normalize(float2(-xBasis.y, xBasis.x));
    yBasis.y = yBasis.y * uniforms.aspectRatio;
    float2 point = pointA + xBasis * position.x + yBasis * position.y;

    vo.position = uniforms.modelViewMatrix * float4(point[0], point[1], 0.0, 1.0);
    vo.color = color;

    return vo;
}

vertex VertexOut line_cap_vertex(
    constant packed_float2 *circle_vertices[[buffer(0)]],
    constant float4 *colors[[buffer(1)]],
    constant Uniforms &uniforms[[buffer(2)]],
    constant packed_float2 *line_points[[buffer(3)]],
    constant float *widths[[buffer(4)]],
    unsigned int vid[[vertex_id]],
    const uint instanceId [[instance_id]]
) {
    VertexOut vo;

    const float lineWidth = widths[0];
    const float4 color = colors[0];
    float2 position = circle_vertices[vid];
    position.y *= uniforms.aspectRatio;

    float2 point = line_points[instanceId] + position;

    vo.position = uniforms.modelViewMatrix * float4(point[0], point[1], 0.0, 1.0);
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

typedef struct {
    float4 position [[position]];
    float2 textureCoordinate;
} PortalRasterizerData;

vertex PortalRasterizerData portal_vertex(
    constant PortalVertex *vertexArray [[buffer(0)]],
    constant Uniforms &uniforms[[buffer(2)]],
    uint vertexID [[vertex_id]]
){
    PortalRasterizerData out;

    float2 point = vertexArray[vertexID].position.xy;
    out.position = uniforms.modelViewMatrix * float4(point[0], point[1], 0.0, 1.0);
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;

    return out;
}

fragment float4 portal_fragment(
    PortalRasterizerData in [[stage_in]],
    texture2d<half> colorTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    const half4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);

    return float4(colorSample);
}
