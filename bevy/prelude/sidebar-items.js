initSidebarItems({"attr":[["bevy_main",""],["reflect_trait",""]],"derive":[["AmbiguitySetLabel",""],["Bundle",""],["Component",""],["Deref","Implements `Deref` for single-item structs. This is especially useful when utilizing the newtype pattern."],["DerefMut","Implements `DerefMut` for single-item structs. This is especially useful when utilizing the newtype pattern."],["DynamicPlugin","Generates a dynamic plugin entry point function for the given `Plugin` type."],["Reflect",""],["RunCriteriaLabel",""],["StageLabel",""],["SystemLabel",""]],"enum":[["AlignContent","Defines how each line is aligned within the flexbox."],["AlignItems","How items are aligned according to the cross axis"],["AlignSelf","Works like [`AlignItems`] but applies only to a single item"],["AlphaMode","Alpha mode"],["AssetEvent","Events that involve assets of type `T`."],["Color",""],["CoreStage","The names of the default [`App`] stages."],["CursorIcon","The icon to display for a window’s cursor."],["Direction","Defines the text direction"],["Display","Whether to use Flexbox layout"],["EulerRot","Euler rotation sequences."],["FileDragAndDrop","Events related to files being dragged and dropped on a window."],["FlexDirection","Defines how flexbox items are ordered within a flexbox"],["FlexWrap","Defines if flexbox items appear on a single line or on multiple lines"],["GamepadAxisType",""],["GamepadButtonType",""],["GamepadEventType",""],["HorizontalAlign","Describes horizontal alignment preference for positioning & bounds."],["Interaction","Describes what type of input interaction has occurred for a UI node."],["JustifyContent","Defines how items are aligned according to the main axis"],["KeyCode","The key code of a `KeyboardInput`."],["Keyframes","List of keyframes for one of the attribute of a [`Transform`]."],["MonitorSelection","Defines which monitor to use."],["MouseButton","A button on a mouse device."],["Overflow","Whether to show or hide overflowing items"],["PositionType","The strategy used to position this node"],["StartupStage","The names of the default [`App`] startup stages."],["TextError",""],["Val","An enum that describes possible types of value in flexbox layout options"],["VerticalAlign","Describes vertical alignment preference for positioning & bounds. Currently a placeholder for future functionality."],["WindowPosition","Defines where window should be placed at on creation."]],"fn":[["default","An ergonomic abbreviation for [`Default::default()`] to make initializing structs easier. This is especially helpful when combined with “struct update syntax”."],["despawn_with_children_recursive","Function for despawning an entity and all its children"],["dynamically_load_plugin","Dynamically links a plugin at the given path. The plugin must export a function with the [`CreatePlugin`] signature named `_bevy_create_plugin`."]],"macro":[["debug","Constructs an event at the debug level."],["debug_span","Constructs a span at the debug level."],["error","Constructs an event at the error level."],["error_span","Constructs a span at the error level."],["info","Constructs an event at the info level."],["info_span","Constructs a span at the info level."],["trace","Constructs an event at the trace level."],["trace_span","Constructs a span at the trace level."],["warn","Constructs an event at the warn level."],["warn_span","Constructs a span at the warn level."]],"mod":[["shape","Generation for some primitive shape meshes."]],"struct":[["AddChild","Command that adds a child to an entity"],["Added","A filter on a component that only retains results added after the system last ran."],["AmbientLight","An ambient light, which lights the entire scene equally."],["AnimationClip","A list of [`VariableCurve`], and the [`EntityPath`] to which they apply."],["AnimationPlayer","Animation controls"],["AnimationPlugin","Adds animation support to an app"],["AnyOf","The `AnyOf` query parameter fetches entities with any of the component types included in T."],["App","A container of app logic and data."],["AssetServer","Loads assets from the filesystem in the background."],["Assets","Stores Assets of a given type and tracks changes to them."],["Audio","Use this resource to play audio"],["AudioOutput","Used internally to play audio on the current “audio device”"],["AudioSource","A source of audio data"],["Axis","Stores the position data of the input devices of type `T`."],["BVec2","A 2-dimensional boolean vector."],["BVec3","A 3-dimensional boolean vector."],["BVec4","A 4-dimensional boolean vector."],["Button","Marker struct for buttons"],["ButtonBundle","A UI node that is a button"],["CalculatedClip","The calculated clip of the node"],["CalculatedSize","The calculated size of the node"],["Camera",""],["Camera2d",""],["Camera2dBundle",""],["Camera3d","Configuration for the “main 3d render graph”."],["Camera3dBundle",""],["ChangeTrackers","[`WorldQuery`] that tracks changes and additions for component `T`."],["Changed","A filter on a component that only retains results added or mutably dereferenced after the system last ran."],["ChildBuilder","Struct for building children onto an entity"],["Children","Contains references to the child entities of this entity"],["ClearColor","When used as a resource, sets the color that is used to clear the screen between frames."],["ColorMaterial","A 2d material that renders 2d meshes with a texture tinted by a uniform color"],["Commands","A queue of commands that get executed at the end of the stage of the system that called them."],["ComputedVisibility","Algorithmically-computed indication of whether an entity is visible and should be extracted for rendering"],["CursorEntered","An event that is sent whenever the user’s cursor enters a window."],["CursorLeft","An event that is sent whenever the user’s cursor leaves a window."],["CursorMoved","An event reporting that the mouse cursor has moved on a window."],["DefaultPlugins","This plugin group will add all the default plugins:"],["DefaultTaskPoolOptions","Helper for configuring and creating the default task pools. For end-users who want full control, insert the default task pools into the resource map manually. If the pools are already inserted, this helper will do nothing."],["DespawnChildrenRecursive","Despawns the given entity’s children recursively"],["DespawnRecursive","Despawns the given entity and all its children recursively"],["DirectionalLight","A Directional light."],["DirectionalLightBundle","A component bundle for [`DirectionalLight`] entities."],["DynamicScene","A collection of serializable dynamic entities, each with its own run-time defined set of components. To spawn a dynamic scene, you can use either:"],["DynamicSceneBundle","A component bundle for a [`DynamicScene`] root."],["Entity","Lightweight identifier of an entity."],["EntityPath","Path to an entity, with [`Name`]s. Each entity in a path must have a name."],["EventReader","Reads events of type `T` in order and tracks which events have already been read."],["EventWriter","Sends events of type `T`."],["Events","An event collection that represents the events that occurred within the last two [`Events::update`] calls. Events can be written to using an [`EventWriter`] and are typically cheaply read using an [`EventReader`]."],["Font",""],["Gamepad",""],["GamepadAxis",""],["GamepadButton",""],["GamepadEvent",""],["Gamepads","Container of unique connected [`Gamepad`]s"],["GilrsPlugin",""],["GlobalTransform","Describe the position of an entity relative to the reference frame."],["Handle","A handle into a specific [`Asset`] of type `T`."],["HandleUntyped","A non-generic version of [`Handle`]."],["HierarchyPlugin","The base plugin for handling [`Parent`] and [`Children`] components"],["IVec2","A 2-dimensional vector."],["IVec3","A 3-dimensional vector."],["IVec4","A 4-dimensional vector."],["Image",""],["ImageBundle","A UI node that is an image"],["In","Wrapper type to mark a [`SystemParam`] as an input."],["Input","A “press-able” input of type `T`."],["InsertChildren","Command that inserts a child at a given index of a parent’s children, shifting following children back"],["Local","A system local [`SystemParam`]."],["Mat3","A 3x3 column major matrix."],["Mat4","A 4x4 column major matrix."],["MaterialMeshBundle","A component bundle for entities with a [`Mesh`] and a [`Material`]."],["MaterialPlugin","Adds the necessary ECS resources and render logic to enable rendering entities using the given [`Material`] asset type."],["Mesh",""],["MinimalPlugins","Minimal plugin group that will add the following plugins:"],["Msaa","Configuration resource for Multi-Sample Anti-Aliasing."],["Mut","Unique mutable borrow of an entity’s component"],["Name","Component used to identify an entity. Stores a hash for faster comparisons The hash is eagerly re-computed upon each update to the name."],["Node","Describes the size of a UI node"],["NodeBundle","The basic UI node"],["NonSend","Shared borrow of a non-[`Send`] resource."],["NonSendMut","Unique borrow of a non-[`Send`] resource."],["Or","A filter that tests if any of the given filters apply."],["OrthographicProjection",""],["ParallelCommands","An alternative to [`Commands`] that can be used in parallel contexts, such as those in `Query::par_for_each`"],["ParamSet",""],["Parent","Holds a reference to the parent entity of this entity. This component should only be present on entities that actually have a parent entity."],["PerspectiveProjection",""],["PlaybackSettings","Settings to control playback from the start."],["PointLight","A light that emits light in all directions from a central point."],["PointLightBundle","A component bundle for [`PointLight`] entities."],["PushChildren","Command that pushes children to the end of the entity’s children"],["Quat","A quaternion representing an orientation."],["Query","Provides scoped access to components in a [`World`]."],["QueryState","Provides scoped access to a [`World`] state according to a given [`WorldQuery`] and query filter."],["ReceivedCharacter","An event that is sent whenever a window receives a character from the OS or underlying system."],["ReflectComponent","A struct used to operate on reflected [`Component`] of a type."],["ReflectDefault","A struct used to provide the default value of a type."],["ReflectDeserialize","A struct used to deserialize reflected instances of a type."],["ReflectResource","A struct used to operate on reflected [`Resource`] of a type."],["ReflectSerialize","A struct used to serialize reflected instances of a type."],["RemoveChildren","Command that removes children from an entity, and removes that child’s parent and inserts it into the previous parent component"],["RemovedComponents","A [`SystemParam`] that grants access to the entities that had their `T` [`Component`] removed."],["Res","Shared borrow of a resource."],["ResMut","Unique mutable borrow of a resource."],["RunCriteria",""],["Scene","To spawn a scene, you can use either:"],["SceneBundle","A component bundle for a [`Scene`] root."],["SceneSpawner",""],["Schedule","A container of [`Stage`]s set to be run in a linear order."],["Shader","A shader, as defined by its [`ShaderSource`] and `ShaderStage` This is an “unprocessed” shader. It can contain preprocessor directives."],["Size","A two dimensional “size” as defined by a width and height"],["SpotLight","A light that emits light in a given direction from a central point. Behaves like a point light in a perfectly absorbant housing that shines light only in a given direction. The direction is taken from the transform, and can be specified with `Transform::looking_at`."],["SpotLightBundle","A component bundle for spot light entities"],["Sprite",""],["SpriteBundle",""],["SpriteSheetBundle","A Bundle of components for drawing a single sprite from a sprite sheet (also referred to as a `TextureAtlas`)"],["StandardMaterial","A material with “standard” properties used in PBR lighting Standard property values with pictures here https://google.github.io/filament/Material%20Properties.pdf."],["StartupSchedule","The label for the startup `Schedule`, which runs once at the beginning of the [`App`]."],["State","Stack based state machine"],["Style","Describes the style of a UI node"],["SystemSet","A builder for describing several systems at the same time."],["SystemStage","Stores and executes systems. Execution order is not defined unless explicitly specified; see `SystemDescriptor` documentation."],["Text",""],["Text2dBundle","The bundle of components needed to draw text in a 2D scene via a 2D `Camera2dBundle`. Example usage."],["TextAlignment",""],["TextBundle","A UI node that is text"],["TextSection",""],["TextStyle",""],["TextureAtlas","An atlas containing multiple textures (like a spritesheet or a tilemap). Example usage animating sprite. Example usage loading sprite sheet."],["TextureAtlasBuilder","A builder which is used to create a texture atlas from many individual sprites."],["TextureAtlasSprite",""],["Time","Tracks elapsed time since the last update and since the App has started"],["Timer","Tracks elapsed time. Enters the finished state once `duration` is reached."],["TouchInput","A touch input event."],["Touches","A collection of [`Touch`]es."],["Transform","Describe the position of an entity. If the entity has a parent, the position is relative to its parent position."],["TransformBundle","A [`Bundle`] of the [`Transform`] and [`GlobalTransform`] `Component`s, which describe the position of an entity."],["TransformPlugin","The base plugin for handling [`Transform`] components"],["UVec2","A 2-dimensional vector."],["UVec3","A 3-dimensional vector."],["UVec4","A 4-dimensional vector."],["UiCameraConfig","Configuration for cameras related to UI."],["UiColor","The color of the node"],["UiImage","The image of the node"],["UiRect","A rect, as defined by its “side” locations"],["VariableCurve","Describes how an attribute of a [`Transform`] should be animated."],["Vec2","A 2-dimensional vector."],["Vec3","A 3-dimensional vector."],["Vec4","A 4-dimensional vector with SIMD support."],["Visibility","User indication of whether an entity is visible"],["Window","An operating system window that can present content and receive user input."],["WindowDescriptor","Describes the information needed for creating a window."],["WindowMoved","An event that is sent when a window is repositioned in physical pixels."],["Windows","A collection of [`Window`]s with unique [`WindowId`]s."],["With","Filter that selects entities with a component `T`."],["Without","Filter that selects entities without a component `T`."],["World","Stores and exposes operations on entities, components, resources, and their associated metadata."],["WorldChildBuilder","Struct for adding children to an entity directly through the [`World`] for use in exclusive systems"]],"trait":[["AddAsset","[`App`] extension methods for adding new asset types."],["AmbiguitySetLabel","Defines a set of strongly-typed labels for a class of objects"],["BuildChildren","Trait defining how to build children"],["BuildWorldChildren","Trait that defines adding children to an entity directly through the [`World`]"],["Bundle","An ordered collection of [`Component`]s."],["Component","A data type that can be used to store data for an entity."],["Decodable","A type implementing this trait can be decoded as a rodio source"],["DespawnRecursiveExt","Trait that holds functions for despawning recursively down the transform hierarchy"],["DetectChanges","Types that implement reliable change detection."],["DynamicPluginExt",""],["ExclusiveSystemDescriptorCoercion",""],["FromWorld","Creates an instance of the type this trait is implemented for using data from the supplied [World]."],["GetField","A convenience trait which combines fetching and downcasting of struct fields."],["GetTupleStructField","A convenience trait which combines fetching and downcasting of tuple struct fields."],["IntoChainSystem","An extension trait providing the [`IntoChainSystem::chain`] method for convenient [`System`] chaining."],["IntoExclusiveSystem",""],["IntoSystem","Conversion trait to turn something into a [`System`]."],["Material","Materials are used alongside [`MaterialPlugin`] and `MaterialMeshBundle` to spawn entities that are rendered with a specific [`Material`] type. They serve as an easy to use high level way to render [`Mesh`] entities with custom shader logic."],["ParallelSystemDescriptorCoercion",""],["Plugin","A collection of Bevy app logic and configuration."],["PluginGroup","Combines multiple [`Plugin`]s into a single unit."],["Reflect","A reflected Rust type."],["RunCriteriaDescriptorCoercion",""],["RunCriteriaLabel","Defines a set of strongly-typed labels for a class of objects"],["Stage","A type that can run as a step of a `Schedule`."],["StageLabel","Defines a set of strongly-typed labels for a class of objects"],["Struct","A reflected Rust regular struct type."],["System","An ECS system that can be added to a `Schedule`"],["SystemLabel","Defines a set of strongly-typed labels for a class of objects"],["SystemParamFunction","A trait implemented for all functions that can be used as [`System`]s."],["TupleStruct","A reflected Rust tuple struct."]],"type":[["ColorMesh2dBundle","A component bundle for entities with a `Mesh2dHandle` and a [`ColorMaterial`]."],["PbrBundle","A component bundle for PBR entities with a [`Mesh`] and a [`StandardMaterial`]."]]});