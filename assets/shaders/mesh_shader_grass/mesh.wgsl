enable wgpu_mesh_shader;

/* bevy imports don't work yet
so this is bevy_render/src/view/view.wgsl
 */
// struct ShaderData {
//     time: f32
// }
// #define_import_path bevy_render::view

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

/// World space:
/// +y is up

/// View space:
/// -z is forward, +x is right, +y is up
/// Forward is from the camera position into the scene.
/// (0.0, 0.0, -1.0) is linear distance of 1.0 in front of the camera's view relative to the camera's rotation
/// (0.0, 1.0, 0.0) is linear distance of 1.0 above the camera's view relative to the camera's rotation

/// NDC (normalized device coordinate):
/// https://www.w3.org/TR/webgpu/#coordinate-systems
/// (-1.0, -1.0) in NDC is located at the bottom-left corner of NDC
/// (1.0, 1.0) in NDC is located at the top-right corner of NDC
/// Z is depth where:
///    1.0 is near clipping plane
///    Perspective projection: 0.0 is inf far away
///    Orthographic projection: 0.0 is far clipping plane

/// Clip space:
/// This is NDC before the perspective divide, still in homogenous coordinate space.
/// Dividing a clip space point by its w component yields a point in NDC space.

/// UV space:
/// 0.0, 0.0 is the top left
/// 1.0, 1.0 is the bottom right


// -----------------
// TO WORLD --------
// -----------------

/// Convert a view space position to world space
fn position_view_to_world(view_pos: vec3<f32>, world_from_view: mat4x4<f32>) -> vec3<f32> {
    let world_pos = world_from_view * vec4(view_pos, 1.0);
    return world_pos.xyz;
}

/// Convert a clip space position to world space
fn position_clip_to_world(clip_pos: vec4<f32>, world_from_clip: mat4x4<f32>) -> vec3<f32> {
    let world_pos = world_from_clip * clip_pos;
    return world_pos.xyz;
}

/// Convert a ndc space position to world space
fn position_ndc_to_world(ndc_pos: vec3<f32>, world_from_clip: mat4x4<f32>) -> vec3<f32> {
    let world_pos = world_from_clip * vec4(ndc_pos, 1.0);
    return world_pos.xyz / world_pos.w;
}

/// Convert a view space direction to world space
fn direction_view_to_world(view_dir: vec3<f32>, world_from_view: mat4x4<f32>) -> vec3<f32> {
    let world_dir = world_from_view * vec4(view_dir, 0.0);
    return world_dir.xyz;
}

/// Convert a clip space direction to world space
fn direction_clip_to_world(clip_dir: vec4<f32>, world_from_clip: mat4x4<f32>) -> vec3<f32> {
    let world_dir = world_from_clip * clip_dir;
    return world_dir.xyz;
}

// -----------------
// TO VIEW ---------
// -----------------

/// Convert a world space position to view space
fn position_world_to_view(world_pos: vec3<f32>, view_from_world: mat4x4<f32>) -> vec3<f32> {
    let view_pos = view_from_world * vec4(world_pos, 1.0);
    return view_pos.xyz;
}

/// Convert a clip space position to view space
fn position_clip_to_view(clip_pos: vec4<f32>, view_from_clip: mat4x4<f32>) -> vec3<f32> {
    let view_pos = view_from_clip * clip_pos;
    return view_pos.xyz;
}

/// Convert a ndc space position to view space
fn position_ndc_to_view(ndc_pos: vec3<f32>, view_from_clip: mat4x4<f32>) -> vec3<f32> {
    let view_pos = view_from_clip * vec4(ndc_pos, 1.0);
    return view_pos.xyz / view_pos.w;
}

/// Convert a world space direction to view space
fn direction_world_to_view(world_dir: vec3<f32>, view_from_world: mat4x4<f32>) -> vec3<f32> {
    let view_dir = view_from_world * vec4(world_dir, 0.0);
    return view_dir.xyz;
}

/// Convert a clip space direction to view space
fn direction_clip_to_view(clip_dir: vec4<f32>, view_from_clip: mat4x4<f32>) -> vec3<f32> {
    let view_dir = view_from_clip * clip_dir;
    return view_dir.xyz;
}

// -----------------
// TO CLIP ---------
// -----------------

/// Convert a world space position to clip space
// fn position_world_to_clip(world_pos: vec3<f32>, clip_from_world: mat4x4<f32>) -> vec4<f32> {
//     let clip_pos = clip_from_world * vec4(world_pos, 1.0);
//     return clip_pos;
// }

/// Convert a view space position to clip space
fn position_view_to_clip(view_pos: vec3<f32>, clip_from_view: mat4x4<f32>) -> vec4<f32> {
    let clip_pos = clip_from_view * vec4(view_pos, 1.0);
    return clip_pos;
}

/// Convert a world space direction to clip space
fn direction_world_to_clip(world_dir: vec3<f32>, clip_from_world: mat4x4<f32>) -> vec4<f32> {
    let clip_dir = clip_from_world * vec4(world_dir, 0.0);
    return clip_dir;
}

/// Convert a view space direction to clip space
fn direction_view_to_clip(view_dir: vec3<f32>, clip_from_view: mat4x4<f32>) -> vec4<f32> {
    let clip_dir = clip_from_view * vec4(view_dir, 0.0);
    return clip_dir;
}

// -----------------
// TO NDC ----------
// -----------------

/// Convert a world space position to ndc space
fn position_world_to_ndc(world_pos: vec3<f32>, clip_from_world: mat4x4<f32>) -> vec3<f32> {
    let ndc_pos = clip_from_world * vec4(world_pos, 1.0);
    return ndc_pos.xyz / ndc_pos.w;
}

/// Convert a view space position to ndc space
fn position_view_to_ndc(view_pos: vec3<f32>, clip_from_view: mat4x4<f32>) -> vec3<f32> {
    let ndc_pos = clip_from_view * vec4(view_pos, 1.0);
    return ndc_pos.xyz / ndc_pos.w;
}

// -----------------
// DEPTH -----------
// -----------------

/// Retrieve the perspective camera near clipping plane
fn perspective_camera_near(clip_from_view: mat4x4<f32>) -> f32 {
    return clip_from_view[3][2];
}

/// Convert ndc depth to linear view z.
/// Note: Depth values in front of the camera will be negative as -z is forward
// fn depth_ndc_to_view_z(ndc_depth: f32, clip_from_view: mat4x4<f32>, view_from_clip: mat4x4<f32>) -> f32 {
// #ifdef VIEW_PROJECTION_PERSPECTIVE
//     return -perspective_camera_near(clip_from_view) / ndc_depth;
// #else ifdef VIEW_PROJECTION_ORTHOGRAPHIC
//     return -(clip_from_view[3][2] - ndc_depth) / clip_from_view[2][2];
// #else
//     let view_pos = view_from_clip * vec4(0.0, 0.0, ndc_depth, 1.0);
//     return view_pos.z / view_pos.w;
// #endif
// }

/// Convert linear view z to ndc depth.
/// Note: View z input should be negative for values in front of the camera as -z is forward
// fn view_z_to_depth_ndc(view_z: f32, clip_from_view: mat4x4<f32>) -> f32 {
// #ifdef VIEW_PROJECTION_PERSPECTIVE
//     return -perspective_camera_near(clip_from_view) / view_z;
// #else ifdef VIEW_PROJECTION_ORTHOGRAPHIC
//     return clip_from_view[3][2] + view_z * clip_from_view[2][2];
// #else
//     let ndc_pos = clip_from_view * vec4(0.0, 0.0, view_z, 1.0);
//     return ndc_pos.z / ndc_pos.w;
// #endif
// }

// -----------------
// UV --------------
// -----------------

/// Convert ndc space xy coordinate [-1.0 .. 1.0] to uv [0.0 .. 1.0]
fn ndc_to_uv(ndc: vec2<f32>) -> vec2<f32> {
    return ndc * vec2(0.5, -0.5) + vec2(0.5);
}

/// Convert uv [0.0 .. 1.0] coordinate to ndc space xy [-1.0 .. 1.0]
fn uv_to_ndc(uv: vec2<f32>) -> vec2<f32> {
    return uv * vec2(2.0, -2.0) + vec2(-1.0, 1.0);
}

/// returns the (0.0, 0.0) .. (1.0, 1.0) position within the viewport for the current render target
/// [0 .. render target viewport size] eg. [(0.0, 0.0) .. (1280.0, 720.0)] to [(0.0, 0.0) .. (1.0, 1.0)]
fn frag_coord_to_uv(frag_coord: vec2<f32>, viewport: vec4<f32>) -> vec2<f32> {
    return (frag_coord - viewport.xy) / viewport.zw;
}

/// Convert frag coord to ndc
fn frag_coord_to_ndc(frag_coord: vec4<f32>, viewport: vec4<f32>) -> vec3<f32> {
    return vec3(uv_to_ndc(frag_coord_to_uv(frag_coord.xy, viewport)), frag_coord.z);
}

/// Convert ndc space xy coordinate [-1.0 .. 1.0] to [0 .. render target
/// viewport size]
fn ndc_to_frag_coord(ndc: vec2<f32>, viewport: vec4<f32>) -> vec2<f32> {
    return ndc_to_uv(ndc) * viewport.zw;
}
// globals.wgsl
// #define_import_path bevy_render::globals

struct Globals {
    // The time since startup in seconds
    // Wraps to 0 after 1 hour.
    time: f32,
    // The delta time since the previous frame in seconds
    delta_time: f32,
    // Frame count since the start of the app.
    // It wraps to zero when it reaches the maximum value of a u32.
    frame_count: u32,
// #ifdef SIXTEEN_BYTE_ALIGNMENT
    // WebGL2 structs must be 16 byte aligned.
    // _webgl2_padding: f32
// #endif
};

/* assorted useful bevy functions */
// fn get_world_from_local(instance_index: u32) -> mat4x4<f32> {
//     return affine3_to_square(mesh[instance_index].world_from_local);
// }
fn mesh_position_local_to_world(world_from_local: mat4x4<f32>, vertex_position: vec4<f32>) -> vec4<f32> {
    return world_from_local * vertex_position;
}

fn position_world_to_clip(world_pos: vec3<f32>) -> vec4<f32> {
    let clip_pos = view.clip_from_world * vec4(world_pos, 1.0);
    return clip_pos;
}

@group(0) @binding(0) var<uniform> globals: Globals;
@group(0) @binding(1) var<uniform> view: View;



// hardcoded compute shader data.
// half_size is half the size of the cube
const half_size = vec3(0.1);
const min = -half_size;
const max = half_size;

// Suppose Y-up right hand, and camera look from +Z to -Z
// 192 items
const vertices = array(
    // xyz, normal.xyz, uv.xy
    // Front
    min.x, min.y, max.z, 0.0, 0.0, 1.0, 0.0, 0.0,
    max.x, min.y, max.z, 0.0, 0.0, 1.0, 1.0, 0.0,
    max.x, max.y, max.z, 0.0, 0.0, 1.0, 1.0, 1.0,
    min.x, max.y, max.z, 0.0, 0.0, 1.0, 0.0, 1.0,
    // Back
    min.x, max.y, min.z, 0.0, 0.0, -1.0, 1.0, 0.0,
    max.x, max.y, min.z, 0.0, 0.0, -1.0, 0.0, 0.0,
    max.x, min.y, min.z, 0.0, 0.0, -1.0, 0.0, 1.0,
    min.x, min.y, min.z, 0.0, 0.0, -1.0, 1.0, 1.0,
    // Right
    max.x, min.y, min.z, 1.0, 0.0, 0.0, 0.0, 0.0,
    max.x, max.y, min.z, 1.0, 0.0, 0.0, 1.0, 0.0,
    max.x, max.y, max.z, 1.0, 0.0, 0.0, 1.0, 1.0,
    max.x, min.y, max.z, 1.0, 0.0, 0.0, 0.0, 1.0,
    // Left
    min.x, min.y, max.z, -1.0, 0.0, 0.0, 1.0, 0.0,
    min.x, max.y, max.z, -1.0, 0.0, 0.0, 0.0, 0.0,
    min.x, max.y, min.z, -1.0, 0.0, 0.0, 0.0, 1.0,
    min.x, min.y, min.z, -1.0, 0.0, 0.0, 1.0, 1.0,
    // Top
    max.x, max.y, min.z, 0.0, 1.0, 0.0, 1.0, 0.0,
    min.x, max.y, min.z, 0.0, 1.0, 0.0, 0.0, 0.0,
    min.x, max.y, max.z, 0.0, 1.0, 0.0, 0.0, 1.0,
    max.x, max.y, max.z, 0.0, 1.0, 0.0, 1.0, 1.0,
    // Bottom
    max.x, min.y, max.z, 0.0, -1.0, 0.0, 0.0, 0.0,
    min.x, min.y, max.z, 0.0, -1.0, 0.0, 1.0, 0.0,
    min.x, min.y, min.z, 0.0, -1.0, 0.0, 1.0, 1.0,
    max.x, min.y, min.z, 0.0, -1.0, 0.0, 0.0, 1.0
);

// 36 items
const indices = array(
    0, 1, 2, 2, 3, 0, // front
    4, 5, 6, 6, 7, 4, // back
    8, 9, 10, 10, 11, 8, // right
    12, 13, 14, 14, 15, 12, // left
    16, 17, 18, 18, 19, 16, // top
    20, 21, 22, 22, 23, 20, // bottom
);

struct TaskPayload {
    colorMask: vec4<f32>,
    grid: vec2u,
    visible: bool,
}
struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    // @location(0) color: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) normal: vec3<f32>
}
struct PrimitiveOutput {
    @builtin(triangle_indices) indices: vec3<u32>,
    @builtin(cull_primitive) cull: bool,
    @per_primitive @location(3) colorMask: vec4<f32>,
}
struct PrimitiveInput {
    @per_primitive @location(3) colorMask: vec4<f32>,
}

var<task_payload> taskPayload: TaskPayload;
var<workgroup> workgroupData: f32;

struct MeshOutput {
    @builtin(vertices) vertices: array<VertexOutput, 24>,
    @builtin(primitives) primitives: array<PrimitiveOutput, 12>,
    @builtin(vertex_count) vertex_count: u32,
    @builtin(primitive_count) primitive_count: u32,
}

var<workgroup> mesh_output: MeshOutput;

struct MeshInput {
    @builtin(global_invocation_id) global_invocation_id: vec3u,
    @builtin(workgroup_id) workgroup_id: vec3u
}

@mesh(mesh_output)
@payload(taskPayload)
@workgroup_size(1)
fn mesh(mesh_input: MeshInput) {
    mesh_output.vertex_count = 24;
    mesh_output.primitive_count = 12;
    workgroupData = 2.0;
    
    // we "fake" the `world_from_local` matrix that normally exists for
    // meshes because we're generating and positioning cubes in arbitrary
    // positions. The global_invocation_id will give us an x/y/z for every
    // point in the 3d space we're filling.
    let world_from_local = mat4x4(
        vec4(1., 0., 0., 0,),
        vec4(0., 1., 0., 0.),
        vec4(0., 0., 1., 0.),
        vec4(
            f32(mesh_input.global_invocation_id.x),
            f32(mesh_input.global_invocation_id.y),
            f32(mesh_input.global_invocation_id.z),
            1.,
        ),
    );

    for (var i: i32 = 0; i < 24; i++) {
        let offset = i * 8;
        mesh_output.vertices[i].position =  position_world_to_clip(
           mesh_position_local_to_world(world_from_local, 
                vec4(vertices[offset] , vertices[offset + 1], vertices[offset + 2], 1.)
           ).xyz
       );
        mesh_output.vertices[i].normal = vec3(vertices[offset + 3], vertices[offset + 4], vertices[offset + 5]);
        mesh_output.vertices[i].uv = vec2(vertices[offset + 6], vertices[offset + 7]);
    };

    for (var i: i32 = 0; i < 12; i++) {
        let offset = i * 3;
        mesh_output.primitives[i].indices = vec3<u32>(u32(indices[offset]), u32(indices[offset + 1]), u32(indices[offset + 2]));
        mesh_output.primitives[i].cull = !taskPayload.visible;
        mesh_output.primitives[i].colorMask = vec4<f32>(1.0, 0.0, 1.0, 1.0);
    };
}
