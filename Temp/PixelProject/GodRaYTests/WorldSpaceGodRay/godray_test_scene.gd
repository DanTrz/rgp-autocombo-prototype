extends Node3D
class_name GodrayTestScene

# Simple, focused controller - single responsibility principle

@export var sun_light: DirectionalLight3D
@export var godray_plane: MeshInstance3D

var godray_material: ShaderMaterial

func _ready():
    setup_godray_plane()
    connect_sun_to_shader()

func setup_godray_plane():
    """Configure the single godray plane with proper render settings"""
    if not godray_plane:
        print("Error: No godray_plane assigned!")
        return
    
    # Set proper render properties
    godray_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    godray_plane.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    
    # Get the material
    godray_material = godray_plane.get_active_material(0) as ShaderMaterial
    if not godray_material:
        print("Error: No shader material found on godray_plane!")
        return
    
    print("Godray plane setup complete")

func connect_sun_to_shader():
    """Initialize sun direction in shader"""
    if not sun_light or not godray_material:
        print("Error: Missing sun_light or godray_material")
        return
    
    update_sun_direction()
    print("Sun connected to shader")

func update_sun_direction():
    """Update sun direction in shader material"""
    if not sun_light or not godray_material:
        return
    
    var sun_direction = -sun_light.global_transform.basis.z.normalized()
    godray_material.set_shader_parameter("sun_direction", sun_direction)

func _process(_delta):
    """Keep sun direction updated"""
    update_sun_direction()

# Debug helper
func debug_print_info():
    print("=== Godray Debug ===")
    print("Sun Light: ", sun_light)
    print("Godray Plane: ", godray_plane)
    print("Material: ", godray_material)
    if sun_light:
        print("Sun Direction: ", -sun_light.global_transform.basis.z.normalized())

# Runtime adjustments
func set_intensity(value: float):
    if godray_material:
        godray_material.set_shader_parameter("ray_intensity", value)

func set_shaft_scale(scale: Vector2):
    if godray_material:
        godray_material.set_shader_parameter("shaft_scale", scale)

func set_noise_intensity(value: float):
    if godray_material:
        godray_material.set_shader_parameter("noise_intensity", value)