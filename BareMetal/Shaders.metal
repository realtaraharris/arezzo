//
//  Shaders.metal
//  BareMetal
//
//  Created by Max Harris on 6/26/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

fragment half4 basic_fragment(float4 params[[stage_in]])
{
    return half4(1.0);
}

vertex float4 basic_vertex(
   const device packed_float3* vertex_array[[buffer(0)]],
   unsigned int vid[[vertex_id]]
) {
    return float4(vertex_array[vid], 1.0);
}
