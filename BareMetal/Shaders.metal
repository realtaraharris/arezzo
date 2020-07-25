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

//struct QuadraticBezierParameters
//{
//    float4 color;
//};

vertex VertexOut basic_vertex(
    constant packed_float3* vertex_array[[buffer(0)]],
    constant float4 *allParams[[buffer(1)]],
    unsigned int vid[[vertex_id]],
    const uint instanceId [[instance_id]]
) {
    VertexOut vo;

    const float4 color = allParams[instanceId];
    float3 vert = vertex_array[vid];
    vo.position.xyzw = float4(vert, 1.0);
    vo.color = color;
    
    return vo;
}

fragment half4 basic_fragment(VertexOut params[[stage_in]])
{
    return half4(params.color);
}
