@tool
extends Node3D

@onready var main_viewport: SubViewport = %MainSubViewport
@onready var reflect_viewport: SubViewport = %ReflectionViewPort
@onready var reflect_camera: Camera3D = %ReflectionCamera3D
@onready var main_cam: Camera3D = %Camera3DGameCam

func _ready() -> void:
	intial_setup()

func _process(_delta: float) -> void:
	update_reflection_camera()


func intial_setup():
	#Setup reflect viewport
	reflect_viewport.size = main_viewport.size
	reflect_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	reflect_viewport.msaa_3d = Viewport.MSAA_4X
	reflect_viewport.positional_shadow_atlas_size = 2048
	reflect_viewport.own_world_3d = false

	sync_cameras()



func sync_cameras():
	# Setup reflect camera
	reflect_camera.attributes = main_cam.attributes
	reflect_camera.fov = main_cam.fov
	reflect_camera.near = main_cam.near
	reflect_camera.far = main_cam.far
	reflect_camera.doppler_tracking = main_cam.doppler_tracking
	reflect_camera.current = true
	reflect_camera.global_transform = main_cam.global_transform
	reflect_camera.make_current()

func update_reflection_camera():
	# if reflect_camera.global_transform != main_cam.global_transform:
	# 	reflect_camera.global_transform = main_cam.global_transform
	# Calculate reflection plane (with advanced features)
	var reflection_plane = calculate_reflection_plane()
	
	var cam_pos = main_cam.global_transform.origin
	
	var proj_pos := reflection_plane.project(cam_pos)
	var mirrored_pos = cam_pos + (proj_pos - cam_pos) * 2.0
	
	# NEW: Create base reflection transform
	var base_reflection_transform = Transform3D()
	base_reflection_transform.origin = mirrored_pos
	base_reflection_transform.basis = Basis(
		main_cam.basis.x.normalized().bounce(reflection_plane.normal).normalized(),
		main_cam.basis.y.normalized().bounce(reflection_plane.normal).normalized(),
		main_cam.basis.z.normalized().bounce(reflection_plane.normal).normalized()
	)
	
	# Set the final transform
	reflect_camera.global_transform = base_reflection_transform
	
	# Pass parameters to shader
	#TODO: Hide this for now
	#update_shader_parameters()

func calculate_reflection_plane() -> Plane:
	#Calculate the reflection plane
	var reflection_transform = global_transform * Transform3D().rotated(Vector3.RIGHT, PI/2)
	var plane_origin = reflection_transform.origin
	var plane_normal = reflection_transform.basis.z.normalized()
	return Plane(plane_normal, plane_origin.dot(plane_normal))

func update_shader_parameters():
	#Update all shader parameters including advanced features
	pass
