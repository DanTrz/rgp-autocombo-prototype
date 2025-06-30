extends Node3D
class_name SimpleGodraysController

# Vertical shaft approach - single mesh with volumetric sampling

@export var sun_light: DirectionalLight3D
@export var godray_volume_mesh: MeshInstance3D  # Single large mesh covering the volume

var godray_material: ShaderMaterial

func _ready():
	if not validate_setup():
		return
	
	setup_volume_mesh()
	connect_sun_tracking()

func validate_setup() -> bool:
	if not godray_volume_mesh:
		print("ERROR: No godray_volume_mesh assigned!")
		print("Create a large MeshInstance3D (like 50x50 QuadMesh) with the vertical shaft shader")
		return false
	
	if not sun_light:
		print("ERROR: No sun_light assigned!")
		return false
	
	godray_material = godray_volume_mesh.get_active_material(0) as ShaderMaterial
	if not godray_material:
		print("ERROR: No shader material!")
		return false
	
	print("✓ Vertical shaft godray setup validated")
	return true

func setup_volume_mesh():
	"""Configure the volume mesh for optimal volumetric sampling"""
	godray_volume_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	godray_volume_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	
	print("✓ Volume mesh configured for vertical shafts")

func connect_sun_tracking():
	update_sun_direction()
	print("✓ Sun tracking connected")

func update_sun_direction():
	if not sun_light or not godray_material:
		return
	
	var sun_direction = -sun_light.global_transform.basis.z.normalized()
	godray_material.set_shader_parameter("sun_direction", sun_direction)

func _process(_delta):
	update_sun_direction()

# Runtime controls for shaft parameters
func set_shaft_width(width: float):
	if godray_material:
		godray_material.set_shader_parameter("shaft_width", width)

func set_shaft_spacing(spacing: float):
	if godray_material:
		godray_material.set_shader_parameter("shaft_spacing", spacing)

func set_shaft_intensity(intensity: float):
	if godray_material:
		godray_material.set_shader_parameter("ray_intensity", intensity)

func set_atmospheric_density(density: float):
	if godray_material:
		godray_material.set_shader_parameter("atmospheric_density", density)

func debug_info():
	print("=== Vertical Shaft Godrays Debug ===")
	print("Volume Mesh: ", godray_volume_mesh)
	print("Sun Light: ", sun_light)
	print("Material: ", godray_material)
	if sun_light:
		print("Sun Direction: ", -sun_light.global_transform.basis.z.normalized())
