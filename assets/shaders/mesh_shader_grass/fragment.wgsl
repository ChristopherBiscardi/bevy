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
// #ifdef SIXTEEN_BYTE_ALIGNMENT
    // WebGL2 structs must be 16 byte aligned.
    // _webgl2_padding: f32
// #endif
};

@group(0) @binding(0) var<uniform> globals: Globals;
@group(0) @binding(1) var<uniform> view: View;

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) world_position: vec3<f32>,
    @location(1) world_normal: vec3<f32>,
    @location(2) root_height: f32,
    @location(3) height: f32
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