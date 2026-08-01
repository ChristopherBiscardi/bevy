import bevy_render::view::View;
import bevy_render::globals::Globals;

@group(0) @binding(0) var<uniform> globals: Globals;
@group(0) @binding(1) var<uniform> view: View;

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) normal: vec3<f32>
}

struct PrimitiveInput {
    @per_primitive @location(3) colorMask: vec4<f32>,
}