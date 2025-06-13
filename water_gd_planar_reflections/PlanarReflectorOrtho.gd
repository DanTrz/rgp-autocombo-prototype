extends MeshInstance3D
class_name PlanarReflectorOrtho

var reflect_camera : Camera3D
var reflect_viewport: SubViewport
@export var main_cam : Camera3D = null
@export var reflection_camera_resolution: Vector2i = Vector2i(1920, 1080)

# Camera mode parameters
@export var ortho_scale_multiplier: float = 1.0 #scale the orthographic projection size for the reflection camera.(lower values = bigger reflection)
@export var ortho_uv_scale: float = 1.0 # uv scale (1 = Normal // 0.5 = sample from half of texture  (zoomed effect) //  2.0 = Sample larger area (tiled effect) )
@export var auto_detect_camera_mode: bool = true

# Performance parameters
@export var update_frequency: int = 1  # Update every N frames (1 = every frame, 2 = every other frame)
@export var use_lod: bool = true # Auto reduce reflection resolution based on distance
@export var lod_distance_near: float = 10.0
@export var lod_distance_far: float = 50.0
@export var lod_resolution_multiplier: float = 0.25  # Multiply resolution by this when far

# Layer and environment control
@export_flags_3d_render var reflection_layers: int = 1
@export var use_custom_environment: bool = true
@export var custom_environment: Environment

# Advanced reflection parameters (for future complex water shaders)
@export_group("Advanced Reflection")
@export var enable_perturb_scale: bool = false
@export var perturb_scale: float = 0.1  # How much normals distort the reflection plane geometry
@export var perturb_frequency: float = 1.0  # Frequency multiplier for perturbation
@export var clip_bias: float = 0.01  # Geometry rendering bias beyond reflection plane
@export var reflection_plane_offset: float = 0.0  # Manual offset for reflection plane position
@export var enable_advanced_culling: bool = false  # More precise culling for complex geometry

# Future-proofing parameters for complex water features
@export_group("Future Water Features")
@export var enable_wave_displacement: bool = false  # For future wave vertex displacement
@export var wave_amplitude: float = 1.0  # Amplitude for future wave displacement
@export var wave_frequency: float = 1.0  # Frequency for future wave patterns
@export var foam_threshold: float = 0.5  # Threshold for future foam generation
@export var shoreline_detection: bool = false  # For future shoreline interaction
@export var caustics_enabled: bool = false  # For future caustics implementation

# Internal optimization variables
var frame_counter: int = 0
var last_camera_position: Vector3
var last_camera_rotation: Basis
var position_threshold: float = 0.01  # Only update if camera moved this much
var rotation_threshold: float = 0.001  # Only update if camera rotated this much

# Advanced reflection calculation cache (for future optimizations)
var cached_reflection_plane: Plane
var cached_clip_plane: Plane
var reflection_plane_dirty: bool = true

func _ready():
	reflect_viewport = SubViewport.new()
	add_child(reflect_viewport)
	reflect_viewport.size = reflection_camera_resolution
	reflect_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	reflect_viewport.msaa_3d = Viewport.MSAA_4X
	reflect_viewport.positional_shadow_atlas_size = 2048
	reflect_viewport.own_world_3d = false

	reflect_camera = Camera3D.new()
	reflect_viewport.add_child(reflect_camera)
	
	# Set reflection camera cull mask to exclude unwanted layers
	setup_reflection_layers()
	
	# Copy basic camera properties (but handle environment separately)
	reflect_camera.attributes = main_cam.attributes
	reflect_camera.doppler_tracking = main_cam.doppler_tracking
	
	# Handle environment/sky exclusion
	setup_reflection_environment()
	
	reflect_camera.current = true
	reflect_camera.make_current()

func setup_reflection_layers():
	"""Configure which layers the reflection camera can see"""
	var cull_mask = reflection_layers
	reflect_camera.cull_mask = cull_mask

func setup_reflection_environment():
	"""Set up environment for reflection camera"""
	if use_custom_environment:
		var reflection_env = Environment.new()
		if custom_environment:
			reflection_env = custom_environment
		else:
			# Auto-generate clean environment
			reflection_env.background_mode = Environment.BG_CLEAR_COLOR 
			# Copy lighting settings from main environment but exclude sky contribution
			if main_cam.environment:
				# Copy ambient light but not from sky
				if main_cam.environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY:
					reflection_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
					reflection_env.ambient_light_color = Color(0.4, 0.4, 0.4)  # Neutral gray
					reflection_env.ambient_light_energy = 0.3
				else:
					reflection_env.ambient_light_source = main_cam.environment.ambient_light_source
					reflection_env.ambient_light_color = main_cam.environment.ambient_light_color
					reflection_env.ambient_light_energy = main_cam.environment.ambient_light_energy
				
				# Copy other lighting but disable sky-dependent effects
				if main_cam.environment.has_method("get_fog_enabled"):
					reflection_env.fog_enabled = false  # Disable fog to avoid sky color bleeding
		
		reflect_camera.environment = reflection_env
	else:
		# Use main camera environment as-is
		reflect_camera.environment = main_cam.environment

func _process(_delta):
	update_viewport()
	if (!main_cam):
		return

	frame_counter += 1
	
	# Skip updates based on frequency and movement threshold
	var should_update = (frame_counter % update_frequency == 0)
	
	if should_update:
		var current_pos = main_cam.global_transform.origin
		var current_basis = main_cam.global_transform.basis
		
		# Check if camera moved/rotated enough to warrant update
		if last_camera_position != Vector3.ZERO:
			var pos_diff = current_pos.distance_to(last_camera_position)
			var rot_diff = current_basis.get_euler().distance_to(last_camera_rotation.get_euler())
			
			if pos_diff < position_threshold and rot_diff < rotation_threshold:
				return  # Skip update if camera barely moved
		
		last_camera_position = current_pos
		last_camera_rotation = current_basis
		
		update_reflection_camera()
	
	if Engine.is_editor_hint(): # Force updates in editor to see changes immediately
		update_reflection_camera()

func calculate_reflection_plane() -> Plane:
	"""Calculate the reflection plane with optional offset and perturbation"""
	var reflection_transform = global_transform * Transform3D().rotated(Vector3.RIGHT, PI/2)
	var plane_origin = reflection_transform.origin
	
	# Apply manual plane offset if specified
	if reflection_plane_offset != 0.0:
		plane_origin += reflection_transform.basis.z.normalized() * reflection_plane_offset
	
	var plane_normal = reflection_transform.basis.z.normalized()
	
	# Future: Add perturbation based on wave displacement here
	if enable_perturb_scale and enable_wave_displacement:
		# This will be expanded when wave displacement is implemented
		# Use engine time for simple wave motion
		var time_offset = Engine.get_process_frames() * 0.016 * wave_frequency  # Approximate frame time
		var perturb_offset = sin(time_offset) * perturb_scale * wave_amplitude
		plane_origin += plane_normal * perturb_offset
	
	return Plane(plane_normal, plane_origin.dot(plane_normal))

func update_reflection_camera():
	# Update camera projection based on main camera
	update_camera_projection()

	# Calculate reflection plane (with advanced features)
	var reflection_plane = calculate_reflection_plane()
	cached_reflection_plane = reflection_plane
	
	var cam_pos = main_cam.global_transform.origin
	
	var proj_pos := reflection_plane.project(cam_pos)
	var mirrored_pos = cam_pos + (proj_pos - cam_pos) * 2.0
	
	reflect_camera.global_transform.origin = mirrored_pos

	reflect_camera.basis = Basis(
		main_cam.basis.x.normalized().bounce(reflection_plane.normal).normalized(),
		main_cam.basis.y.normalized().bounce(reflection_plane.normal).normalized(),
		main_cam.basis.z.normalized().bounce(reflection_plane.normal).normalized()
	)
	
	# Apply advanced culling and clipping if enabled
	if enable_advanced_culling:
		setup_advanced_clipping(reflection_plane)
	
	# Pass parameters to shader
	update_shader_parameters()

func setup_advanced_clipping(reflection_plane: Plane):
	"""Set up advanced clipping planes for complex geometry"""
	if clip_bias != 0.0:
		# Adjust the clipping plane with bias to prevent seams
		var adjusted_plane = Plane(reflection_plane.normal, reflection_plane.d + clip_bias)
		cached_clip_plane = adjusted_plane
		
		# Future: Implement custom clipping plane setup here
		# This will be useful for complex wave geometry and shoreline interactions
	
func update_shader_parameters():
	"""Update all shader parameters including advanced features"""
	var mat: ShaderMaterial = self.mesh.surface_get_material(0)
	if mat == null:
		printerr("material not found or not shader material")
		return
	
	# Core reflection texture
	mat.set_shader_parameter("reflection_screen_texture", reflect_viewport.get_texture())
	
	# Camera mode detection
	var is_orthogonal = false
	if Engine.is_editor_hint(): # Force perspective in editor
		is_orthogonal = false
	else:
		is_orthogonal = (main_cam.projection == Camera3D.PROJECTION_ORTHOGONAL)

	mat.set_shader_parameter("is_orthogonal_camera", is_orthogonal)
	mat.set_shader_parameter("ortho_uv_scale", ortho_uv_scale)
	
	# Advanced reflection parameters
	mat.set_shader_parameter("enable_perturb_scale", enable_perturb_scale)
	mat.set_shader_parameter("perturb_scale", perturb_scale)
	mat.set_shader_parameter("perturb_frequency", perturb_frequency)
	mat.set_shader_parameter("clip_bias", clip_bias)
	
	# Future water feature parameters (ready for when shader supports them)
	mat.set_shader_parameter("enable_wave_displacement", enable_wave_displacement)
	mat.set_shader_parameter("wave_amplitude", wave_amplitude)
	mat.set_shader_parameter("wave_frequency", wave_frequency)
	mat.set_shader_parameter("foam_threshold", foam_threshold)
	mat.set_shader_parameter("shoreline_detection", shoreline_detection)
	mat.set_shader_parameter("caustics_enabled", caustics_enabled)
	
	# Pass reflection plane data for advanced shader calculations
	mat.set_shader_parameter("reflection_plane_normal", cached_reflection_plane.normal)
	mat.set_shader_parameter("reflection_plane_distance", cached_reflection_plane.d)

func update_camera_projection():
	if auto_detect_camera_mode:
		reflect_camera.projection = main_cam.projection
		if Engine.is_editor_hint(): # Force perspective in editor
			reflect_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	
	if reflect_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		reflect_camera.size = main_cam.size * ortho_scale_multiplier
	else:
		reflect_camera.fov = main_cam.fov

func update_viewport() -> void:
	var target_size = get_viewport().size
	
	# Apply LOD based on distance
	if use_lod and main_cam:
		var distance = global_transform.origin.distance_to(main_cam.global_transform.origin)
		var lod_factor = 1.0
		
		if distance > lod_distance_near:
			var lerp_factor = clamp((distance - lod_distance_near) / (lod_distance_far - lod_distance_near), 0.0, 1.0)
			lod_factor = lerp(1.0, lod_resolution_multiplier, lerp_factor)
		
		target_size = Vector2i(target_size * lod_factor)
		target_size.x = max(target_size.x, 128)  # Minimum resolution
		target_size.y = max(target_size.y, 128)
	
	reflect_viewport.size = target_size

# Utility functions for future advanced features
func get_water_height_at_position(world_pos: Vector3) -> float:
	"""Get water surface height at a world position - for future wave displacement"""
	# This will be implemented when wave displacement is added
	if enable_wave_displacement:
		# Use a simple time-based approach with engine frames
		var time_offset = Engine.get_process_frames() * 0.016 * wave_frequency  # ~60fps timing
		return sin(world_pos.x * 0.1 + time_offset) * wave_amplitude
	return global_transform.origin.y

func is_position_underwater(world_pos: Vector3) -> bool:
	"""Check if a world position is underwater - for future foam/caustics"""
	return world_pos.y < get_water_height_at_position(world_pos)

func get_shoreline_distance(world_pos: Vector3) -> float:
	"""Get distance to shoreline - for future shoreline effects"""
	# This will be implemented when shoreline detection is added
	return 0.0










# extends MeshInstance3D
# class_name PlanarReflectorOrtho

# var reflect_camera : Camera3D
# var reflect_viewport: SubViewport
# @export var main_cam : Camera3D = null
# @export var reflection_camera_resolution: Vector2i = Vector2i(1920, 1080)

# # New parameters for orthogonal mode
# @export var ortho_scale_multiplier: float = 1.0
# @export var ortho_uv_scale: float = 1.0
# @export var auto_detect_camera_mode: bool = true
# @export var update_frequency: int = 1  # Update every N frames (1 = every frame, 2 = every other frame)
# @export var use_lod: bool = true
# @export var lod_distance_near: float = 10.0
# @export var lod_distance_far: float = 50.0
# @export var lod_resolution_multiplier: float = 0.25  # Multiply resolution by this when far
# @export_range(1, 20) var reflection_layer: int = 1  #what layers to reflect

# var frame_counter: int = 0
# var last_camera_position: Vector3
# var last_camera_rotation: Basis
# var position_threshold: float = 0.01  # Only update if camera moved this much
# var rotation_threshold: float = 0.001  # Only update if camera rotated this much

# func _ready():
# 	reflect_viewport = SubViewport.new();
# 	add_child(reflect_viewport);
# 	reflect_viewport.size = reflection_camera_resolution;
# 	reflect_camera = Camera3D.new();
# 	reflect_viewport.add_child(reflect_camera);
# 	reflect_camera.cull_mask =  1 << (reflection_layer-1); #20 = 524288
	
# 	# Copy basic camera properties
# 	reflect_camera.environment = main_cam.environment
# 	reflect_camera.attributes = main_cam.attributes
# 	reflect_camera.doppler_tracking = main_cam.doppler_tracking
	
# 	reflect_camera.current = true;
# 	reflect_camera.make_current();

# func _process(_delta):
# 	update_viewport()
# 	if (!main_cam):
# 		return

# 	frame_counter += 1
	
# 	# Skip updates based on frequency and movement threshold
# 	var should_update = (frame_counter % update_frequency == 0)
	
# 	if should_update:
# 		var current_pos = main_cam.global_transform.origin
# 		var current_basis = main_cam.global_transform.basis
		
# 		# Check if camera moved/rotated enough to warrant update
# 		if last_camera_position != Vector3.ZERO:
# 			var pos_diff = current_pos.distance_to(last_camera_position)
# 			var rot_diff = current_basis.get_euler().distance_to(last_camera_rotation.get_euler())
			
# 			if pos_diff < position_threshold and rot_diff < rotation_threshold:
# 				return  # Skip update if camera barely moved
		
# 		last_camera_position = current_pos
# 		last_camera_rotation = current_basis
		
# 		update_reflection_camera()
	
# 		if Engine.is_editor_hint(): # Force updates in editor to see changes immediately
# 			update_reflection_camera()

# func update_reflection_camera():
# 	# Update camera projection based on main camera
# 	update_camera_projection()

# 	var reflection_transform = global_transform * Transform3D().rotated(Vector3.RIGHT, PI/2);
# 	var plane_origin = reflection_transform.origin;
# 	var plane_normal = reflection_transform.basis.z.normalized();
# 	var reflection_plane = Plane(plane_normal, plane_origin.dot(plane_normal))
	
# 	var cam_pos = main_cam.global_transform.origin
	
# 	var proj_pos := reflection_plane.project(cam_pos)
# 	var mirrored_pos = cam_pos + (proj_pos - cam_pos) * 2.0
	
# 	reflect_camera.global_transform.origin = mirrored_pos

# 	reflect_camera.basis = Basis(
# 		main_cam.basis.x.normalized().bounce(reflection_plane.normal).normalized(),
# 		main_cam.basis.y.normalized().bounce(reflection_plane.normal).normalized(),
# 		main_cam.basis.z.normalized().bounce(reflection_plane.normal).normalized()
# 	)
	
# 	var mat:ShaderMaterial = self.mesh.surface_get_material(0)
# 	if mat == null:
# 		printerr("material not found or not shader material")
# 		return
	
# 	mat.set_shader_parameter("reflection_screen_texture", reflect_viewport.get_texture());
	
# 	# Pass camera mode info to shader
# 	var is_orthogonal = false

# 	if Engine.is_editor_hint(): # Force perspective in editor
# 		is_orthogonal = false
# 	else:
# 		is_orthogonal = (main_cam.projection == Camera3D.PROJECTION_ORTHOGONAL)

# 	mat.set_shader_parameter("is_orthogonal_camera", is_orthogonal);
# 	mat.set_shader_parameter("ortho_uv_scale", ortho_uv_scale);
	
# 	if is_orthogonal:
# 		mat.set_shader_parameter("camera_size", main_cam.size);
# 	else:
# 		mat.set_shader_parameter("camera_fov", main_cam.fov);

# func update_camera_projection():
# 	if auto_detect_camera_mode:
# 		reflect_camera.projection = main_cam.projection
# 		if Engine.is_editor_hint(): # Force perspective in editor
# 			reflect_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	
# 	if reflect_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
# 		reflect_camera.size = main_cam.size * ortho_scale_multiplier
# 	else:
# 		reflect_camera.fov = main_cam.fov

# func update_viewport() -> void:
# 	var target_size = get_viewport().size
	
# 	# Apply LOD based on distance
# 	if use_lod and main_cam:
# 		var distance = global_transform.origin.distance_to(main_cam.global_transform.origin)
# 		var lod_factor = 1.0
		
# 		if distance > lod_distance_near:
# 			var lerp_factor = clamp((distance - lod_distance_near) / (lod_distance_far - lod_distance_near), 0.0, 1.0)
# 			lod_factor = lerp(1.0, lod_resolution_multiplier, lerp_factor)
		
# 		target_size = Vector2i(target_size * lod_factor)
# 		target_size.x = max(target_size.x, 128)  # Minimum resolution
# 		target_size.y = max(target_size.y, 128)
	
# 	reflect_viewport.size = target_size





















#### BACKUP WORKING CODE FOR ORTHO #######

# extends MeshInstance3D
# class_name PlanarReflectorOrtho

# var reflect_camera : Camera3D
# var reflect_viewport: SubViewport
# @export var main_cam : Camera3D = null
# @export var reflection_camera_resolution: Vector2i = Vector2i(1920, 1080)

# # New parameters for orthogonal mode
# @export var ortho_scale_multiplier: float = 1.0
# @export var ortho_uv_scale: float = 1.0
# @export var auto_detect_camera_mode: bool = true

# func _ready():
# 	reflect_viewport = SubViewport.new();
# 	add_child(reflect_viewport);
# 	reflect_viewport.size = reflection_camera_resolution;
# 	reflect_camera = Camera3D.new();
# 	reflect_viewport.add_child(reflect_camera);
# 	reflect_camera.cull_mask = 1;
	
# 	# Copy basic camera properties
# 	reflect_camera.environment = main_cam.environment
# 	reflect_camera.attributes = main_cam.attributes
# 	reflect_camera.doppler_tracking = main_cam.doppler_tracking
	
# 	reflect_camera.current = true;
# 	reflect_camera.make_current();

# func _process(_delta):
# 	update_viewport()
# 	if (!main_cam):
# 		return

# 	# Update camera projection based on main camera
# 	update_camera_projection()

# 	var reflection_transform = global_transform * Transform3D().rotated(Vector3.RIGHT, PI/2);
# 	var plane_origin = reflection_transform.origin;
# 	var plane_normal = reflection_transform.basis.z.normalized();
# 	var reflection_plane = Plane(plane_normal, plane_origin.dot(plane_normal))
	
# 	var cam_pos = main_cam.global_transform.origin
	
# 	var proj_pos := reflection_plane.project(cam_pos)
# 	var mirrored_pos = cam_pos + (proj_pos - cam_pos) * 2.0
	
# 	reflect_camera.global_transform.origin = mirrored_pos

# 	reflect_camera.basis = Basis(
# 		main_cam.basis.x.normalized().bounce(reflection_plane.normal).normalized(),
# 		main_cam.basis.y.normalized().bounce(reflection_plane.normal).normalized(),
# 		main_cam.basis.z.normalized().bounce(reflection_plane.normal).normalized()
# 	)
	
# 	var mat:ShaderMaterial = self.mesh.surface_get_material(0)
# 	if mat == null:
# 		printerr("material not found or not shader material")
# 		return
	
# 	mat.set_shader_parameter("reflection_screen_texture", reflect_viewport.get_texture());
	
# 	# Pass camera mode info to shader
# 	var is_orthogonal = (main_cam.projection == Camera3D.PROJECTION_ORTHOGONAL)
# 	mat.set_shader_parameter("is_orthogonal_camera", is_orthogonal);
# 	mat.set_shader_parameter("ortho_uv_scale", ortho_uv_scale);
	
# 	if is_orthogonal:
# 		mat.set_shader_parameter("camera_size", main_cam.size);
# 	else:
# 		mat.set_shader_parameter("camera_fov", main_cam.fov);

# func update_camera_projection():
# 	if auto_detect_camera_mode:
# 		reflect_camera.projection = main_cam.projection
	
# 	if main_cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
# 		reflect_camera.size = main_cam.size * ortho_scale_multiplier
# 	else:
# 		reflect_camera.fov = main_cam.fov

# func update_viewport() -> void:
# 	reflect_viewport.size = get_viewport().size
