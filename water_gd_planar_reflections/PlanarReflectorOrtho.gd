extends MeshInstance3D
class_name PlanarReflectorOrtho

var reflect_camera : Camera3D
var reflect_viewport: SubViewport
@export var main_cam : Camera3D = null
@export var reflection_camera_resolution: Vector2i = Vector2i(1920, 1080)

# New parameters for orthogonal mode
@export var ortho_scale_multiplier: float = 1.0
@export var ortho_uv_scale: float = 1.0
@export var auto_detect_camera_mode: bool = true
@export var update_frequency: int = 1  # Update every N frames (1 = every frame, 2 = every other frame)
@export var use_lod: bool = true
@export var lod_distance_near: float = 10.0
@export var lod_distance_far: float = 50.0
@export var lod_resolution_multiplier: float = 0.25  # Multiply resolution by this when far
@export_range(0, 20) var reflection_layer: int = 1  #what layers to reflect

# Layer culling options for excluding objects
@export var use_custom_environment: bool = true  # Exclude sky/environment background
@export var custom_environment: Environment  # Exclude sky/environment background

# @export var excluded_layers: Array[int] = []  # Additional layers to exclude from reflection

var frame_counter: int = 0
var last_camera_position: Vector3
var last_camera_rotation: Basis
var position_threshold: float = 0.01  # Only update if camera moved this much
var rotation_threshold: float = 0.001  # Only update if camera rotated this much

func _ready():
	reflect_viewport = SubViewport.new();
	add_child(reflect_viewport);
	reflect_viewport.size = reflection_camera_resolution;
	reflect_camera = Camera3D.new();
	reflect_viewport.add_child(reflect_camera);
	
	# Set reflection camera cull mask to exclude unwanted layers
	setup_reflection_layers()
	
	# Copy basic camera properties (but handle environment separately)
	reflect_camera.attributes = main_cam.attributes
	reflect_camera.doppler_tracking = main_cam.doppler_tracking
	
	# Handle environment/sky exclusion
	setup_reflection_environment()
	
	reflect_camera.current = true;
	reflect_camera.make_current();

func setup_reflection_layers():
	"""Configure which layers the reflection camera can see"""
	var cull_mask = 0
	
	# Start with all layers enabled (if reflection_layer is 0)
	if reflection_layer == 0:
		cull_mask = 0xFFFFFFFF  # All layers
	else:
		# Only include the specified reflection layer
		cull_mask = 1 << (reflection_layer - 1)
	
	# Exclude additional layers
	# for layer in excluded_layers:
	# 	if layer >= 1 and layer <= 20:
	# 		var exclude_mask = 1 << (layer - 1)
	# 		cull_mask &= ~exclude_mask  # Remove layer from mask
	
	reflect_camera.cull_mask = cull_mask

func setup_reflection_environment():
	"""Set up environment for reflection camera"""
	if use_custom_environment:
		# Create a custom environment without sky background
		var reflection_env = Environment.new()
		if custom_environment:
			reflection_env = custom_environment
		else:
			# Set transparent background instead of sky - set it to BG_CLEAR_COLOR
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

func update_reflection_camera():
	# Update camera projection based on main camera
	update_camera_projection()

	var reflection_transform = global_transform * Transform3D().rotated(Vector3.RIGHT, PI/2);
	var plane_origin = reflection_transform.origin;
	var plane_normal = reflection_transform.basis.z.normalized();
	var reflection_plane = Plane(plane_normal, plane_origin.dot(plane_normal))
	
	var cam_pos = main_cam.global_transform.origin
	
	var proj_pos := reflection_plane.project(cam_pos)
	var mirrored_pos = cam_pos + (proj_pos - cam_pos) * 2.0
	
	reflect_camera.global_transform.origin = mirrored_pos

	reflect_camera.basis = Basis(
		main_cam.basis.x.normalized().bounce(reflection_plane.normal).normalized(),
		main_cam.basis.y.normalized().bounce(reflection_plane.normal).normalized(),
		main_cam.basis.z.normalized().bounce(reflection_plane.normal).normalized()
	)
	
	var mat:ShaderMaterial = self.mesh.surface_get_material(0)
	if mat == null:
		printerr("material not found or not shader material")
		return
	
	mat.set_shader_parameter("reflection_screen_texture", reflect_viewport.get_texture());
	
	# Pass camera mode info to shader
	var is_orthogonal = false

	if Engine.is_editor_hint(): # Force perspective in editor
		is_orthogonal = false
	else:
		is_orthogonal = (main_cam.projection == Camera3D.PROJECTION_ORTHOGONAL)

	mat.set_shader_parameter("is_orthogonal_camera", is_orthogonal);
	mat.set_shader_parameter("ortho_uv_scale", ortho_uv_scale);
	

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
