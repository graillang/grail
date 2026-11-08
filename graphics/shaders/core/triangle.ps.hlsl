// triangle.ps.hlsl - passes the interpolated vertex colour through.
//
// The point is not the colour: it is that the value reaching the target is a blend of the three
// vertex colours, so the readback proves the vertex buffer, the index buffer and the rasteriser all
// did their job rather than the clear colour surviving.
struct GrailTriangleIn
{
    float4 position : SV_Position;
    float4 colour   : COLOR0;
};

float4 main(GrailTriangleIn input) : SV_Target
{
    return input.colour;
}
