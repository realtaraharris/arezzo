//
//  Shaders.metal
//  BareMetal
//
//  Created by Max Harris on 6/26/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position[[position]];
    float4 color;
};

struct Uniforms {
    float width;
    float height;
    float4x4 modelViewMatrix;
};

struct Beep {
    float2 pointA [[attribute(0)]];
    float2 pointB [[attribute(1)]];
};

float2 screenSpaceToMetalSpace (float2 position, float width, float height) {
    return float2(
        (2.0f * position.x / width) - 2.0,
        (-2.0f * position.y / height) + 2.0f
    );
}

vertex VertexOut segment_vertex(
    constant packed_float2* vertex_array[[buffer(0)]],
    constant float4 *colors[[buffer(1)]],
    constant Uniforms &uniforms[[buffer(2)]],
    constant packed_float2 *points[[buffer(3)]],
    unsigned int vid[[vertex_id]],
    const uint instanceId [[instance_id]]
) {
    VertexOut vo;
    
    const float lineWidth = 5.0; // TODO: move into uniforms

    const float4 color = float4(0.0, 1.0, 0.0, 1.0);
    // colors[instanceId];
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

vertex VertexOut cap_vertex(
    constant packed_float2* vertex_array[[buffer(0)]],
    constant float4 *colors[[buffer(1)]],
    constant Uniforms &uniforms[[buffer(2)]],
    constant packed_float2 *points[[buffer(3)]],
    unsigned int vid[[vertex_id]],
    const uint instanceId [[instance_id]]
) {
    VertexOut vo;

    const float4 color = float4(0.0, 1.0, 0.0, 1.0);
    // colors[instanceId];
    const float2 position = vertex_array[vid];

    float2 point = points[instanceId] + position;

    vo.position = uniforms.modelViewMatrix * float4(screenSpaceToMetalSpace(point, uniforms.width, uniforms.height), 0.0, 1.0);
    vo.color = color;

    return vo;
}

fragment half4 basic_fragment(VertexOut params[[stage_in]])
{
    return half4(params.color);
}
