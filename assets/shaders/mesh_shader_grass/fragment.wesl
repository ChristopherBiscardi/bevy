import super::{
    bindings::{view, globals, VertexOutput},
    noise::perlin_noise_2d
};

enable wgpu_mesh_shader;

/// Convert ndc depth to linear view z.
/// Note: Depth values in front of the camera will be negative as -z is forward
fn depth_ndc_to_view_z(ndc_depth: f32, clip_from_view: mat4x4<f32>, view_from_clip: mat4x4<f32>) -> f32 {
// #ifdef VIEW_PROJECTION_PERSPECTIVE
    return -perspective_camera_near(clip_from_view) / ndc_depth;
// #else ifdef VIEW_PROJECTION_ORTHOGRAPHIC
//     return -(clip_from_view[3][2] - ndc_depth) / clip_from_view[2][2];
// #else
//     let view_pos = view_from_clip * vec4(0.0, 0.0, ndc_depth, 1.0);
//     return view_pos.z / view_pos.w;
// #endif
}

fn perspective_camera_near(clip_from_view: mat4x4<f32>) -> f32 {
    return clip_from_view[3][2];
}

struct PrimitiveInput {
    @per_primitive @location(4) colorMask: vec4<f32>,
    @builtin(front_facing) front_facing: bool
}

struct Output {
    @location(0) color: vec4<f32>,
    @builtin(frag_depth) frag_depth: f32
}

@fragment
fn fragment(vertex: VertexOutput, primitive: PrimitiveInput) -> Output {
    // return vertex.position;//vertex.color * primitive.colorMask;
    var output: Output;
    // output.color = vec4(vertex.uv, 0.,1.);
    // output.color = vec4(vertex.normal,1.);
    let self_shadow: f32 = clamp(pow((vertex.world_position.y - vertex.root_height) / vertex.height, 1.5), 0, 1);
    let rgb = pow(vec3f(0.41, 0.44, 0.29), vec3f(2.2)) * self_shadow;
    let rgb_mul = rgb * vec3(0.75) + vec3(0.25 * perlin_noise_2d(0.25 * vertex.world_position.xy));
    output.color = vec4(rgb_mul, 1.);

    // var normal: vec3f = normalize(vertex.world_normal);

    // if (!primitive.front_facing) {
    //     normal = -normal;
    // }

    // output.normal.xyz = normalize(mix(vec3f(0., 0., 1.), normal, 0.25));

    // output.color = vec4(1., 0., 1., 1.);
    output.frag_depth = vertex.position.z;
    return output;
}


