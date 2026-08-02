import bevy_render::maths::PI;
import bevy_pbr::render::utils::rand_f;
import super::{
    bindings::{view, globals, VertexOutput},
    noise::perlin_noise_2d
};

enable wgpu_mesh_shader;

/* assorted useful bevy functions */
fn mesh_position_local_to_world(world_from_local: mat4x4<f32>, vertex_position: vec4<f32>) -> vec4<f32> {
    return world_from_local * vertex_position;
}

fn position_world_to_clip(world_pos: vec3<f32>) -> vec4<f32> {
    let clip_pos = view.clip_from_world * vec4(world_pos, 1.0);
    return clip_pos;
}

// ground normal of patch
const NORMAL = vec3(0.01, 1., 0.);

// position, normal, height
// vec3, vec3, f32
const patches = array(
    0., 0., 0., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    1., 0., 0., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    2., 0., 0., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    3., 0., 0., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    4., 0., 0., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    5., 0., 0., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    6., 0., 0., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    7., 0., 0., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    8., 0., 0., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    9., 0., 0., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    0., 0., 1., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    1., 0., 1., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    2., 0., 1., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    3., 0., 1., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    4., 0., 1., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    5., 0., 1., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    6., 0., 1., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    7., 0., 1., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    8., 0., 1., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    9., 0., 1., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    0., 0., 2., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    1., 0., 2., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    2., 0., 2., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    3., 0., 2., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    4., 0., 2., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    5., 0., 2., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    6., 0., 2., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    7., 0., 2., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    8., 0., 2., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    9., 0., 2., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    0., 0., 3., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    1., 0., 3., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    2., 0., 3., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    3., 0., 3., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    4., 0., 3., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    5., 0., 3., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    6., 0., 3., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    7., 0., 3., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    8., 0., 3., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    9., 0., 3., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    0., 0., 4., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    1., 0., 4., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    2., 0., 4., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    3., 0., 4., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    4., 0., 4., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    5., 0., 4., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    6., 0., 4., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    7., 0., 4., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    8., 0., 4., NORMAL.x, NORMAL.y, NORMAL.z, 1.,
    9., 0., 4., NORMAL.x, NORMAL.y, NORMAL.z, 1.,  
);

struct TaskPayload {
    colorMask: vec4<f32>,
    grid: vec2u,
    visible: bool,
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
const GRASS_END_DISTANCE: f32 = 100;

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

    // todo: is it useful to set these as mesh_output.* values?
    let vertex_counta: i32   = i32(blade_count) * vertices_per_blade;
    let triangle_counta: i32 = i32(blade_count) * triangles_per_blade;
    // mesh_output.vertex_count = u32(vertex_counta);
    // mesh_output.primitive_count = u32(triangle_counta);



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

        let height: f32 = arguments_height + rand_f(&rng) / 1.;

        // position the grass in a circle around the patchPosition taking the patch normal into account
        let tangent: vec3f   = normalize(cross(vec3(0., 1., 0.), patch_normal));
        let bitangent: vec3f = normalize(cross(patch_normal, tangent));

        let blade_direction_angle: f32  = 2. * PI * rand_f(&rng);
        let blade_direction: vec2f      = vec2(cos(blade_direction_angle), sin(blade_direction_angle));

        let offset_angle: f32  = 2. * PI * rand_f(&rng);
        let offset_radius: f32 = spacing * sqrt(rand_f(&rng));
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

fn get_wind_offset(pos: vec2f, time: f32) -> vec3f {
    // arbitrary wind direction
    let wind_direction = 1.;
    let animation_scale = 1.;
    let pos_on_sine_wave: f32 = cos(wind_direction) * pos.x - sin(wind_direction) * pos.y;

    let t: f32 = time + pos_on_sine_wave + 4 * perlin_noise_2d(0.1 * pos);
    let windx: f32 = 2 * sin(.5 * t);
    let windy: f32 = 1 * sin(1. * t);

    return animation_scale * vec3(windx, 0, windy);
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
