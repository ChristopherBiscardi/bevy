//! This example demonstrates how to write a mesh shader.
//!
//! TODO: explain task and mesh shaders, as well as caveats like Metal not having a wgsl frontend

#[cfg(feature = "free_camera")]
use bevy::camera_controller::free_camera::{FreeCamera, FreeCameraPlugin};
use bevy::{
    camera::{MainPassResolutionOverride, Viewport},
    core_pipeline::{core_3d::CORE_3D_DEPTH_FORMAT, Core3d, Core3dSystems},
    prelude::*,
    render::{
        camera::ExtractedCamera,
        globals::{GlobalsBuffer, GlobalsUniform},
        render_resource::{
            BindGroupEntries, BindGroupLayout, BindGroupLayoutEntry, BindingType,
            BufferBindingType, ColorTargetState, ColorWrites, PipelineLayoutDescriptor,
            RenderPassDescriptor, RenderPipeline, ShaderModuleDescriptor, ShaderSource,
            ShaderStages, ShaderType, TextureFormat, WgpuFeatures, WgpuLimits,
        },
        renderer::{RenderContext, RenderDevice, ViewQuery},
        settings::{RenderCreation, WgpuSettings},
        view::{
            ExtractedView, ViewDepthTexture, ViewTarget, ViewUniform, ViewUniformOffset,
            ViewUniforms,
        },
        RenderApp, RenderPlugin,
    },
};

use wgpu::{
    BufferBinding, CompareFunction, DepthBiasState, DepthStencilState, StencilState, StoreOp,
};

fn main() {
    App::new()
        .add_plugins((
            DefaultPlugins.set(RenderPlugin {
                render_creation: RenderCreation::Automatic(Box::new(WgpuSettings {
                    features: WgpuFeatures::EXPERIMENTAL_MESH_SHADER
                        | WgpuFeatures::EXPERIMENTAL_PASSTHROUGH_SHADERS,
                    limits: WgpuLimits::default().using_recommended_minimum_mesh_shader_values(),
                    ..default()
                })),
                ..default()
            }),
            MeshShaderGrassPlugin,
            #[cfg(feature = "free_camera")]
            FreeCameraPlugin,
        ))
        .add_systems(Startup, setup)
        .run();
}

fn setup(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
) {
    commands.spawn((
        Mesh3d(meshes.add(Cuboid::new(0.5, 0.5, 0.5))),
        MeshMaterial3d(materials.add(Color::srgb_u8(124, 144, 255))),
        Transform::from_xyz(0.0, 0.5, 0.0),
    ));
    // light
    commands.spawn((
        PointLight {
            shadow_maps_enabled: true,
            ..default()
        },
        Transform::from_xyz(4.0, 8.0, 4.0),
    ));
    // camera
    commands.spawn((
        Camera3d::default(),
        Transform::from_xyz(-5.0, 1.0, -5.0).looking_at(Vec3::new(0., 0., 0.), Vec3::Y),
        // disable msaa for simplicity
        Msaa::Off,
        #[cfg(feature = "free_camera")]
        FreeCamera::default(),
    ));
}

struct MeshShaderGrassPlugin;
impl Plugin for MeshShaderGrassPlugin {
    fn build(&self, app: &mut App) {}
    // We initialize in finish so that the RenderDevice is available for our FromWorld implementation
    fn finish(&self, app: &mut App) {
        // We need to get the render app from the main app
        let Some(render_app) = app.get_sub_app_mut(RenderApp) else {
            return;
        };

        render_app
            .init_resource::<GrassDrawNode>()
            .add_systems(Core3d, draw_grass.in_set(Core3dSystems::MainPass));
    }
}

impl FromWorld for GrassDrawNode {
    fn from_world(world: &mut World) -> Self {
        let device = world.resource::<RenderDevice>();
        #[allow(unsafe_code)]
        let mesh_shader = unsafe {
            device.create_shader_module(ShaderModuleDescriptor {
                label: Some("mesh_shader"),
                source: ShaderSource::Wgsl(
                    include_str!("../../assets/shaders/mesh_shader_grass/mesh.wgsl").into(),
                ),
            })
        };
        #[allow(unsafe_code)]
        let fragment_shader = unsafe {
            device.create_shader_module(ShaderModuleDescriptor {
                label: Some("fragment_shader"),
                source: ShaderSource::Wgsl(
                    include_str!("../../assets/shaders/mesh_shader_grass/fragment.wgsl").into(),
                ),
            })
        };

        let bind_group_data = device.create_bind_group_layout(
            "bind_group_data",
            &[
                BindGroupLayoutEntry {
                    binding: 0,
                    visibility: ShaderStages::all(),
                    ty: BindingType::Buffer {
                        ty: BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: Some(GlobalsUniform::min_size()),
                    },
                    count: None,
                },
                BindGroupLayoutEntry {
                    binding: 1,
                    visibility: ShaderStages::all(),
                    ty: BindingType::Buffer {
                        ty: BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: Some(ViewUniform::min_size()),
                    },
                    count: None,
                },
            ],
        );

        let pipeline_layout = device.create_pipeline_layout(&PipelineLayoutDescriptor {
            label: "grass_mesh_shader_pipeline_layout".into(),
            bind_group_layouts: &[&bind_group_data],
            immediate_size: 0,
        });

        let mesh_pipeline =
            device
                .wgpu_device()
                .create_mesh_pipeline(&wgpu::MeshPipelineDescriptor {
                    label: "grass_mesh_shader_pipeline".into(),
                    layout: Some(&pipeline_layout),
                    task: None,
                    mesh: wgpu::MeshState {
                        module: &mesh_shader,
                        entry_point: "mesh".into(),
                        compilation_options: Default::default(),
                    },
                    fragment: Some(wgpu::FragmentState {
                        module: &fragment_shader,
                        entry_point: "fragment".into(),
                        compilation_options: Default::default(),
                        targets: &[Some(ColorTargetState {
                            format: TextureFormat::bevy_default(),
                            blend: None,
                            write_mask: ColorWrites::ALL,
                        })],
                    }),
                    primitive: Default::default(),
                    depth_stencil: Some(DepthStencilState {
                        format: CORE_3D_DEPTH_FORMAT,
                        depth_write_enabled: true,
                        depth_compare: CompareFunction::Greater,
                        stencil: StencilState::default(),
                        bias: DepthBiasState::default(),
                    }),
                    multisample: Default::default(),
                    cache: None,
                    multiview: None,
                });

        GrassDrawNode {
            mesh_pipeline: mesh_pipeline.into(),
            bind_group_data,
        }
    }
}

#[derive(Resource)]
struct GrassDrawNode {
    mesh_pipeline: RenderPipeline,
    bind_group_data: BindGroupLayout,
    // todo: shaders here?
}

fn draw_grass(
    view: ViewQuery<(
        &'static ExtractedCamera,
        &'static ExtractedView,
        &'static ViewTarget,
        &'static ViewDepthTexture,
        &'static ViewUniformOffset,
        Option<&'static MainPassResolutionOverride>,
    )>,
    mut render_context: RenderContext,
    data: Res<GrassDrawNode>,
    view_uniforms_resource: Res<ViewUniforms>,
    globals_buffer: Res<GlobalsBuffer>,
) {
    let (camera, _, target, depth, view_uniform_offset, resolution_override) = view.into_inner();

    let view_uniforms = &view_uniforms_resource.uniforms;
    let view_uniforms_buffer = view_uniforms.buffer().unwrap();

    let time_bind_group = render_context.render_device().create_bind_group(
        "time_bind_group",
        &data.bind_group_data,
        &BindGroupEntries::sequential((
            &globals_buffer.buffer,
            BufferBinding {
                buffer: view_uniforms_buffer,
                size: Some(ViewUniform::min_size()),
                offset: view_uniform_offset.offset as u64,
            },
        )),
    );

    {
        let mut render_pass =
            render_context
                .command_encoder()
                .begin_render_pass(&RenderPassDescriptor {
                    label: Some("grass_mesh_shader_pass"),
                    // Write directly to the view target
                    color_attachments: &[Some(target.get_color_attachment())],
                    depth_stencil_attachment: Some(depth.get_attachment(StoreOp::Store)),
                    timestamp_writes: None,
                    occlusion_query_set: None,
                    multiview_mask: None,
                });

        render_pass.push_debug_group("Prepare data for draw.");
        render_pass.set_pipeline(&data.mesh_pipeline);
        render_pass.set_bind_group(0, &time_bind_group, &[]);
        if let Some(viewport) =
            Viewport::from_viewport_and_override(camera.viewport.as_ref(), resolution_override)
        {
            render_pass.set_viewport(
                viewport.physical_position.x as f32,
                viewport.physical_position.y as f32,
                viewport.physical_size.x as f32,
                viewport.physical_size.y as f32,
                viewport.depth.start,
                viewport.depth.end,
            );
        }
        render_pass.pop_debug_group();
        render_pass.insert_debug_marker("Draw!");
        // TODO: dispatch more
        render_pass.draw_mesh_tasks(50, 1, 1);
    }
}
