@tool
extends MeshInstance3D
class_name PlanarReflectorGDSCriptCompositor

var reflect_camera: Camera3D
var reflect_viewport: SubViewport
var editor_camera: Camera3D = null
@export var main_camera: Camera3D = null
@export var reflection_camera_resolution: Vector2i = Vector2i(1920, 1080)
@export_group("Camera Controls")
@export var ortho_scale_multiplier: float = 1.0
@export var ortho_uv_scale: float = 1.0
@export var auto_detect_camera_mode: bool = true
@export_group("Reflection Layers and Environment")
@export_flags_3d_render var reflection_layers: int = 1
@export var use_custom_environment: bool = true
@export var custom_environment: Environment = null
#NEW EXPORTS
@export_group("Reflection Intersection masking")
@export var hide_intersect_reflections: bool = true
@export var override_YAxis_height: bool = false
@export var new_YAxis_height: float = 0.0

@export_group("Reflection Offset Control")
@export var enable_reflection_offset: bool = false
@export var reflection_offset_position: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var reflection_offset_rotation: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var reflection_offset_scale: float = 1.0
@export var offset_blend_mode: int = 0
@export_group("Performance Controls")
@export var update_frequency: int = 1
@export var use_lod: bool = true
@export var lod_distance_near: float = 10.0
@export var lod_distance_far: float = 30.0
@export var lod_resolution_multiplier: float = 0.45

#TODO:
#1 - add a export bool under Reflection Layers and Environment" to enable CompositorEffect "WaterMask"
#2 Add exporrt variables to be passed to the CompositorEffect: EffectEnabled, WaterHeight, etc. # Need to make sure this are constantly synced (in Process) as we can change water height in the editor
#3 Merge/Pass the Updates from this script to the CPP version and push the latest WaterShader to my projects
#debug test
@onready var test_camera: Camera3D = %ReflectionCamera3D

var editor_helper: Node = null
var active_shader_material: ShaderMaterial = null
var reflection_compositor_effect: ReflectionCompositor = null

var frame_counter: int = 0
var last_camera_position: Vector3 = Vector3.ZERO
var last_camera_rotation: Basis = Basis()
var position_threshold: float = 0.01
var rotation_threshold: float = 0.001

var cached_reflection_plane: Plane = Plane()
var is_layer_one_active: bool = true

var cached_offset_transform: Transform3D = Transform3D.IDENTITY
var last_offset_position: Vector3 = Vector3.ZERO
var last_offset_rotation: Vector3 = Vector3.ZERO

func _ready() -> void:
	intial_setup()

func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if reflect_camera and reflect_camera.compositor:
			update_compositor_reflection_effect(get_reflection_effect(reflect_camera.compositor))

func intial_setup() -> void:
	#Core Setup
	add_to_group("planar_reflectors")
	find_editor_helper()
	setup_reflection_camera_and_viewport()
	update_offset_cache()

	#Regular update loop
	update_reflect_viewport_size()
	set_reflection_camera_transform()

func _process(_delta: float) -> void:
	update_reflect_viewport_size()
	frame_counter += 1
	update_offset_cache()
	var should_update: bool = (frame_counter % update_frequency == 0)
	if should_update:
		var active_cam: Camera3D = editor_camera if Engine.is_editor_hint() else main_camera
		if active_cam:
			var current_pos: Vector3 = active_cam.global_transform.origin
			var current_basis: Basis = active_cam.global_transform.basis
			if last_camera_position != Vector3.ZERO:
				var pos_diff: float = current_pos.distance_to(last_camera_position)
				var rot_diff: float = current_basis.get_euler().distance_to(last_camera_rotation.get_euler())
				if pos_diff < position_threshold and rot_diff < rotation_threshold:
					return
			last_camera_position = current_pos
			last_camera_rotation = current_basis
			set_reflection_camera_transform()


func setup_reflection_camera_and_viewport() -> void:
	#Setup the reflection viewport
	reflect_viewport = SubViewport.new()
	reflect_viewport.name = "ReflectionViewPort"
	add_child(reflect_viewport)
	reflect_viewport.size = reflection_camera_resolution
	reflect_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	reflect_viewport.msaa_3d = Viewport.MSAA_DISABLED
	reflect_viewport.positional_shadow_atlas_size = 2048
	reflect_viewport.own_world_3d = false
	reflect_viewport.transparent_bg = true

	#Setup the reflection camera
	reflect_camera = Camera3D.new()
	reflect_viewport.add_child(reflect_camera)
	
	#Setup the reflection camera cull mask / layers
	var cull_mask: int = reflection_layers
	reflect_camera.cull_mask = cull_mask
	is_layer_one_active = bool(cull_mask & (1 << 0))
	if not is_layer_one_active:
		print("Layer 1 not active, make sure to add the layers to the scene Lights cull masks")
	
	#copy main camera properties to reflection camera
	if main_camera:
		reflect_camera.attributes = main_camera.attributes
		reflect_camera.doppler_tracking = main_camera.doppler_tracking
	reflect_camera.current = true
	reflect_camera.make_current()

	#TODO: CHECK IF THE CODE BELOW NEEDS TO BE IN THIS METHOD THAT RUNS IN "PROCCESS" OR JUST IN THE INTIIAL SETUP
	#debug

	#after camera setup, we can set the camera environment
	setup_reflection_environment()

	#Setup the reflection camera CompositorEffect
	if hide_intersect_reflections:
		setup_compositor_reflection_effect(reflect_camera)
		setup_compositor_reflection_effect(test_camera) # debug test
	else:
		clear_compositor_reflection_effect(reflect_camera)
		clear_compositor_reflection_effect(test_camera)# debug test

func setup_reflection_environment() -> void:
	#Prepare or copy the environment for the reflection camera
	var reflection_env: Environment = Environment.new()
	if use_custom_environment:
		if custom_environment:
			reflection_env = custom_environment
	else:
		reflection_env.background_mode = Environment.BG_CLEAR_COLOR
		reflection_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		reflection_env.ambient_light_color = Color.LIGHT_GRAY
		reflection_env.ambient_light_energy = 1
	
	reflect_camera.environment = reflection_env

func calculate_reflection_plane() -> Plane:
	var reflection_transform: Transform3D = global_transform * Transform3D().rotated(Vector3.RIGHT, PI/2)
	var plane_origin: Vector3 = reflection_transform.origin
	var plane_normal: Vector3 = reflection_transform.basis.z.normalized()
	return Plane(plane_normal, plane_origin.dot(plane_normal))

func set_reflection_camera_transform() -> void:
	var active_camera: Camera3D = main_camera
	find_editor_helper()
	if Engine.is_editor_hint():
		if editor_camera:
			active_camera = editor_camera
			active_camera.name = "EditorCamera"

	if active_camera == null:
		return
	update_camera_projection()
	var reflection_plane: Plane = calculate_reflection_plane()
	cached_reflection_plane = reflection_plane
	var cam_pos: Vector3 = active_camera.global_transform.origin
	var proj_pos: Vector3 = reflection_plane.project(cam_pos)
	var mirrored_pos: Vector3 = cam_pos + (proj_pos - cam_pos) * 2.0
	var base_reflection_transform: Transform3D = Transform3D()
	base_reflection_transform.origin = mirrored_pos
	var main_basis: Basis = active_camera.global_transform.basis
	var n: Vector3 = reflection_plane.normal
	var reflection_basis: Basis = Basis(
		main_basis.x.normalized().bounce(n).normalized(),
		main_basis.y.normalized().bounce(n).normalized(),
		main_basis.z.normalized().bounce(n).normalized()
	)
	base_reflection_transform.basis = reflection_basis
	var final_reflection_transform: Transform3D = apply_reflection_offset(base_reflection_transform)
	reflect_camera.global_transform = final_reflection_transform
	
	#To ensure sync, we update shaders afterr the camera render data is updated
	update_shader_parameters()

func update_shader_parameters() -> void:
	if active_shader_material == null:
		active_shader_material = get_active_material(0)
	var material: ShaderMaterial = active_shader_material
	if material == null:
		return
	material.set_shader_parameter("reflection_screen_texture", reflect_viewport.get_texture())
	var is_orthogonal: bool = false
	if Engine.is_editor_hint():
		is_orthogonal = reflect_camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	else:
		is_orthogonal = (main_camera and main_camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	material.set_shader_parameter("is_orthogonal_camera", is_orthogonal)
	material.set_shader_parameter("ortho_uv_scale", ortho_uv_scale)
	material.set_shader_parameter("reflection_offset_enabled", enable_reflection_offset)
	material.set_shader_parameter("reflection_offset_position", reflection_offset_position)
	material.set_shader_parameter("reflection_offset_scale", reflection_offset_scale)
	material.set_shader_parameter("reflection_plane_normal", cached_reflection_plane.normal)
	material.set_shader_parameter("reflection_plane_distance", cached_reflection_plane.d)
	material.set_shader_parameter("planar_surface_y", global_transform.origin.y)

func update_camera_projection() -> void:
	var active_cam: Camera3D = editor_camera if Engine.is_editor_hint() else main_camera
	if active_cam == null:
		return
	if auto_detect_camera_mode:
		reflect_camera.projection = active_cam.projection
	if reflect_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		reflect_camera.size = active_cam.size * ortho_scale_multiplier
	else:
		reflect_camera.fov = active_cam.fov

func update_reflect_viewport_size() -> void:
	var target_size: Vector2i

	if Engine.is_editor_hint() and editor_helper and editor_helper.has_method("get_editor_viewport_size"):
		target_size = editor_helper.call("get_editor_viewport_size")
		if typeof(target_size) != TYPE_VECTOR2I:
			target_size = get_viewport().get_visible_rect().size
	else:
		target_size = get_viewport().get_visible_rect().size

	var active_cam: Camera3D = editor_camera if Engine.is_editor_hint() else main_camera
	
	if use_lod and active_cam:
		var distance: float = global_transform.origin.distance_to(active_cam.global_transform.origin)
		var lod_factor: float = 1.0
		if distance > lod_distance_near:
			var lerp_factor: float = clamp((distance - lod_distance_near) / (lod_distance_far - lod_distance_near), 0.0, 1.0)
			lod_factor = lerp(1.0, lod_resolution_multiplier, lerp_factor)
		target_size = Vector2i(target_size * lod_factor)
		target_size.x = max(target_size.x, 128)
		target_size.y = max(target_size.y, 128)
	
	reflect_viewport.size = target_size

func apply_reflection_offset(base_transform: Transform3D) -> Transform3D:
	if not enable_reflection_offset:
		return base_transform
	var result_transform: Transform3D = base_transform
	
	match offset_blend_mode:
		0:
			result_transform.origin += cached_offset_transform.origin
			if reflection_offset_rotation != Vector3.ZERO:
				result_transform.basis = result_transform.basis * cached_offset_transform.basis
		1:
			result_transform = result_transform * cached_offset_transform
		2:
			if main_camera:
				var view_offset: Vector3 = main_camera.global_transform.basis * cached_offset_transform.origin
				result_transform.origin += view_offset
				result_transform.basis = result_transform.basis * cached_offset_transform.basis
	return result_transform

func update_offset_cache() -> void:
	if not enable_reflection_offset:
		cached_offset_transform = Transform3D.IDENTITY
		return
	if (last_offset_position != reflection_offset_position or last_offset_rotation != reflection_offset_rotation):
		var offset_basis: Basis = Basis()
		offset_basis = offset_basis.rotated(Vector3.RIGHT, deg_to_rad(reflection_offset_rotation.x))
		offset_basis = offset_basis.rotated(Vector3.UP, deg_to_rad(reflection_offset_rotation.y))
		offset_basis = offset_basis.rotated(Vector3.FORWARD, deg_to_rad(reflection_offset_rotation.z))
		cached_offset_transform = Transform3D(offset_basis, reflection_offset_position * reflection_offset_scale)
		last_offset_position = reflection_offset_position
		last_offset_rotation = reflection_offset_rotation

#region - EDITOR AND PLUGIN HELPER METHODS
#EDITOR HELPER METHOS
func find_editor_helper() -> void:
	if Engine.is_editor_hint():
		if Engine.has_singleton("PlanarReflectorEditorHelper"):
			editor_helper = Engine.get_singleton("PlanarReflectorEditorHelper")

func set_editor_camera(viewport_camera: Camera3D) -> void:
	editor_camera = viewport_camera
	# printt("GDSCript SET Editor Camera: ", editor_camera.name)
	update_reflect_viewport_size()
	set_reflection_camera_transform()

func is_planar_reflector_active() -> bool:
	return true

func get_active_camera() -> Camera3D:
	return main_camera


#endregion

#region- REFLECTION COMPOSITOR AND REFLECTION MASK METHODS
func setup_compositor_reflection_effect(reflect_cam: Camera3D) -> void:
	if reflect_cam.compositor == null:
		if reflect_cam.compositor:
			clear_compositor_reflection_effect(reflect_cam)
		reflect_cam.compositor = Compositor.new()

	#Check if the compositor already has the Compositor effect required "ReflectionCompositor". We update the params if it exists. Create new if it does not
	var active_reflection_effect = get_reflection_effect(reflect_cam.compositor)
	if active_reflection_effect != null:
		# print("Compositor Effect already exist: ", reflect_cam.name)
		update_compositor_reflection_effect(active_reflection_effect)
		# active_reflection_effect.effect_enabled = true
		# active_reflection_effect.needs_normal_roughness = true
		# active_reflection_effect.intersect_height = global_transform.origin.y
		# if override_YAxis_height:
		# 	active_reflection_effect.intersect_height = new_YAxis_height
	else:
		# print("Creating Compositor Effect for camera: ", reflect_cam.name)
		reflection_compositor_effect = ReflectionCompositor.new()
		update_compositor_reflection_effect(reflection_compositor_effect)
		# reflection_compositor_effect.effect_enabled = true
		# reflection_compositor_effect.needs_normal_roughness = true
		# reflection_compositor_effect.intersect_height = global_transform.origin.y
		reflect_cam.compositor.set_compositor_effects([reflection_compositor_effect])
	

func update_compositor_reflection_effect(comp_effect: CompositorEffect) -> void:
	if comp_effect:
		comp_effect.effect_enabled = true
		comp_effect.needs_normal_roughness = true
		comp_effect.intersect_height = global_transform.origin.y
		if override_YAxis_height:
			comp_effect.intersect_height = new_YAxis_height


func clear_compositor_reflection_effect(reflect_cam: Camera3D) -> void:
	if reflect_cam.compositor:
		# reflect_cam.compositor.free()
		reflect_cam.compositor.compositor_effects.clear()	
		reflect_cam.compositor = null
		print("Compositor Set to null for: ", reflect_cam.name)

func get_reflection_effect(comp: Compositor) -> Variant:
	if comp == null:
		return false
	for effect in comp.compositor_effects:
		if effect is ReflectionCompositor:
			return effect
	return null

#endregion