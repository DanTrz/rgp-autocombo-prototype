@tool
extends MeshInstance3D

## Assign your main DirectionalLight3D node here in the Inspector.
@export var sun_light: DirectionalLight3D

func _process(_delta):
	# Ensure the node and material are valid before proceeding.
	if not is_instance_valid(sun_light):
		return

	var mat = get_active_material(0) as ShaderMaterial
	if not mat:
		return

	# --- This is the corrected section ---

	# 1. Get the unique ID (RID) of the shadow atlas that this light belongs to.
	var atlas_rid = sun_light.get_shadow_atlas()

	# 2. Use that RID to get the actual shadow texture from the RenderingServer.
	var shadow_atlas_texture = RenderingServer.att(atlas_rid)
	
	# 3. Get the light's projection matrix.
	var light_transform = sun_light.get_light_project_matrix()

	# Send the correct data to the shader uniforms.
	mat.set_shader_parameter("light_projection_matrix", light_transform)
	mat.set_shader_parameter("shadow_atlas_texture", shadow_atlas_texture)



# extends MeshInstance3D

# # Script to handle multi-point shadow sampling for godrays
# # This cycles through different sample points to detect shadows along the ray

# @export var directional_light: DirectionalLight3D
# @export var sample_count: int = 10 # Number of samples in each direction
# @export var update_rate: float = 60.0 # How many times per second to update
# @export var detection_mode: int = 0 # 0 = cycle through points, 1 = manual control

# var current_sample_index: int = -10
# var update_timer: float = 0.0
# var shadow_detected_at_any_point: bool = false
# var shadow_map: Dictionary = {} # Store shadow detection results

# var shader_material:ShaderMaterial

# signal shadow_detected()
# signal shadow_cleared()

# func _ready():
# 	shader_material = get_surface_override_material(0)

# 	if directional_light and shader_material:
# 		update_light_direction()
# 		# Initialize at center
# 		shader_material.set_shader_parameter("sample_index", 0)

# func _process(delta):
# 	if not directional_light or not shader_material:
# 		return
		
# 	update_timer += delta
	
# 	if update_timer >= 1.0 / update_rate:
# 		update_timer = 0.0
		
# 		if detection_mode == 0:
# 			# Cycle through sample points
# 			cycle_sample_point()
		
# 		# Always update light direction
# 		update_light_direction()

# func cycle_sample_point():
# 	# Move to next sample point
# 	current_sample_index += 1
# 	if current_sample_index > sample_count:
# 		current_sample_index = -sample_count
		
# 		# Check if any point had shadow
# 		check_shadow_map()
	
# 	# Set the sample index in shader
# 	shader_material.set_shader_parameter("sample_index", current_sample_index)

# func check_shadow_map():
# 	# Analyze shadow detection results
# 	var any_shadow = false
# 	for key in shadow_map:
# 		if shadow_map[key]:
# 			any_shadow = true
# 			break
	
# 	if any_shadow != shadow_detected_at_any_point:
# 		shadow_detected_at_any_point = any_shadow
# 		if any_shadow:
# 			shadow_detected.emit()
# 			# Optionally hide the ray
# 			if shader_material.get_shader_parameter("hide_entire_ray_on_shadow"):
# 				visible = false
# 		else:
# 			shadow_cleared.emit()
# 			visible = true

# func update_light_direction():
# 	# Get light direction in world space
# 	var light_dir = -directional_light.global_transform.basis.z
# 	shader_material.set_shader_parameter("light_direction_world", light_dir)
# 	shader_material.set_shader_parameter("use_manual_light_direction", true)

# # Manual control functions
# func set_sample_index(index: int):
# 	current_sample_index = clamp(index, -sample_count, sample_count)
# 	shader_material.set_shader_parameter("sample_index", current_sample_index)

# func scan_all_points_once():
# 	# Useful for doing a full scan
# 	for i in range(-sample_count, sample_count + 1):
# 		set_sample_index(i)
# 		# You'd need to wait a frame between each to let the shader update
# 		await get_tree().process_frame
