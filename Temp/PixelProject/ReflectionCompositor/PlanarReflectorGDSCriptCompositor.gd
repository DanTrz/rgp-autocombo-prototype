@tool
extends MeshInstance3D
class_name PlanarReflectorGDSCriptCompositor

var reflect_camera : Camera3D
var reflect_viewport: SubViewport
var editor_camera : Camera3D = null 
@export var main_camera : Camera3D = null 
@export var reflection_camera_resolution: Vector2i = Vector2i(1920, 1080)

@export_group("Camera Controls")
@export var ortho_scale_multiplier: float = 1.0
@export var ortho_uv_scale: float = 1.0
@export var auto_detect_camera_mode: bool = true

@export_group("Reflection Layers and Environment")
@export_flags_3d_render var reflection_layers: int = 1
@export var use_custom_environment: bool = true
@export var custom_environment: Environment

@export_group("Reflection Offset Control")
@export var enable_reflection_offset: bool = false
@export var reflection_offset_position: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var reflection_offset_rotation: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var reflection_offset_scale: float = 1.0
@export var offset_blend_mode: int = 0 # 0=Add,1=Multiply,2=Screen-space shift

@export_group("Performance Controls")
@export var update_frequency: int = 1
@export var use_lod: bool = true
@export var lod_distance_near: float = 10.0
@export var lod_distance_far: float = 30.0
@export var lod_resolution_multiplier: float = 0.45

var editor_helper: Node = null
var active_shader_material: ShaderMaterial = null

var frame_counter: int = 0
var last_camera_position: Vector3
var last_camera_rotation: Basis
var position_threshold: float = 0.01
var rotation_threshold: float = 0.001

var cached_reflection_plane: Plane
var is_layer_one_active: bool = true

var cached_offset_transform: Transform3D
var last_offset_position: Vector3
var last_offset_rotation: Vector3

func _ready():
	add_to_group("planar_reflectors")
	find_editor_helper()

	reflect_viewport = SubViewport.new()
	reflect_viewport.name = "ReflectionViewPort" # keep your %ReflectionViewPort lookups valid
	add_child(reflect_viewport)
	reflect_viewport.size = reflection_camera_resolution
	reflect_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	reflect_viewport.msaa_3d = Viewport.MSAA_4X
	reflect_viewport.positional_shadow_atlas_size = 2048
	reflect_viewport.own_world_3d = false

	reflect_camera = Camera3D.new()
	reflect_viewport.add_child(reflect_camera) # <<< attach camera to viewport

	setup_reflection_layers()

	if main_camera:
		reflect_camera.attributes = main_camera.attributes
		reflect_camera.doppler_tracking = main_camera.doppler_tracking
	reflect_camera.current = true
	reflect_camera.make_current()

	setup_reflection_environment()
	update_offset_cache()

func find_editor_helper():
	if Engine.is_editor_hint():
		if Engine.has_singleton("PlanarReflectorEditorHelper"):
			editor_helper = Engine.get_singleton("PlanarReflectorEditorHelper")

func set_editor_camera(viewport_camera: Camera3D):
	editor_camera = viewport_camera
	printt("GDSCript SET Editor Camera: ", editor_camera.name)
	update_viewport()
	update_reflection_camera()

func get_is_active() -> bool:
	return true

func get_active_camera():
	return main_camera

func _process(_delta):
	update_viewport()

	frame_counter += 1
	update_offset_cache()

	var should_update := (frame_counter % update_frequency == 0)
	if should_update:
		var active_cam: Camera3D = editor_camera if Engine.is_editor_hint() else main_camera
		if active_cam:
			var current_pos = active_cam.global_transform.origin
			var current_basis = active_cam.global_transform.basis
			if last_camera_position != Vector3.ZERO:
				var pos_diff = current_pos.distance_to(last_camera_position)
				var rot_diff = current_basis.get_euler().distance_to(last_camera_rotation.get_euler())
				if pos_diff < position_threshold and rot_diff < rotation_threshold:
					return
			last_camera_position = current_pos
			last_camera_rotation = current_basis
			update_reflection_camera()

	if Engine.is_editor_hint():
		update_reflection_camera()

func setup_reflection_layers():
	var cull_mask = reflection_layers
	reflect_camera.cull_mask = cull_mask
	is_layer_one_active = bool(cull_mask & (1 << 0))
	if not is_layer_one_active:
		print("Layer 1 not active, make sure to add the layers to the scene Lights cull masks")

func setup_reflection_environment():
	if use_custom_environment:
		var reflection_env := Environment.new()
		if custom_environment:
			reflection_env = custom_environment
		else:
			reflection_env.background_mode = Environment.BG_CLEAR_COLOR
			if main_camera and main_camera.environment:
				if main_camera.environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY:
					reflection_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
					reflection_env.ambient_light_color = Color(0.4, 0.4, 0.4)
					reflection_env.ambient_light_energy = 0.3
				else:
					reflection_env.ambient_light_source = main_camera.environment.ambient_light_source
					reflection_env.ambient_light_color = main_camera.environment.ambient_light_color
					reflection_env.ambient_light_energy = main_camera.environment.ambient_light_energy
				if main_camera.environment.has_method("get_fog_enabled"):
					reflection_env.fog_enabled = false
		reflect_camera.environment = reflection_env
	else:
		reflect_camera.environment = main_camera.environment if main_camera else null

func calculate_reflection_plane() -> Plane:
	var reflection_transform = global_transform * Transform3D().rotated(Vector3.RIGHT, PI/2)
	var plane_origin = reflection_transform.origin
	var plane_normal = reflection_transform.basis.z.normalized()
	return Plane(plane_normal, plane_origin.dot(plane_normal))

func update_reflection_camera():
	var active_camera: Camera3D = main_camera
	find_editor_helper()
	if Engine.is_editor_hint():
		if editor_camera:
			active_camera = editor_camera
			active_camera.name = "EditorCamera"
		else:
			printt("GDSCript: Editor Camera not set, using main camera as active camera")

	if active_camera == null:
		return

	# Use the *actual* active camera for projection sync
	update_camera_projection()

	var reflection_plane = calculate_reflection_plane()
	cached_reflection_plane = reflection_plane

	var cam_pos = active_camera.global_transform.origin
	var proj_pos := reflection_plane.project(cam_pos)
	var mirrored_pos = cam_pos + (proj_pos - cam_pos) * 2.0

	var base_reflection_transform = Transform3D()
	base_reflection_transform.origin = mirrored_pos

	var main_basis := active_camera.global_transform.basis # <<< fix
	var n = reflection_plane.normal
	var reflection_basis := Basis(
		main_basis.x.normalized().bounce(n).normalized(),
		main_basis.y.normalized().bounce(n).normalized(),
		main_basis.z.normalized().bounce(n).normalized()
	)
	base_reflection_transform.basis = reflection_basis

	var final_reflection_transform = apply_reflection_offset(base_reflection_transform)
	reflect_camera.global_transform = final_reflection_transform

	update_shader_parameters()

func update_shader_parameters():
	if active_shader_material == null:
		active_shader_material = get_active_material(0)
	var material: ShaderMaterial = active_shader_material
	if material == null:
		return

	material.set_shader_parameter("reflection_screen_texture", reflect_viewport.get_texture())

	var is_orthogonal := false
	if Engine.is_editor_hint():
		# respect current projection set on reflect_camera (already synced)
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

func update_camera_projection():
	var src_cam: Camera3D = editor_camera if Engine.is_editor_hint() else main_camera
	if src_cam == null:
		return
	if auto_detect_camera_mode:
		reflect_camera.projection = src_cam.projection
	if reflect_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		reflect_camera.size = src_cam.size * ortho_scale_multiplier
	else:
		reflect_camera.fov = src_cam.fov

func update_viewport() -> void:
	var target_size: Vector2i
	if Engine.is_editor_hint() and editor_helper and editor_helper.has_method("get_editor_viewport_size"):
		target_size = editor_helper.call("get_editor_viewport_size")
		if typeof(target_size) != TYPE_VECTOR2I:
			target_size = get_viewport().get_visible_rect().size
	else:
		target_size = get_viewport().get_visible_rect().size

	var active_cam: Camera3D = editor_camera if Engine.is_editor_hint() else main_camera
	if use_lod and active_cam:
		var distance = global_transform.origin.distance_to(active_cam.global_transform.origin)
		var lod_factor = 1.0
		if distance > lod_distance_near:
			var lerp_factor = clamp((distance - lod_distance_near) / (lod_distance_far - lod_distance_near), 0.0, 1.0)
			lod_factor = lerp(1.0, lod_resolution_multiplier, lerp_factor)
		target_size = Vector2i(target_size * lod_factor)
		target_size.x = max(target_size.x, 128)
		target_size.y = max(target_size.y, 128)

	reflect_viewport.size = target_size # <<< apply

func apply_reflection_offset(base_transform: Transform3D) -> Transform3D:
	if not enable_reflection_offset:
		return base_transform
	var result_transform = base_transform
	match offset_blend_mode:
		0:
			result_transform.origin += cached_offset_transform.origin
			if reflection_offset_rotation != Vector3.ZERO:
				result_transform.basis = result_transform.basis * cached_offset_transform.basis
		1:
			result_transform = result_transform * cached_offset_transform
		2:
			if main_camera:
				var view_offset = main_camera.global_transform.basis * cached_offset_transform.origin
				result_transform.origin += view_offset
				result_transform.basis = result_transform.basis * cached_offset_transform.basis
	return result_transform

func update_offset_cache():
	if not enable_reflection_offset:
		cached_offset_transform = Transform3D.IDENTITY
		return
	if (last_offset_position != reflection_offset_position or last_offset_rotation != reflection_offset_rotation):
		var offset_basis = Basis()
		offset_basis = offset_basis.rotated(Vector3.RIGHT, deg_to_rad(reflection_offset_rotation.x))
		offset_basis = offset_basis.rotated(Vector3.UP, deg_to_rad(reflection_offset_rotation.y))
		offset_basis = offset_basis.rotated(Vector3.FORWARD, deg_to_rad(reflection_offset_rotation.z))
		cached_offset_transform = Transform3D(offset_basis, reflection_offset_position * reflection_offset_scale)
		last_offset_position = reflection_offset_position
		last_offset_rotation = reflection_offset_rotation

