// import bevy_render::view::View;
// import bevy_render::globals::Globals;
import super::{
    bindings::globals,
    task_payload::{TaskPayload, workgroupData}
};
enable wgpu_mesh_shader;

var<task_payload> taskPayload: TaskPayload;

@task
@payload(taskPayload)
@workgroup_size(1)
fn task() -> @builtin(mesh_task_size) vec3<u32> {
    workgroupData = 1.0;

    taskPayload.colorMask = vec4(1.0, 1.0, 0.0, 1.0);
    taskPayload.visible = true;

    // how many mesh shaders get dispatched grows over time
    // until it passes a gpu limit. When it hits the limit all
    // cubes disappear, showing what can happen if you choose the
    // wrong values.
    return vec3u(u32(globals.time));
}