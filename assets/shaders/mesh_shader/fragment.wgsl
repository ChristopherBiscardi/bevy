enable wgpu_mesh_shader;


struct ColorGrading {
    balance: mat3x3<f32>,
    saturation: vec3<f32>,
    contrast: vec3<f32>,
    gamma: vec3<f32>,
    gain: vec3<f32>,
    lift: vec3<f32>,
    midtone_range: vec2<f32>,
    exposure: f32,
    hue: f32,
    post_saturation: f32,
}

struct View {
    clip_from_world: mat4x4<f32>,
    unjittered_clip_from_world: mat4x4<f32>,
    world_from_clip: mat4x4<f32>,
    world_from_view: mat4x4<f32>,
    view_from_world: mat4x4<f32>,
    // Typically a column-major right-handed projection matrix, one of either:
    //
    // Perspective (infinite reverse z)
    // ```
    // f = 1 / tan(fov_y_radians / 2)
    //
    // ⎡ f / aspect  0   0     0 ⎤
    // ⎢          0  f   0     0 ⎥
    // ⎢          0  0   0  near ⎥
    // ⎣          0  0  -1     0 ⎦
    // ```
    //
    // Orthographic
    // ```
    // w = right - left
    // h = top - bottom
    // d = far - near
    // cw = -right - left
    // ch = -top - bottom
    //
    // ⎡ 2 / w      0      0   cw / w ⎤
    // ⎢     0  2 / h      0   ch / h ⎥
    // ⎢     0      0  1 / d  far / d ⎥
    // ⎣     0      0      0        1 ⎦
    // ```
    //
    // `clip_from_view[3][3] == 1.0` is the standard way to check if a projection is orthographic
    //
    // Wgsl matrices are column major, so for example getting the near plane of a perspective projection is `clip_from_view[3][2]`
    //
    // Custom projections are also possible however.
    clip_from_view: mat4x4<f32>,
    view_from_clip: mat4x4<f32>,
    world_position: vec3<f32>,
    exposure: f32,
    // viewport(x_origin, y_origin, width, height)
    viewport: vec4<f32>,
    main_pass_viewport: vec4<f32>,
    // 6 world-space half spaces (normal: vec3, distance: f32) ordered left, right, top, bottom, near, far.
    // The normal vectors point towards the interior of the frustum.
    // A half space contains `p` if `normal.dot(p) + distance > 0.`
    frustum: array<vec4<f32>, 6>,
    color_grading: ColorGrading,
    mip_bias: f32,
    frame_count: u32,
};


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

struct Globals {
    // The time since startup in seconds
    // Wraps to 0 after 1 hour.
    time: f32,
    // The delta time since the previous frame in seconds
    delta_time: f32,
    // Frame count since the start of the app.
    // It wraps to zero when it reaches the maximum value of a u32.
    frame_count: u32,
};

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

struct Output {
    @location(0) color: vec4<f32>,
    @builtin(frag_depth) frag_depth: f32
}
@fragment
fn fragment(vertex: VertexOutput, primitive: PrimitiveInput) -> Output {
    var output: Output;
    output.color = vec4(vertex.uv, 0.,1.);
    // output.color = vec4(vertex.normal,1.);
    output.frag_depth = vertex.position.z;
    return output;
}