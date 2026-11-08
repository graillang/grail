// triangle.vs.hlsl - a vertex stage that reads attributes, for the real draw path.
//
// fullscreen.vs generates its vertices from SV_VertexID and binds no vertex buffer. This one takes
// two attributes from a real vertex buffer, which is what makes a pipeline exercise the vertex
// input state, the vertex buffer binding and the index buffer.
//
// POSITION is float2 so it maps to GR_FORMAT_R32G32_FLOAT; z is 0 and w is 1, and the projection is
// the identity, so the triangle lands in clip space directly.
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

GrailTriangleOut main(GrailTriangleIn input)
{
    GrailTriangleOut output;
    output.position = float4(input.position, 0.0, 1.0);
    output.colour = input.colour;
    return output;
}
