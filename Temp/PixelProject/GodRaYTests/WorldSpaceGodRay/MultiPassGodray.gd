# Multi-Pass Godray Controller
# This script manages the 3-pass rendering system for "any pixel shadow = hide entire ray"
extends MeshInstance3D

class_name MultiPassGodray

# Shader materials for each pass
@export var shadow_detection_material: ShaderMaterial
@export var final_render_material: ShaderMaterial
@export var analysis_material: ShaderMaterial

# Rendering setup
@export var shadow_detection_resolution: Vector2i = Vector2i(64, 64) # Small texture for shadow detection
@export var shadow_detection_threshold: float = 0.2

# Internal components
var shadow_detection_viewport: SubViewport
var shadow_analysis_viewport: SubViewport
var shadow_detection_camera: Camera3D
var shadow_detection_mesh: MeshInstance3D

# Analysis components  
var analysis_quad: MeshInstance3D

# Main camera reference
@export var main_camera: Camera3D

func _ready():
	setup_shadow_detection_pass()
	setup_analysis_pass()
	setup_final_render_pass()

func setup_shadow_detection_pass():
	"""Setup Pass 1: Shadow Detection"""
	
	# Create viewport for shadow detection
	shadow_detection_viewport = SubViewport.new()
	shadow_detection_viewport.size = shadow_detection_resolution
	# shadow_detection_viewport.update_mode = SubViewport.UPDATE_ALWAYS
	shadow_detection_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(shadow_detection_viewport)
	
	# Create camera for shadow detection
	shadow_detection_camera = Camera3D.new()
	shadow_detection_viewport.add_child(shadow_detection_camera)
	
	# Create mesh instance for shadow detection pass
	shadow_detection_mesh = MeshInstance3D.new()
	shadow_detection_mesh.mesh = mesh  # Use same mesh as main ray
	shadow_detection_mesh.material_override = shadow_detection_material
	shadow_detection_viewport.add_child(shadow_detection_mesh)

func setup_analysis_pass():
	"""Setup Pass 2: Shadow Analysis"""
	
	# Create viewport for analysis
	shadow_analysis_viewport = SubViewport.new()
	shadow_analysis_viewport.size = Vector2i(1, 1)  # Single pixel result
	shadow_analysis_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(shadow_analysis_viewport)
		
	# Create quad for analysis
	analysis_quad = MeshInstance3D.new()
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(2, 2)  # Full screen quad
	analysis_quad.mesh = quad_mesh
	analysis_quad.material_override = analysis_material
	shadow_analysis_viewport.add_child(analysis_quad)
	
	# Create camera for analysis
	var analysis_camera = Camera3D.new()
	analysis_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	analysis_camera.size = 2.0
	analysis_camera.position = Vector3(0, 0, 1)
	shadow_analysis_viewport.add_child(analysis_camera)

func setup_final_render_pass():
	"""Setup Pass 3: Final Render"""
	
	# Set the final render material on this mesh
	material_override = final_render_material

func _process(_delta):
	if not main_camera:
		return
	
	# Update shadow detection camera to match main camera
	update_shadow_detection_camera()
	
	# Update shadow detection mesh transform to match this object
	update_shadow_detection_mesh()
	
	# Update analysis material with shadow detection result
	update_analysis_pass()
	
	# Update final render material with analysis result
	update_final_render_pass()

func update_shadow_detection_camera():
	"""Sync shadow detection camera with main camera"""
	shadow_detection_camera.global_transform = main_camera.global_transform
	shadow_detection_camera.fov = main_camera.fov
	shadow_detection_camera.projection = main_camera.projection
	
	# Copy other camera properties
	shadow_detection_camera.near = main_camera.near
	shadow_detection_camera.far = main_camera.far

func update_shadow_detection_mesh():
	"""Sync shadow detection mesh with main mesh"""
	shadow_detection_mesh.global_transform = global_transform
	
	# Update shader parameters
	if shadow_detection_material:
		shadow_detection_material.set_shader_parameter("shadow_detection_threshold", shadow_detection_threshold)

func update_analysis_pass():
	"""Update Pass 2: Analyze shadow detection result"""
	if analysis_material:
		# Pass the shadow detection texture to analysis shader
		var shadow_detection_texture = shadow_detection_viewport.get_texture()
		analysis_material.set_shader_parameter("shadow_detection_texture", shadow_detection_texture)

func update_final_render_pass():
	"""Update Pass 3: Use analysis result in final render"""
	if final_render_material:
		# Pass the analysis result to final render shader
		var analysis_texture = shadow_analysis_viewport.get_texture()
		final_render_material.set_shader_parameter("shadow_analysis_texture", analysis_texture)
		
		# Pass through other shader parameters
		final_render_material.set_shader_parameter("shadow_detection_threshold", shadow_detection_threshold)

# Helper functions for external control
func set_ray_color(color: Color):
	if final_render_material:
		final_render_material.set_shader_parameter("ray_color", color)

func set_brightness(brightness: float):
	if final_render_material:
		final_render_material.set_shader_parameter("brightness", brightness)

func force_hide_ray(hide: bool):
	if final_render_material:
		final_render_material.set_shader_parameter("force_hide_ray", hide)
