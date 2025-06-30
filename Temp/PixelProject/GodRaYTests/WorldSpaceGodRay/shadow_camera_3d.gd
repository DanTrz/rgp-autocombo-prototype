# File: shadow_camera_controller.gd
# This script remains on your ShadowCamera node.
# FINAL CORRECTION FOR GODOT 4.3+

@tool
extends Camera3D

## --- EXPORT VARIABLES ---
@export var sun_light: DirectionalLight3D
@export var target_object: MeshInstance3D

## --- Camera settings ---
@export var camera_distance: float = 50.0
@export var frustum_size: float = 40.0


func _process(_delta):
	if not is_instance_valid(sun_light):
		return

	# --- Sync Transform with Light ---
	var light_direction = -sun_light.global_transform.basis.z
	global_position = -light_direction * camera_distance
	look_at(Vector3.ZERO, Vector3.UP)
	self.size = frustum_size
	
	# --- Send Matrix Data to Target ---
	if not is_instance_valid(target_object):
		return
	var mat = target_object.get_active_material(0) as ShaderMaterial
	if not mat:
		return
		
	# --- THIS IS THE CORRECTED SECTION FOR GODOT 4.3+ ---

	# The View Matrix is the inverse of the camera's global transform.
	var light_view_matrix = self.global_transform.affine_inverse()

	# The Projection Matrix, using the correct function name you found.
	var light_projection_matrix = self.get_camera_projection()

	# Send these matrices to the shader on our target object.
	mat.set_shader_parameter("light_view_matrix", light_view_matrix)
	mat.set_shader_parameter("light_projection_matrix", light_projection_matrix)
