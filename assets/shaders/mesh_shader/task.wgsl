enable wgpu_mesh_shader;

struct ShaderData {
    time: f32
}
@group(0) @binding(0) var<uniform> shader_data: ShaderData;

struct TaskPayload {
    colorMask: vec4<f32>,
    grid: vec2u,
    visible: bool,
}

var<task_payload> taskPayload: TaskPayload;
var<workgroup> workgroupData: f32;

@task
@payload(taskPayload)
@workgroup_size(1)
fn task() -> @builtin(mesh_task_size) vec3<u32> {
    workgroupData = 1.0;
    taskPayload.colorMask = vec4(1.0, 1.0, 0.0, 1.0);
    taskPayload.grid = vec2u(shader_data.time * 10);
    // taskPayload.grid = vec2u( 10);

    taskPayload.visible = true;
    return vec3(taskPayload.grid.xy, 1);
}
