enable wgpu_mesh_shader;

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec4<f32>,
}

struct PrimitiveInput {
    @per_primitive @location(1) colorMask: vec4<f32>,
}

@fragment
fn fragment(vertex: VertexOutput, primitive: PrimitiveInput) -> @location(0) vec4<f32> {
    return vertex.position;//vertex.color * primitive.colorMask;
}