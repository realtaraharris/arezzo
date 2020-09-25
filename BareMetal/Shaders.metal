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
//    float2 position [[attribute(0)]];
    float2 pointA [[attribute(0)]];
    float2 pointB [[attribute(1)]];
};

vertex VertexOut basic_vertex(
    constant packed_float2* vertex_array[[buffer(0)]],
    constant float4 *colors[[buffer(1)]],
    constant Uniforms &uniforms[[buffer(2)]],
    constant float2 *points[[buffer(3)]],
    unsigned int vid[[vertex_id]],
    const uint instanceId [[instance_id]]
) {
    VertexOut vo;
    
    const float lineWidth = 0.2; // TODO: move into uniforms

    const float4 color = colors[instanceId];
    const float2 vert = vertex_array[vid];
    const float4 clipPosition(
        (2.0f * vert.x / uniforms.width) - 2.0,
        (-2.0f * vert.y / uniforms.height) + 2.0f,
        0.0f,
        1.0f
    );

    float2 pointA = points[instanceId];
    float2 pointB = points[instanceId + 1];
    float2 xBasis = pointB - pointA;
    float2 yBasis = normalize(float2(-xBasis.y, xBasis.x));
//    float2 point = points.pointA + xBasis * points.position.x + yBasis * lineWidth * points.position.y;
    float2 point = pointA + xBasis * vert.x + yBasis * lineWidth * vert.y;
    vo.position = /* clipPosition * */ float4(pointA.x, pointA.y, pointB.x, pointB.y);
//    vo.position = float4(vert.x, vert.y, 0.0, 1.0);
//    vo.position = uniforms.modelViewMatrix * clipPosition;
    vo.color = color;

    return vo;
}

fragment half4 basic_fragment(VertexOut params[[stage_in]])
{
    return half4(params.color);
}
