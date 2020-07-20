//
//  Shaders.metal
//  BareMetal
//
//  Created by Max Harris on 6/26/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// CubicBezierParameters represent a per-curve buffer specifying curve parameters. Note that
// even though the vertex shader is obviously called per-vertex, it actually uses the same
// BezierParameters instance (identified through the instance_id) for all vertexes in a given
// curve.
struct CubicBezierParameters
{
    float2 a;
    float2 b;
    float2 p1;
    float2 p2;
    float lineThickness;
    float4 color;
    int ts;
    int elementsPerInstance;
};

// QuadraticBezierParameters represent a per-curve buffer specifying curve parameters. Note that
// even though the vertex shader is obviously called per-vertex, it actually uses the same
// BezierParameters instance (identified through the instance_id) for all vertexes in a given
// curve.
struct QuadraticBezierParameters
{
    float2 a;
    float2 b;
    float2 p;
    float lineThickness;
    float4 color;
    int ts;
    int elementsPerInstance;
};

struct VertexInOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexInOut bezier_vertex_quadratic(
    const device packed_float3* vertex_array[[buffer(0)]],
    constant QuadraticBezierParameters *allParams[[buffer(1)]],
    uint vertexId [[vertex_id]]
) {
    QuadraticBezierParameters params = allParams[vertexId];
    float t = params.elementsPerInstance;
    
    // This is a little trick to avoid conditional code. We need to determine which side of the
    // triangle we are processing, so as to calculate the correct "side" of the curve, so we just
    // check for odd vs. even vertexId values to determine that:
    float lineWidth = (1 - (((float) (vertexId % 2)) * 2.0)) * params.lineThickness;
    
    float2 a = params.a;
    float2 b = params.b;
    float2 p = params.p;

    float nt = 1.0f - t;
    float nt_2 = nt * nt;
    float t_2 = t * t;

    // quadratic:
    // B(t) =
    //   (1-t)^2 * P0 +               ... nt_2 * a
    //   2 * (1-t) * t * P1 +         ... 2 * nt * t * p
    //   t^2 * P2                     ... t_2 * b
    // where 0 < t < 1
    float2 point = nt_2 * a + 2 * nt * t * p + t_2 * b;

    // for quadratic   f(t) = a(1-t)^2 + 2b(1-t)t+ct^2
    //                      = a+2(-a+b)t+(a-2b+c)t^2
    // The derivative f'(t) =  2(1-t)(b-a)+2(c-b)t

    // Calculate the tangent so we can produce a triangle (to achieve a line width greater than 1):
    float2 tangent = 2 * nt * (b-a) + 2 * (p-b) * t;
    tangent = normalize(float2(tangent.y, tangent.x));

    VertexInOut vo;

//    vo.pos.x = a.x;
//    vo.pos.y = a.y;
//    vo.pos.z = 0;
//    vo.pos.w = 0;
//    vo.color = (0.0, 1.0, 1.0, 1.0);

    // Combine the point with the tangent and lineWidth to achieve a properly oriented
    // triangle for this point in the curve:
    vo.position.xy = point + (tangent * (lineWidth / 2.0f));
    vo.position.zw = float2(0, 1);
    vo.color = params.color;

    return vo;
}

/*
vertex VertexOut bezier_vertex_cubic(constant CubicBezierParameters *allParams[[buffer(0)]],
                               uint vertexId [[vertex_id]])
{
    CubicBezierParameters params = allParams[vertexId];
    float t = params.elementsPerInstance;

    // This is a little trick to avoid conditional code. We need to determine which side of the
    // triangle we are processing, so as to calculate the correct "side" of the curve, so we just
    // check for odd vs. even vertexId values to determine that:
    float lineWidth = (1 - (((float) (vertexId % 2)) * 2.0)) * params.lineThickness;
    
    float2 a = params.a;
    float2 b = params.b;
    
    // We premultiply several values though I doubt it actually does anything performance-wise:
    float2 p1 = params.p1 * 3.0;
    float2 p2 = params.p2 * 3.0;
    
    float nt = 1.0f - t;

    float nt_2 = nt * nt;
    float nt_3 = nt_2 * nt;
    
    float t_2 = t * t;
    float t_3 = t_2 * t;
    
    // cubic:
    // B(t) =
    //   (1-t)^3 * P0 +               ... nnt
    //   3 * (1-t)^2 * t * P1 +
    //   3 * (1-t) * t^2 * P2 +
    //   t^3 * P3
    // where 0 < t < 1
    
    // Calculate a single point in this Bezier curve:
    float2 point = a * nt_3 + p1 * nt_2 * t + p2 * nt * t_2 + b * t_3;
    
    // Calculate the tangent so we can produce a triangle (to achieve a line width greater than 1):
    float2 tangent = -3.0 * a * nt_2 + p1 * (1.0 - 4.0 * t + 3.0 * t_2) + p2 * (2.0 * t - 3.0 * t_2) + 3 * b * t_2;

    tangent = normalize(float2(-tangent.y, tangent.x));
    
    VertexOut vo;
    
    // Combine the point with the tangent and lineWidth to achieve a properly oriented
    // triangle for this point in the curve:
    vo.pos.xy = point + (tangent * (lineWidth / 2.0f));
    vo.pos.zw = float2(0, 1);
    vo.color = params.color;
    
    return vo;
}
*/

fragment half4 bezier_fragment(VertexInOut params[[stage_in]])
{
    return half4(params.color);
}

vertex VertexInOut basic_vertex(
   const device packed_float3* vertex_array[[buffer(0)]],
   unsigned int vid[[vertex_id]]
) {
//    return float4(vertex_array[vid], 1.0);
    VertexInOut outVertex;
    outVertex.position = float4(vertex_array[vid], 1.0);
    outVertex.color = float4(1.0, 0.0, 0.0, 1.0); //color[vid];
    return outVertex;
}

fragment half4 quadratic_basic_fragment(
    constant QuadraticBezierParameters *allParams[[buffer(0)]]
) {
    QuadraticBezierParameters params = allParams[0];

    float2 a = params.a;
    float2 b = params.b;
    float2 p = params.p;
    
    return half4(a.xy); // half4(1.0);
}

//fragment half4 cubic_basic_fragment(
//    float4 coords[[stage_in]],
//    constant CubicBezierParameters *allParams[[buffer(0)]]
//) {
//    float4 params = allParams[0];
//
//    float x = coords.x;
//    float y = coords.y;


fragment half4 cubic_basic_fragment(
    VertexInOut asdf[[stage_in]],
    constant CubicBezierParameters *allParams[[buffer(0)]]
) {
    CubicBezierParameters params = allParams[0];
    
    float fudge = -25;

    float minX = 540 + fudge;
    float maxX = 1000 - fudge;
    
    float minY = 99 + 0;
    float maxY = 398 - 0;
    
    float x = (asdf.position.x - minX)/(maxX - minX);
    float y = 1 - (asdf.position.y - minY)/(maxY - minY);
    
//    float x = asdf.position.x; // 844 -> 1684
//    float y = asdf.position.y; // 135 -> 530
    
//    return half4(x, 0.0,  0.0, 1.0);
    
//    if (x < 0 || x > 1) {
//        return half4(0.0 , 1.0 , 0.0, 1.0);  // return green
//    } else {
//        return half4(0.0, 0.0 , 1.0, 1.0);  // return blue
//    }

    float2 p = params.a;
    float2 q = params.b;
    float2 r = params.p1;
    float2 s = params.p2;
    
    float l2 = - (- p.y + 3 * q.y - 3 * r.y + s.y);
    float l1 = - (2 * p.y - 4 * q.y + 2 * r.y);
    float l0 = - (- p.y + q.y);

    float m2 = - p.x + 3 * q.x - 3 * r.x + s.x;
    float m1 = 2 * p.x - 4 * q.x + 2 * r.x;
    float m0 = - p.x + q.x;

    float u02 = - p.x - 2 * q.x + r.x;
    float u01 = - 2 * p.x + 2 * q.x;
    float u00 = p.x;
    
    float lu04 = l2 * u02;
    float lu03 = l1 * u02 + l2 * u01;
    float lu02 = l2 * u00 + l1 * u01 + l0 * u02;
    float lu01 = l0 * u01 + l1 * u00;
    float lu00 = l0 * u00;

    float u12 = - p.y - 2 * q.y + r.y;
    float u11 = - 2 * p.y + 2 * q.y;
    float u10 = p.y;
    
    float mu14 = m2 * u12;
    float mu13 = m1 * u12 + m2 * u11;
    float mu12 = m2 * u10 + m1 * u11 + m0 * u12;
    float mu11 = m0 * u11 + m1 * u10;
    float mu10 = m0 * u10;

    float a = - (lu04 + mu14);
    float b = (- (lu03 + mu13)) / a;
    float c = (l2 * x + m2 * y - (lu02 + mu12)) / a;
    float d = (l1 * x + m1 * y - (lu01 + mu11)) / a;
    float e = (l0 * x + m0 * y - (lu00 + mu10)) / a;
    
    float bb = b * b;
    float bbb = bb * b;
    float bbbb = bb * bb;
    float cc = c * c;
    float ccc = cc * c;
    float cccc = cc * cc;
    float dd = d * d;
    float ddd = dd * d;
    float dddd = dd * dd;
    float ee = e * e;
    float eee = ee * e;
    
    float D = - 108 * dd + 108 * b * c * d - 27 * bbb * d - 32 * ccc + 9 * bb * cc;
    float P = - 768 * e + 192 * b * d + 128 * cc - 144 * bb * c + 27 * bbbb;
    float Q = (384 * ee - 192 * b * d * e - 128 * cc * e + 144 * bb * c * e - 27 * bbbb * e
               + 72 * c * dd - 3 * bb * dd - 40 * b * cc * d + 9 * bbb * c * d + 8 * cccc
               - 2 * bb * ccc);
    float R = (- 256 * eee + 192 * b * d * ee + 128 * cc * ee - 144 * bb * c * ee
               + 27 * bbbb * ee - 144 * c * dd * e + 6 * bb * dd * e + 80 * b * cc * d * e
               - 18 * bbb * c * d * e -16 * cccc * e + 4 * bb * ccc * e + 27 * dddd - 18 * b * c * ddd
               + 4 * bbb * ddd + 4 * ccc * dd - bb * cc * dd);
    
    bool flag = !(R >= 0) && !(D >= 0 && (P >= 0 || Q <= 0));
    half red = flag;
    half green = flag ? x : 1;
    half blue = flag ? 0 : y;
    half4 colorSample   = {red, green, blue, 1};
    
    return half4(colorSample);
//    return half4(1.0);
    
//    return half4(a.xy); // half4(1.0);
}

/*
fragment float4 cubic_fragmentShader(
   ColorInOut in [[stage_in]],
   constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]]
//   texture2d<half> colorMap     [[ texture(TextureIndexColor) ]]
) {
    half x = in.texCoord.xy[0];
    half y = in.texCoord.xy[1];

    // Bezier
    float2 p = uniforms.bezierParams.points[0];
    float2 q = uniforms.bezierParams.points[1];
    float2 r = uniforms.bezierParams.points[2];
    float2 s = uniforms.bezierParams.points[3];
    
    float l2 = - (- p.y + 3 * q.y - 3 * r.y + s.y);
    float l1 = - (2 * p.y - 4 * q.y + 2 * r.y);
    float l0 = - (- p.y + q.y);

    float m2 = - p.x + 3 * q.x - 3 * r.x + s.x;
    float m1 = 2 * p.x - 4 * q.x + 2 * r.x;
    float m0 = - p.x + q.x;

    float u02 = - p.x - 2 * q.x + r.x;
    float u01 = - 2 * p.x + 2 * q.x;
    float u00 = p.x;
    
    float lu04 = l2 * u02;
    float lu03 = l1 * u02 + l2 * u01;
    float lu02 = l2 * u00 + l1 * u01 + l0 * u02;
    float lu01 = l0 * u01 + l1 * u00;
    float lu00 = l0 * u00;

    float u12 = - p.y - 2 * q.y + r.y;
    float u11 = - 2 * p.y + 2 * q.y;
    float u10 = p.y;
    
    float mu14 = m2 * u12;
    float mu13 = m1 * u12 + m2 * u11;
    float mu12 = m2 * u10 + m1 * u11 + m0 * u12;
    float mu11 = m0 * u11 + m1 * u10;
    float mu10 = m0 * u10;

    float a = - (lu04 + mu14);
    float b = (- (lu03 + mu13)) / a;
    float c = (l2 * x + m2 * y - (lu02 + mu12)) / a;
    float d = (l1 * x + m1 * y - (lu01 + mu11)) / a;
    float e = (l0 * x + m0 * y - (lu00 + mu10)) / a;
    
    float bb = b * b;
    float bbb = bb * b;
    float bbbb = bb * bb;
    float cc = c * c;
    float ccc = cc * c;
    float cccc = cc * cc;
    float dd = d * d;
    float ddd = dd * d;
    float dddd = dd * dd;
    float ee = e * e;
    float eee = ee * e;
    
    float D = - 108 * dd + 108 * b * c * d - 27 * bbb * d - 32 * ccc + 9 * bb * cc;
    float P = - 768 * e + 192 * b * d + 128 * cc - 144 * bb * c + 27 * bbbb;
    float Q = (384 * ee - 192 * b * d * e - 128 * cc * e + 144 * bb * c * e - 27 * bbbb * e
               + 72 * c * dd - 3 * bb * dd - 40 * b * cc * d + 9 * bbb * c * d + 8 * cccc
               - 2 * bb * ccc);
    float R = (- 256 * eee + 192 * b * d * ee + 128 * cc * ee - 144 * bb * c * ee
               + 27 * bbbb * ee - 144 * c * dd * e + 6 * bb * dd * e + 80 * b * cc * d * e
               - 18 * bbb * c * d * e -16 * cccc * e + 4 * bb * ccc * e + 27 * dddd - 18 * b * c * ddd
               + 4 * bbb * ddd + 4 * ccc * dd - bb * cc * dd);

    bool flag = !(R >= 0) && !(D >= 0 && (P >= 0 || Q <= 0));
    half red = flag;
    half green = flag ? x : 1;
    half blue = flag ? 0 : y;
    half4 colorSample   = {red, green, blue, 1};
    
    return float4(colorSample);
}
*/
