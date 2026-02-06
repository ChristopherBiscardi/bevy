enable wgpu_mesh_shader;

// bevy_render:: maths
const PI: f32 = 3.14159265358979323846;
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

// globals.wgsl

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

/* assorted useful bevy functions */
fn mesh_position_local_to_world(world_from_local: mat4x4<f32>, vertex_position: vec4<f32>) -> vec4<f32> {
    return world_from_local * vertex_position;
}

fn position_world_to_clip(world_pos: vec3<f32>) -> vec4<f32> {
    let clip_pos = view.clip_from_world * vec4(world_pos, 1.0);
    return clip_pos;
}

@group(0) @binding(0) var<uniform> globals: Globals;
@group(0) @binding(1) var<uniform> view: View;

// position, normal, height
// vec3, vec3, f32
const patches = array(
    0., 0., 0., 0.01, 1., 0., 1.,
    1., 0., 0., 0.01, 1., 0., 1.,
    2., 0., 0., 0.01, 1., 0., 1.,
    3., 0., 0., 0.01, 1., 0., 1.,
    4., 0., 0., 0.01, 1., 0., 1.,
    5., 0., 0., 0.01, 1., 0., 1.,
    6., 0., 0., 0.01, 1., 0., 1.,
    7., 0., 0., 0.01, 1., 0., 1.,
    8., 0., 0., 0.01, 1., 0., 1.,
    9., 0., 0., 0.01, 1., 0., 1.,
    0., 0., 1., 0.01, 1., 0., 1.,
    1., 0., 1., 0.01, 1., 0., 1.,
    2., 0., 1., 0.01, 1., 0., 1.,
    3., 0., 1., 0.01, 1., 0., 1.,
    4., 0., 1., 0.01, 1., 0., 1.,
    5., 0., 1., 0.01, 1., 0., 1.,
    6., 0., 1., 0.01, 1., 0., 1.,
    7., 0., 1., 0.01, 1., 0., 1.,
    8., 0., 1., 0.01, 1., 0., 1.,
    9., 0., 1., 0.01, 1., 0., 1.,
    0., 0., 2., 0.01, 1., 0., 1.,
    1., 0., 2., 0.01, 1., 0., 1.,
    2., 0., 2., 0.01, 1., 0., 1.,
    3., 0., 2., 0.01, 1., 0., 1.,
    4., 0., 2., 0.01, 1., 0., 1.,
    5., 0., 2., 0.01, 1., 0., 1.,
    6., 0., 2., 0.01, 1., 0., 1.,
    7., 0., 2., 0.01, 1., 0., 1.,
    8., 0., 2., 0.01, 1., 0., 1.,
    9., 0., 2., 0.01, 1., 0., 1.,
    0., 0., 3., 0.01, 1., 0., 1.,
    1., 0., 3., 0.01, 1., 0., 1.,
    2., 0., 3., 0.01, 1., 0., 1.,
    3., 0., 3., 0.01, 1., 0., 1.,
    4., 0., 3., 0.01, 1., 0., 1.,
    5., 0., 3., 0.01, 1., 0., 1.,
    6., 0., 3., 0.01, 1., 0., 1.,
    7., 0., 3., 0.01, 1., 0., 1.,
    8., 0., 3., 0.01, 1., 0., 1.,
    9., 0., 3., 0.01, 1., 0., 1.,
    0., 0., 4., 0.01, 1., 0., 1.,
    1., 0., 4., 0.01, 1., 0., 1.,
    2., 0., 4., 0.01, 1., 0., 1.,
    3., 0., 4., 0.01, 1., 0., 1.,
    4., 0., 4., 0.01, 1., 0., 1.,
    5., 0., 4., 0.01, 1., 0., 1.,
    6., 0., 4., 0.01, 1., 0., 1.,
    7., 0., 4., 0.01, 1., 0., 1.,
    8., 0., 4., 0.01, 1., 0., 1.,
    9., 0., 4., 0.01, 1., 0., 1.,  
);
struct TaskPayload {
    colorMask: vec4<f32>,
    grid: vec2u,
    visible: bool,
}
struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) world_position: vec3<f32>,
    @location(1) world_normal: vec3<f32>,
    @location(2) root_height: f32,
    @location(3) height: f32,
    @location(5) something: vec4f
}
struct PrimitiveOutput {
    @builtin(triangle_indices) indices: vec3<u32>,
    @builtin(cull_primitive) cull: bool,
    @per_primitive @location(4) colorMask: vec4<f32>,
}

// var<task_payload> taskPayload: TaskPayload;
var<workgroup> workgroupData: f32;

const GROUP_SIZE: u32       = 128;
const GRASS_VERT_COUNT: u32 = 256;
const GRASS_PRIM_COUNT: u32 = 192;
// arbitrary distance to stop rendering grass. There is no value
// set in the blog post
const GRASS_END_DISTANCE: f32 = 10;

struct MeshOutput {
    @builtin(vertices) vertices: array<VertexOutput, GRASS_VERT_COUNT>,
    @builtin(primitives) primitives: array<PrimitiveOutput, GRASS_PRIM_COUNT>,
    @builtin(vertex_count) vertex_count: u32,
    @builtin(primitive_count) primitive_count: u32,
}

var<workgroup> mesh_output: MeshOutput;

struct MeshInput {
    @builtin(global_invocation_id) global_invocation_id: vec3u,
    @builtin(workgroup_id) workgroup_id: vec3u,
    @builtin(local_invocation_id) local_invocation_id: vec3u
}

@mesh(mesh_output)
// @payload(taskPayload)
@workgroup_size(GROUP_SIZE, 1, 1)
fn mesh(mesh_input: MeshInput) {
    mesh_output.vertex_count = GRASS_VERT_COUNT;
    mesh_output.primitive_count = GRASS_PRIM_COUNT;
    workgroupData = 2.0;
    // 7 is vec3, vec3, f32
    let base_offset = mesh_input.workgroup_id.x * 7;

    const vertices_per_blade_edge: i32 = 4;
    const vertices_per_blade: i32 = 2 * vertices_per_blade_edge;
    const triangles_per_blade: i32 = 6;
    const max_blade_count: i32 = 32;

    let patch_center = vec3(
        patches[base_offset],
        patches[base_offset + 1],
        patches[base_offset + 2]
    );
    let patch_normal = vec3(
        patches[base_offset + 3],
        patches[base_offset + 4],
        patches[base_offset + 5]
    );
    let arguments_height = patches[base_offset + 6];
    // const spacing: f32       = DynamicConst.grassSpacing; // TODO: this is a uniform value passed in
    let spacing = 0.43;
    // const seed: i32          = combineSeed(asuint(int(patchCenter.x / spacing)), asuint(int(patchCenter.y / spacing)));


    // view.world_position
    // float distanceToCamera = distance(arguments.position, DynamicConst.cullingCameraPosition.xyz);
    let distance_to_camera: f32 = distance(patch_center, view.world_position);
    // float blade_count_f      = lerp(float(maxBladeCount), 2., pow(saturate(distanceToCamera / (GRASS_END_DISTANCE * 1.05)), 0.75));
    let blade_count_f = mix(f32(max_blade_count), 2., pow(saturate(distance_to_camera / (GRASS_END_DISTANCE * 1.05)), 0.75));

    // int bladeCount = ceil(bladeCountF);
    let blade_count = ceil(blade_count_f);

    // const int triangleCount = bladeCount * trianglesPerBlade;

    // we "fake" the `world_from_local` matrix that normally exists for
    // meshes because we're generating and positioning cubes in arbitrary
    // positions.
    let world_from_local = mat4x4(
        vec4(1., 0., 0., 0,),
        vec4(0., 1., 0., 0.),
        vec4(0., 0., 1., 0.),
        vec4(
            // TODO: these need to be the translation of the grass blades probably?
            f32(mesh_input.workgroup_id.x),
            f32(mesh_input.workgroup_id.y),
            f32(mesh_input.workgroup_id.z),
            1.,
        ),
    );

    // todo: are these out outputs
    let vertex_counta: i32   = i32(blade_count) * vertices_per_blade;
    let triangle_counta: i32 = i32(blade_count) * triangles_per_blade;

    // let gtid = mesh_input.workgroup_id.x;
    let gtid = mesh_input.local_invocation_id.x;
    for (var i: u32 = 0; i < 2; i++){
        let vert_id: u32 = gtid + GROUP_SIZE * i;

        if (vert_id >= u32(vertex_counta)) {
            break;
        }

        let blade_id: u32     = vert_id / u32(vertices_per_blade);
        let vert_id_local = vert_id % u32(vertices_per_blade);

        // rng could probably use work?
        // var rng = mesh_input.local_invocation_id.x << blade_id;
        var rng = blade_id;

        let height: f32 = arguments_height + rand_f(&rng) / 40.;

        //position the grass in a circle around the patchPosition and angled using the patchNormal
        let tangent: vec3f   = normalize(cross(vec3(0., 1., 0.), patch_normal));
        let bitangent: vec3f = normalize(cross(patch_normal, tangent));

        let blade_direction_angle: f32  = 2. * PI * rand_f(&rng);
        let blade_direction: vec2f      = vec2(cos(blade_direction_angle), sin(blade_direction_angle));

        let  offset_angle: f32  = 2. * PI * rand_f(&rng);
        let  offset_radius: f32 = spacing * sqrt(rand_f(&rng));
        let blade_offset: vec3f  = offset_radius * (cos(offset_angle) * tangent + sin(offset_angle) * bitangent);

        var p0: vec3f = patch_center + blade_offset;
        var p1: vec3f = p0 + vec3(0, height, 0);
        var p2: vec3f = p1 + vec3(blade_direction  * height * 0.3, 0.);

        p2 += get_wind_offset(p0.xy, globals.time);

        // TODO: can this actuall mutate p1 and p2?
        make_persistent_length(p0, &p1, &p2, height);

        var width: f32 = 0.03;

        width *= f32(max_blade_count) / blade_count_f;

        if (blade_id == u32(blade_count-1)){
            width *= fract(blade_count_f);
        }


        mesh_output.vertices[vert_id].height                 = arguments_height;
        // mesh_output.vertices[vert_id].world_space_ground_normal = patch_normal;
        mesh_output.vertices[vert_id].root_height             = p0.z;

        let side_vec: vec3f = normalize(vec3(blade_direction.y, -blade_direction.x, 0));
        let offset: vec3f  = f32(tsign(vert_id_local, 0)) * width * side_vec;

        p0 += offset * 1.0;
        p1 += offset * 0.7;
        p2 += offset * 0.3;

        let t: f32 = f32((vert_id_local/2)) / f32(vertices_per_blade_edge - 1);
        mesh_output.vertices[vert_id].world_position = bezier(p0, p1, p2, t);
        mesh_output.vertices[vert_id].world_normal   = cross(side_vec, normalize(bezier_derivative(p0, p1, p2, t)));
        // todo: is clip_from_view right?
        mesh_output.vertices[vert_id].position  = position_world_to_clip(
               mesh_output.vertices[vert_id].world_position
       );
            // mesh_output.vertices[vert_id].position  = vec4(1.,1.,1.,1.);
       let tsig_temp = f32(tsign(vert_id_local, 0));
      mesh_output.vertices[vert_id].something = vec4f(
        f32(blade_id),        f32(blade_id),        f32(blade_id),
        f32(vert_id_local)
      );
    //    view.clip_from_view * vec4(mesh_output.vertices[vert_id].world_position, 1);

    }

    for (var i: u32 = 0; i < 2; i++){
        let tri_id: i32 = i32(gtid + GROUP_SIZE * i);

        if (tri_id >= triangle_counta) {
            break;
        }

        let blade_id: i32    = tri_id / triangles_per_blade;
        let tri_id_local: i32 = tri_id % triangles_per_blade;

        let offset: u32 = u32(blade_id * vertices_per_blade + 2 * (tri_id_local / 2));

        if ((tri_id_local & 1) == 0 ) {
           mesh_output.primitives[tri_id].indices = vec3u(offset + 0, offset + 1, offset + 2);
        } else {
           mesh_output.primitives[tri_id].indices = vec3u(offset + 3, offset + 2, offset + 1);
        }
        mesh_output.primitives[tri_id].colorMask = vec4(f32(blade_id),0.,0.,1.);
        mesh_output.primitives[tri_id].cull = false;
    }
}

// The utility function tsign(uint value, int bitPos) returns -1 or +1
// depending on if the bit at bitPos in value is set. Thus, when vertIdLocal
// is even, we move P in the negative direction, and into the positive direction,
// when it is odd. We scale the offset at each control point with respectively w0, w1, and w2
// - https://gpuopen.com/learn/mesh_shaders/mesh_shaders-procedural_grass_rendering/
fn tsign(gtid: u32, id: i32) -> i32 {
    if bool(gtid & (1u << u32(id))) {
        return 1;
    } else {
        return -1;
    }
}

// A bevy_pbr/render/utils rand function
// Generates a random f32 in range [0, 1.0].
fn rand_f(state: ptr<function, u32>) -> f32 {
    *state = *state * 747796405u + 2891336453u;
    let word = ((*state >> ((*state >> 28u) + 4u)) ^ *state) * 277803737u;
    return f32((word >> 22u) ^ word) * bitcast<f32>(0x2f800004u);
}

fn get_wind_offset(pos: vec2f, time: f32) -> vec3f {
    // arbitrary wind direction
    let wind_direction = 1.;
    let animation_scale = 1.;
    let pos_on_sine_wave: f32 = cos(wind_direction) * pos.x - sin(wind_direction) * pos.y;

    let t: f32     = time + pos_on_sine_wave + 4 * perlin_noise_2d(0.1 * pos);
    let windx: f32 = 2 * sin(.5 * t);
    let windy: f32 = 1 * sin(1. * t);

    return animation_scale * vec3(windx, windy, 0);
}

fn bezier(p0: vec3f, p1: vec3f, p2: vec3f, t: f32) -> vec3f {
    let a: vec3f = mix(p0, p1, t);
    let b: vec3f = mix(p1, p2, t);
    return mix(a, b, t);
}

fn bezier_derivative(p0: vec3f, p1: vec3f, p2: vec3f, t: f32) -> vec3f {
    return 2. * (1. - t) * (p1 - p0) + 2. * t * (p2 - p1);
}

fn make_persistent_length(
    // in
    v0: vec3f,
    // inout float3 
    v1: ptr<function, vec3f>,
    // inout float3
    v2: ptr<function, vec3f>,
    //in
    height: f32) {
    //Persistent length
    let v01: vec3f = *v1 - v0;
    let v12: vec3f = *v2 - *v1;
    let lv01: f32 = length(v01);
    let lv12: f32 = length(v12);

    let L1: f32 = lv01 + lv12;
    let L0: f32 = length(*v2-v0);
    let L: f32 = (2.0f * L0 + L1) / 3.0f; //http://steve.hollasch.net/cgindex/curves/cbezarclen.html

    let ldiff: f32 = height / L;
    let v01_b = v01 * ldiff;
    let v12_b = v12 * ldiff;
    *v1 = v0 + v01_b;
    *v2 = *v1 + v12_b;
}

// MIT License. © Stefan Gustavson, Munrocket
//
fn permute_four(x: vec4<f32>) -> vec4<f32> { return ((x * 34. + 1.) * x) % vec4<f32>(289.); }
fn fade_two(t: vec2<f32>) -> vec2<f32> { return t * t * t * (t * (t * 6. - 15.) + 10.); }

fn perlin_noise_2d(P: vec2<f32>) -> f32 {
  var Pi: vec4<f32> = floor(P.xyxy) + vec4<f32>(0., 0., 1., 1.);
  let Pf = fract(P.xyxy) - vec4<f32>(0., 0., 1., 1.);
  Pi = Pi % vec4<f32>(289.); // To avoid truncation effects in permutation
  let ix = Pi.xzxz;
  let iy = Pi.yyww;
  let fx = Pf.xzxz;
  let fy = Pf.yyww;
  let i = permute_four(permute_four(ix) + iy);
  var gx: vec4<f32> = 2. * fract(i * 0.0243902439) - 1.; // 1/41 = 0.024...
  let gy = abs(gx) - 0.5;
  let tx = floor(gx + 0.5);
  gx = gx - tx;
  var g00: vec2<f32> = vec2<f32>(gx.x, gy.x);
  var g10: vec2<f32> = vec2<f32>(gx.y, gy.y);
  var g01: vec2<f32> = vec2<f32>(gx.z, gy.z);
  var g11: vec2<f32> = vec2<f32>(gx.w, gy.w);
  let norm = 1.79284291400159 - 0.85373472095314 *
      vec4<f32>(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11));
  g00 = g00 * norm.x;
  g01 = g01 * norm.y;
  g10 = g10 * norm.z;
  g11 = g11 * norm.w;
  let n00 = dot(g00, vec2<f32>(fx.x, fy.x));
  let n10 = dot(g10, vec2<f32>(fx.y, fy.y));
  let n01 = dot(g01, vec2<f32>(fx.z, fy.z));
  let n11 = dot(g11, vec2<f32>(fx.w, fy.w));
  let fade_xy = fade_two(Pf.xy);
  let n_x = mix(vec2<f32>(n00, n01), vec2<f32>(n10, n11), vec2<f32>(fade_xy.x));
  let n_xy = mix(n_x.x, n_x.y, fade_xy.y);
  return 2.3 * n_xy;
}