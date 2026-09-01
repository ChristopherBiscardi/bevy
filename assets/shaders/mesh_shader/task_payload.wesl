// TaskPayload should be kept very small.
struct TaskPayload {
    colorMask: vec4<f32>,
    visible: bool,
}

var<workgroup> workgroupData: f32;