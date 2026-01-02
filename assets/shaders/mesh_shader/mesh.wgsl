enable wgpu_mesh_shader;

const positions = array(
    vec4(0., 1., 0., 1.),
    vec4(-1., -1., 0., 1.),
    vec4(1., -1., 0., 1.)
);
const colors = array(
    vec4(0., 1., 0., 1.),
    vec4(0., 0., 1., 1.),
    vec4(1., 0., 0., 1.)
);

struct TaskPayload {
    colorMask: vec4<f32>,
    grid: vec2u,
    visible: bool,
}
struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec4<f32>,
}
struct PrimitiveOutput {
    @builtin(triangle_indices) indices: vec3<u32>,
    @builtin(cull_primitive) cull: bool,
    @per_primitive @location(1) colorMask: vec4<f32>,
}
struct PrimitiveInput {
    @per_primitive @location(1) colorMask: vec4<f32>,
}

var<task_payload> taskPayload: TaskPayload;
var<workgroup> workgroupData: f32;

struct MeshOutput {
    @builtin(vertices) vertices: array<VertexOutput, 3>,
    @builtin(primitives) primitives: array<PrimitiveOutput, 1>,
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
    mesh_output.vertex_count = 3;
    mesh_output.primitive_count = 1;
    workgroupData = 2.0;

    let grid = vec2f(taskPayload.grid.xy);
    let current_fractional = vec2f(mesh_input.workgroup_id.xy) / vec2f(grid);
    let center_point = current_fractional * vec2(2.) - vec2(1.);
        // - vec3f(vec2f(taskPayload.grid.xy) * (1. / vec2f(taskPayload.grid.xy)) - 0.5 , 0.),
    // 0.);
    // let pos = (positions[0].xyz + vec3(1.)) / vec3(4.) - vec3(0.25);
    let scale_triangle = vec4(vec2(1.) / grid, 1.,1.);
    mesh_output.vertices[0].position = positions[0] * scale_triangle + vec4(center_point + vec2(1.)/grid, 0.,0.);
    mesh_output.vertices[0].color = colors[0] * taskPayload.colorMask;

    mesh_output.vertices[1].position = positions[1]  * scale_triangle + vec4(center_point + vec2(1.)/grid, 0.,0.);
    mesh_output.vertices[1].color = colors[1] * taskPayload.colorMask;

    mesh_output.vertices[2].position = positions[2]  * scale_triangle + vec4(center_point + vec2(1.)/grid, 0.,0.);
    mesh_output.vertices[2].color = colors[2] * taskPayload.colorMask;

    mesh_output.primitives[0].indices = vec3<u32>(0, 1, 2);
    mesh_output.primitives[0].cull = !taskPayload.visible;
    mesh_output.primitives[0].colorMask = vec4<f32>(1.0, 0.0, 1.0, 1.0);
}

// 0,1,2,3
// 5
// 0/5 - 1.