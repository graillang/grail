// triangle.vs.hlsl - a vertex stage that reads attributes, for the real draw path.
//
// fullscreen.vs generates its vertices from SV_VertexID and binds no vertex buffer. This one takes
// two attributes from a real vertex buffer, which is what makes a pipeline exercise the vertex
// input state, the vertex buffer binding and the index buffer.
//
// POSITION is float2 so it maps to GR_FORMAT_R32G32_FLOAT; z comes from a push constant and w is 1,
// so the triangle lands in clip space directly.
struct GrailTriangleIn
{
    float2 position : POSITION;
    float4 colour   : COLOR0;
};

struct GrailTriangleOut
{
    float4 position : SV_Position;
    float4 colour   : COLOR0;
};

// Clip-space z for this draw. Reverse-Z means 1 is the near plane and 0 the far plane, so a larger
// value occludes a smaller one under GREATER_OR_EQUAL. Kept in a push constant rather than in the
// vertex buffer so one buffer can be drawn at two depths and the depth test alone decides the
// ordering.
struct GrailTrianglePush
{
    float depth_z;
};

[[vk::push_constant]] ConstantBuffer<GrailTrianglePush> g_push : register(b0);

GrailTriangleOut main(GrailTriangleIn input)
{
    GrailTriangleOut output;
    output.position = float4(input.position, g_push.depth_z, 1.0);
    output.colour = input.colour;
    return output;
}
