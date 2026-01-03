//! This example demonstrates how to write a mesh shader.
//!
//! TODO: explain task and mesh shaders, as well as caveats like Metal not having a wgsl frontend

use std::ops::Range;

use bevy::pbr::SetMeshViewEmptyBindGroup;
use bevy::{
    camera::MainPassResolutionOverride,
    core_pipeline::core_3d::graph::{Core3d, Node3d},
    ecs::{
        query::QueryItem,
        system::{lifetimeless::SRes, SystemParamItem},
    },
    math::FloatOrd,
    mesh::MeshVertexBufferLayoutRef,
    pbr::{
        DrawMesh, MeshInputUniform, MeshPipeline, MeshPipelineKey, MeshPipelineViewLayoutKey,
        MeshUniform, RenderMeshInstances, SetMeshBindGroup, SetMeshViewBindGroup,
    },
    platform::collections::HashSet,
    prelude::*,
    render::{
        batching::{
            gpu_preprocessing::{
                batch_and_prepare_sorted_render_phase, IndirectParametersCpuMetadata,
                UntypedPhaseIndirectParametersBuffers,
            },
            GetBatchData, GetFullBatchData,
        },
        camera::ExtractedCamera,
        extract_component::{ExtractComponent, ExtractComponentPlugin},
        mesh::{allocator::MeshAllocator, RenderMesh},
        render_asset::RenderAssets,
        render_graph::{
            NodeRunError, RenderGraphContext, RenderGraphExt, RenderLabel, ViewNode, ViewNodeRunner,
        },
        render_phase::{
            sort_phase_system, AddRenderCommand, CachedRenderPipelinePhaseItem, DrawFunctionId,
            DrawFunctions, PhaseItem, PhaseItemExtraIndex, SetItemPipeline, SortedPhaseItem,
            SortedRenderPhasePlugin, ViewSortedRenderPhases,
        },
        render_resource::{
            CachedRenderPipelineId, ColorTargetState, ColorWrites, Face, FragmentState,
            PipelineCache, PrimitiveState, RenderPassDescriptor, RenderPipelineDescriptor,
            SpecializedMeshPipeline, SpecializedMeshPipelineError, SpecializedMeshPipelines,
            TextureFormat, VertexState,
        },
        renderer::RenderContext,
        sync_world::MainEntity,
        view::{ExtractedView, RenderVisibleEntities, RetainedViewEntity, ViewTarget},
        Extract, Render, RenderApp, RenderDebugFlags, RenderStartup, RenderSystems,
    },
};
use bevy::{camera::Viewport, core_pipeline::core_3d::CORE_3D_DEPTH_FORMAT};
use bevy_render::{
    globals::{GlobalsBuffer, GlobalsUniform},
    render_resource::{
        BindGroupEntries, BindGroupLayout, BindGroupLayoutEntry, BindingType, BufferBindingType,
        PipelineLayoutDescriptor, RenderPipeline, ShaderModuleDescriptor, ShaderSource,
        ShaderStages, ShaderType, UniformBuffer,
    },
    renderer::{RenderDevice, RenderQueue},
    settings::{RenderCreation, WgpuFeatures, WgpuLimits, WgpuSettings},
    view::{ViewDepthTexture, ViewUniform, ViewUniformOffset, ViewUniforms},
    RenderPlugin,
};
use nonmax::NonMaxU32;
use wgpu::{
    BufferBinding, CompareFunction, DepthBiasState, DepthStencilState, StencilState, StoreOp,
    TaskState,
};

const SHADER_ASSET_PATH: &str = "shaders/custom_stencil.wgsl";

fn main() {
    App::new()
        .add_plugins((
            DefaultPlugins.set(RenderPlugin {
                render_creation: RenderCreation::Automatic(WgpuSettings {
                    features: WgpuFeatures::EXPERIMENTAL_MESH_SHADER
                        | WgpuFeatures::EXPERIMENTAL_PASSTHROUGH_SHADERS,
                    limits: WgpuLimits::default().using_recommended_minimum_mesh_shader_values(),
                    ..default()
                }),
                ..default()
            }),
            MeshStencilPhasePlugin,
        ))
        .add_systems(Startup, setup)
        .add_systems(Update, rotate_camera)
        .run();
}

fn rotate_camera(mut camera: Query<&mut Transform, With<Camera>>, time: Res<Time>) {
    let now = time.elapsed_secs();
    for mut transform in camera.iter_mut() {
        *transform = Transform::from_translation(
            Quat::from_rotation_y(now).mul_vec3(Vec3::new(-2.0, 4.5, 9.0)),
        )
        .looking_at(Vec3::ZERO, Vec3::Y);
    }
}

fn setup(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
) {
    // circular base
    // commands.spawn((
    //     Mesh3d(meshes.add(Circle::new(4.0))),
    //     MeshMaterial3d(materials.add(Color::WHITE)),
    //     Transform::from_rotation(Quat::from_rotation_x(-std::f32::consts::FRAC_PI_2)),
    // ));
    // cube
    // This cube will be rendered by the main pass, but it will also be rendered by our custom
    // pass. This should result in an unlit red cube
    commands.spawn((
        Mesh3d(meshes.add(Cuboid::new(0.5, 0.5, 0.5))),
        MeshMaterial3d(materials.add(Color::srgb_u8(124, 144, 255))),
        Transform::from_xyz(0.0, 0.5, 0.0),
        // This marker component is used to identify which mesh will be used in our custom pass
        // The circle doesn't have it so it won't be rendered in our pass
        DrawStencil,
    ));
    // light
    commands.spawn((
        PointLight {
            shadows_enabled: true,
            ..default()
        },
        Transform::from_xyz(4.0, 8.0, 4.0),
    ));
    // camera
    commands.spawn((
        Camera3d::default(),
        Transform::from_xyz(-2.0, 4.5, 9.0).looking_at(Vec3::ZERO, Vec3::Y),
        // disable msaa for simplicity
        Msaa::Off,
    ));
}

#[derive(Component, ExtractComponent, Clone, Copy, Default)]
struct DrawStencil;

struct MeshStencilPhasePlugin;
impl Plugin for MeshStencilPhasePlugin {
    fn build(&self, app: &mut App) {
        app.add_plugins((
            ExtractComponentPlugin::<DrawStencil>::default(),
            SortedRenderPhasePlugin::<Stencil3d, MeshPipeline>::new(RenderDebugFlags::default()),
        ));
    }
    // We initialize in finish so that the RenderDevice is available for our FromWorld implementation
    fn finish(&self, app: &mut App) {
        // We need to get the render app from the main app
        let Some(render_app) = app.get_sub_app_mut(RenderApp) else {
            return;
        };
        render_app
            .init_resource::<SpecializedMeshPipelines<StencilPipeline>>()
            .init_resource::<DrawFunctions<Stencil3d>>()
            .add_render_command::<Stencil3d, DrawMesh3dStencil>()
            .init_resource::<ViewSortedRenderPhases<Stencil3d>>()
            .add_systems(RenderStartup, init_stencil_pipeline)
            .add_systems(ExtractSchedule, extract_camera_phases)
            .add_systems(
                Render,
                (
                    queue_custom_meshes.in_set(RenderSystems::QueueMeshes),
                    sort_phase_system::<Stencil3d>.in_set(RenderSystems::PhaseSort),
                    batch_and_prepare_sorted_render_phase::<Stencil3d, StencilPipeline>
                        .in_set(RenderSystems::PrepareResources),
                ),
            );

        render_app
            .add_render_graph_node::<ViewNodeRunner<CustomDrawNode>>(Core3d, CustomDrawPassLabel)
            // Tell the node to run after the main pass
            .add_render_graph_edges(Core3d, (Node3d::MainOpaquePass, CustomDrawPassLabel));
    }
}

#[derive(Resource)]
struct StencilPipeline {
    /// The base mesh pipeline defined by bevy
    ///
    /// Since we want to draw a stencil of an existing bevy mesh we want to reuse the default
    /// pipeline as much as possible
    mesh_pipeline: MeshPipeline,
    /// Stores the shader used for this pipeline directly on the pipeline.
    /// This isn't required, it's only done like this for simplicity.
    shader_handle: Handle<Shader>,
}

fn init_stencil_pipeline(
    mut commands: Commands,
    mesh_pipeline: Res<MeshPipeline>,
    asset_server: Res<AssetServer>,
) {
    commands.insert_resource(StencilPipeline {
        mesh_pipeline: mesh_pipeline.clone(),
        shader_handle: asset_server.load(SHADER_ASSET_PATH),
    });
}

// For more information on how SpecializedMeshPipeline work, please look at the
// specialized_mesh_pipeline example
impl SpecializedMeshPipeline for StencilPipeline {
    type Key = MeshPipelineKey;

    fn specialize(
        &self,
        key: Self::Key,
        layout: &MeshVertexBufferLayoutRef,
    ) -> Result<RenderPipelineDescriptor, SpecializedMeshPipelineError> {
        // We will only use the position of the mesh in our shader so we only need to specify that
        let mut vertex_attributes = Vec::new();
        if layout.0.contains(Mesh::ATTRIBUTE_POSITION) {
            // Make sure this matches the shader location
            vertex_attributes.push(Mesh::ATTRIBUTE_POSITION.at_shader_location(0));
        }
        // This will automatically generate the correct `VertexBufferLayout` based on the vertex attributes
        let vertex_buffer_layout = layout.0.get_layout(&vertex_attributes)?;
        let view_layout = self
            .mesh_pipeline
            .get_view_layout(MeshPipelineViewLayoutKey::from(key));
        Ok(RenderPipelineDescriptor {
            label: Some("Specialized Mesh Pipeline".into()),
            // We want to reuse the data from bevy so we use the same bind groups as the default
            // mesh pipeline
            layout: vec![
                // Bind group 0 is the view uniform
                view_layout.main_layout.clone(),
                // Bind group 1 is empty
                view_layout.empty_layout.clone(),
                // Bind group 2 is the mesh uniform
                self.mesh_pipeline.mesh_layouts.model_only.clone(),
            ],
            vertex: VertexState {
                shader: self.shader_handle.clone(),
                buffers: vec![vertex_buffer_layout],
                ..default()
            },
            fragment: Some(FragmentState {
                shader: self.shader_handle.clone(),
                targets: vec![Some(ColorTargetState {
                    format: TextureFormat::bevy_default(),
                    blend: None,
                    write_mask: ColorWrites::ALL,
                })],
                ..default()
            }),
            primitive: PrimitiveState {
                topology: key.primitive_topology(),
                // I think I'm writing the vertices in the wrong order?
                cull_mode: None,
                ..default()
            },
            // It's generally recommended to specialize your pipeline for MSAA,
            // but it's not always possible
            ..default()
        })
    }
}

// We will reuse render commands already defined by bevy to draw a 3d mesh
type DrawMesh3dStencil = (
    SetItemPipeline,
    // This will set the view bindings in group 0
    SetMeshViewBindGroup<0>,
    // This will set an empty bind group in group 1
    SetMeshViewEmptyBindGroup<1>,
    // This will set the mesh bindings in group 2
    SetMeshBindGroup<2>,
    // This will draw the mesh
    DrawMesh,
);

// This is the data required per entity drawn in a custom phase in bevy. More specifically this is the
// data required when using a ViewSortedRenderPhase. This would look differently if we wanted a
// batched render phase. Sorted phases are a bit easier to implement, but a batched phase would
// look similar.
//
// If you want to see how a batched phase implementation looks, you should look at the Opaque2d
// phase.
struct Stencil3d {
    pub sort_key: FloatOrd,
    pub entity: (Entity, MainEntity),
    pub pipeline: CachedRenderPipelineId,
    pub draw_function: DrawFunctionId,
    pub batch_range: Range<u32>,
    pub extra_index: PhaseItemExtraIndex,
    /// Whether the mesh in question is indexed (uses an index buffer in
    /// addition to its vertex buffer).
    pub indexed: bool,
}

// For more information about writing a phase item, please look at the custom_phase_item example
impl PhaseItem for Stencil3d {
    #[inline]
    fn entity(&self) -> Entity {
        self.entity.0
    }

    #[inline]
    fn main_entity(&self) -> MainEntity {
        self.entity.1
    }

    #[inline]
    fn draw_function(&self) -> DrawFunctionId {
        self.draw_function
    }

    #[inline]
    fn batch_range(&self) -> &Range<u32> {
        &self.batch_range
    }

    #[inline]
    fn batch_range_mut(&mut self) -> &mut Range<u32> {
        &mut self.batch_range
    }

    #[inline]
    fn extra_index(&self) -> PhaseItemExtraIndex {
        self.extra_index.clone()
    }

    #[inline]
    fn batch_range_and_extra_index_mut(&mut self) -> (&mut Range<u32>, &mut PhaseItemExtraIndex) {
        (&mut self.batch_range, &mut self.extra_index)
    }
}

impl SortedPhaseItem for Stencil3d {
    type SortKey = FloatOrd;

    #[inline]
    fn sort_key(&self) -> Self::SortKey {
        self.sort_key
    }

    #[inline]
    fn sort(items: &mut [Self]) {
        // bevy normally uses radsort instead of the std slice::sort_by_key
        // radsort is a stable radix sort that performed better than `slice::sort_by_key` or `slice::sort_unstable_by_key`.
        // Since it is not re-exported by bevy, we just use the std sort for the purpose of the example
        items.sort_by_key(SortedPhaseItem::sort_key);
    }

    #[inline]
    fn indexed(&self) -> bool {
        self.indexed
    }
}

impl CachedRenderPipelinePhaseItem for Stencil3d {
    #[inline]
    fn cached_pipeline(&self) -> CachedRenderPipelineId {
        self.pipeline
    }
}

impl GetBatchData for StencilPipeline {
    type Param = (
        SRes<RenderMeshInstances>,
        SRes<RenderAssets<RenderMesh>>,
        SRes<MeshAllocator>,
    );
    type CompareData = AssetId<Mesh>;
    type BufferData = MeshUniform;

    fn get_batch_data(
        (mesh_instances, _render_assets, mesh_allocator): &SystemParamItem<Self::Param>,
        (_entity, main_entity): (Entity, MainEntity),
    ) -> Option<(Self::BufferData, Option<Self::CompareData>)> {
        let RenderMeshInstances::CpuBuilding(ref mesh_instances) = **mesh_instances else {
            error!(
                "`get_batch_data` should never be called in GPU mesh uniform \
                building mode"
            );
            return None;
        };
        let mesh_instance = mesh_instances.get(&main_entity)?;
        let first_vertex_index =
            match mesh_allocator.mesh_vertex_slice(&mesh_instance.mesh_asset_id) {
                Some(mesh_vertex_slice) => mesh_vertex_slice.range.start,
                None => 0,
            };
        let mesh_uniform = {
            let mesh_transforms = &mesh_instance.transforms;
            let (local_from_world_transpose_a, local_from_world_transpose_b) =
                mesh_transforms.world_from_local.inverse_transpose_3x3();
            MeshUniform {
                world_from_local: mesh_transforms.world_from_local.to_transpose(),
                previous_world_from_local: mesh_transforms.previous_world_from_local.to_transpose(),
                lightmap_uv_rect: UVec2::ZERO,
                local_from_world_transpose_a,
                local_from_world_transpose_b,
                flags: mesh_transforms.flags,
                first_vertex_index,
                current_skin_index: u32::MAX,
                material_and_lightmap_bind_group_slot: 0,
                tag: 0,
                pad: 0,
            }
        };
        Some((mesh_uniform, None))
    }
}

impl GetFullBatchData for StencilPipeline {
    type BufferInputData = MeshInputUniform;

    fn get_index_and_compare_data(
        (mesh_instances, _, _): &SystemParamItem<Self::Param>,
        main_entity: MainEntity,
    ) -> Option<(NonMaxU32, Option<Self::CompareData>)> {
        // This should only be called during GPU building.
        let RenderMeshInstances::GpuBuilding(ref mesh_instances) = **mesh_instances else {
            error!(
                "`get_index_and_compare_data` should never be called in CPU mesh uniform building \
                mode"
            );
            return None;
        };
        let mesh_instance = mesh_instances.get(&main_entity)?;
        Some((
            mesh_instance.current_uniform_index,
            mesh_instance
                .should_batch()
                .then_some(mesh_instance.mesh_asset_id),
        ))
    }

    fn get_binned_batch_data(
        (mesh_instances, _render_assets, mesh_allocator): &SystemParamItem<Self::Param>,
        main_entity: MainEntity,
    ) -> Option<Self::BufferData> {
        let RenderMeshInstances::CpuBuilding(ref mesh_instances) = **mesh_instances else {
            error!(
                "`get_binned_batch_data` should never be called in GPU mesh uniform building mode"
            );
            return None;
        };
        let mesh_instance = mesh_instances.get(&main_entity)?;
        let first_vertex_index =
            match mesh_allocator.mesh_vertex_slice(&mesh_instance.mesh_asset_id) {
                Some(mesh_vertex_slice) => mesh_vertex_slice.range.start,
                None => 0,
            };

        Some(MeshUniform::new(
            &mesh_instance.transforms,
            first_vertex_index,
            mesh_instance.material_bindings_index.slot,
            None,
            None,
            None,
        ))
    }

    fn write_batch_indirect_parameters_metadata(
        indexed: bool,
        base_output_index: u32,
        batch_set_index: Option<NonMaxU32>,
        indirect_parameters_buffers: &mut UntypedPhaseIndirectParametersBuffers,
        indirect_parameters_offset: u32,
    ) {
        // Note that `IndirectParameters` covers both of these structures, even
        // though they actually have distinct layouts. See the comment above that
        // type for more information.
        let indirect_parameters = IndirectParametersCpuMetadata {
            base_output_index,
            batch_set_index: match batch_set_index {
                None => !0,
                Some(batch_set_index) => u32::from(batch_set_index),
            },
        };

        if indexed {
            indirect_parameters_buffers
                .indexed
                .set(indirect_parameters_offset, indirect_parameters);
        } else {
            indirect_parameters_buffers
                .non_indexed
                .set(indirect_parameters_offset, indirect_parameters);
        }
    }

    fn get_binned_index(
        _param: &SystemParamItem<Self::Param>,
        _query_item: MainEntity,
    ) -> Option<NonMaxU32> {
        None
    }
}

// When defining a phase, we need to extract it from the main world and add it to a resource
// that will be used by the render world. We need to give that resource all views that will use
// that phase
fn extract_camera_phases(
    mut stencil_phases: ResMut<ViewSortedRenderPhases<Stencil3d>>,
    cameras: Extract<Query<(Entity, &Camera), With<Camera3d>>>,
    mut live_entities: Local<HashSet<RetainedViewEntity>>,
) {
    live_entities.clear();
    for (main_entity, camera) in &cameras {
        if !camera.is_active {
            continue;
        }
        // This is the main camera, so we use the first subview index (0)
        let retained_view_entity = RetainedViewEntity::new(main_entity.into(), None, 0);

        stencil_phases.insert_or_clear(retained_view_entity);
        live_entities.insert(retained_view_entity);
    }

    // Clear out all dead views.
    stencil_phases.retain(|camera_entity, _| live_entities.contains(camera_entity));
}

// This is a very important step when writing a custom phase.
//
// This system determines which meshes will be added to the phase.
fn queue_custom_meshes(
    custom_draw_functions: Res<DrawFunctions<Stencil3d>>,
    mut pipelines: ResMut<SpecializedMeshPipelines<StencilPipeline>>,
    pipeline_cache: Res<PipelineCache>,
    custom_draw_pipeline: Res<StencilPipeline>,
    render_meshes: Res<RenderAssets<RenderMesh>>,
    render_mesh_instances: Res<RenderMeshInstances>,
    mut custom_render_phases: ResMut<ViewSortedRenderPhases<Stencil3d>>,
    mut views: Query<(&ExtractedView, &RenderVisibleEntities, &Msaa)>,
    has_marker: Query<(), With<DrawStencil>>,
) {
    for (view, visible_entities, msaa) in &mut views {
        let Some(custom_phase) = custom_render_phases.get_mut(&view.retained_view_entity) else {
            continue;
        };
        let draw_custom = custom_draw_functions.read().id::<DrawMesh3dStencil>();

        // Create the key based on the view.
        // In this case we only care about MSAA and HDR
        let view_key = MeshPipelineKey::from_msaa_samples(msaa.samples())
            | MeshPipelineKey::from_hdr(view.hdr);

        let rangefinder = view.rangefinder3d();
        // Since our phase can work on any 3d mesh we can reuse the default mesh 3d filter
        for (render_entity, visible_entity) in visible_entities.iter::<Mesh3d>() {
            // We only want meshes with the marker component to be queued to our phase.
            if has_marker.get(*render_entity).is_err() {
                continue;
            }
            let Some(mesh_instance) = render_mesh_instances.render_mesh_queue_data(*visible_entity)
            else {
                continue;
            };
            let Some(mesh) = render_meshes.get(mesh_instance.mesh_asset_id) else {
                continue;
            };

            // Specialize the key for the current mesh entity
            // For this example we only specialize based on the mesh topology
            // but you could have more complex keys and that's where you'd need to create those keys
            let mut mesh_key = view_key;
            mesh_key |= MeshPipelineKey::from_primitive_topology(mesh.primitive_topology());

            let pipeline_id = pipelines.specialize(
                &pipeline_cache,
                &custom_draw_pipeline,
                mesh_key,
                &mesh.layout,
            );
            let pipeline_id = match pipeline_id {
                Ok(id) => id,
                Err(err) => {
                    error!("{}", err);
                    continue;
                }
            };
            let distance = rangefinder.distance(&mesh_instance.center);
            // At this point we have all the data we need to create a phase item and add it to our
            // phase
            custom_phase.add(Stencil3d {
                // Sort the data based on the distance to the view
                sort_key: FloatOrd(distance),
                entity: (*render_entity, *visible_entity),
                pipeline: pipeline_id,
                draw_function: draw_custom,
                // Sorted phase items aren't batched
                batch_range: 0..1,
                extra_index: PhaseItemExtraIndex::None,
                indexed: mesh.indexed(),
            });
        }
    }
}

// Render label used to order our render graph node that will render our phase
#[derive(RenderLabel, Debug, Clone, Hash, PartialEq, Eq)]
struct CustomDrawPassLabel;

struct CustomDrawNode {
    mesh_pipeline: RenderPipeline,
    bind_group_data: BindGroupLayout,
    // time_bind_group: BindGroup,
    // time_uniform_buffer: UniformBuffer<ShaderData>,
}

#[derive(ShaderType)]
struct ShaderData {
    time: f32,
}

impl FromWorld for CustomDrawNode {
    fn from_world(world: &mut World) -> Self {
        let device = world.resource::<RenderDevice>();
        #[allow(unsafe_code)]
        let task_shader = unsafe {
            device.create_shader_module(ShaderModuleDescriptor {
                label: Some("task_shader"),
                source: ShaderSource::Wgsl(
                    include_str!("../../assets/shaders/mesh_shader/task.wgsl").into(),
                ),
            })
        };
        #[allow(unsafe_code)]
        let mesh_shader = unsafe {
            device.create_shader_module(ShaderModuleDescriptor {
                label: Some("mesh_shader"),
                source: ShaderSource::Wgsl(
                    include_str!("../../assets/shaders/mesh_shader/mesh.wgsl").into(),
                ),
            })
        };
        #[allow(unsafe_code)]
        let fragment_shader = unsafe {
            device.create_shader_module(ShaderModuleDescriptor {
                label: Some("fragment_shader"),
                source: ShaderSource::Wgsl(
                    include_str!("../../assets/shaders/mesh_shader/fragment.wgsl").into(),
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
            label: "triangle_layout".into(),
            bind_group_layouts: &[&bind_group_data],
            immediate_size: 0,
        });

        let mesh_pipeline =
            device
                .wgpu_device()
                .create_mesh_pipeline(&wgpu::MeshPipelineDescriptor {
                    label: "mesh_shader_pipeline".into(),
                    layout: Some(&pipeline_layout),
                    task: Some(TaskState {
                        // module: &task_shader,
                        module: &task_shader,
                        entry_point: "task".into(),
                        compilation_options: Default::default(),
                    }),
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

        CustomDrawNode {
            mesh_pipeline: mesh_pipeline.into(),
            bind_group_data,
        }
    }
}

impl ViewNode for CustomDrawNode {
    type ViewQuery = (
        &'static ExtractedCamera,
        &'static ExtractedView,
        &'static ViewTarget,
        &'static ViewDepthTexture,
        &'static ViewUniformOffset,
        Option<&'static MainPassResolutionOverride>,
    );

    fn run<'w>(
        &self,
        _graph: &mut RenderGraphContext,
        render_context: &mut RenderContext<'w>,
        (camera, _view, target, depth, view_uniform_offset, resolution_override): QueryItem<
            'w,
            '_,
            Self::ViewQuery,
        >,
        world: &'w World,
    ) -> Result<(), NodeRunError> {
        // Get the view entity from the graph
        // let view_entity = graph.view_entity();

        let view_uniforms_resource = world.resource::<ViewUniforms>();
        let view_uniforms = &view_uniforms_resource.uniforms;
        let view_uniforms_buffer = view_uniforms.buffer().unwrap();

        let globals_buffer = world.resource::<GlobalsBuffer>();

        // let (
        //     Ok((view_uniform_offset, view_target, auto_exposure, view)),
        //     Some(auto_exposure_buffers),
        // ) = (
        //     self.query.get_manual(world, view_entity),
        //     auto_exposure_buffers.buffers.get(&view_entity),
        // )
        // else {
        //     return Ok(());
        // };

        let data = ShaderData {
            time: world.resource::<Time>().elapsed_secs(),
        };
        let mut time_uniform_buffer = UniformBuffer::from(data);
        let queue = world.resource::<RenderQueue>();
        time_uniform_buffer.write_buffer(&render_context.render_device(), &queue);

        let time_bind_group = render_context.render_device().create_bind_group(
            "time_bind_group",
            &self.bind_group_data,
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
                        label: Some("mesh shader pass"),
                        // Write directly to the view target
                        color_attachments: &[Some(target.get_color_attachment())],
                        depth_stencil_attachment: Some(depth.get_attachment(StoreOp::Store)),
                        timestamp_writes: None,
                        occlusion_query_set: None,
                        multiview_mask: None,
                    });

            render_pass.push_debug_group("Prepare data for draw.");
            render_pass.set_pipeline(&self.mesh_pipeline);
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
            render_pass.draw_mesh_tasks(1, 1, 1);
        }

        Ok(())
    }
}
