@tool
extends MeshInstance3D
class_name PlanarReflectionMultiPass

# -------- Core ----------
var editor_camera: Camera3D = null
@export var main_camera: Camera3D
@export var reflection_camera_resolution: Vector2i = Vector2i(1920, 1080)

@export_group("Camera Controls")
@export var ortho_scale_multiplier := 1.0
@export var ortho_uv_scale := 1.0
@export var auto_detect_camera_mode := true

@export_group("Two-Pass Layers")
# BG: sky / terrain / static; FG: all reflectable props/characters/etc.
@export_flags_3d_render var background_layers: int = 1
@export_flags_3d_render var foreground_layers: int = 2
@export var use_custom_compositor: bool = false
@export var custom_compositor: Compositor = null

@export_group("Underwater masking (FG_ABOVE only)")
@export var use_fg_underwater_mask := true
@export var override_water_height := false
@export var water_height_override := 0.0

@export_group("Performance")
@export var update_frequency := 1
@export var use_lod := true
@export var lod_distance_near := 10.0
@export var lod_distance_far := 30.0
@export var lod_resolution_multiplier := 0.6

@export_group("Offsets")
@export var enable_reflection_offset := false
@export var reflection_offset_position := Vector3(0,0,0)
@export var reflection_offset_rotation := Vector3(0,0,0)
@export var reflection_offset_scale := 1.0
@export var offset_blend_mode := 0  # 0 add, 1 post-mul, 2 view-space add

# ---------- Internals ----------
var bg_vp: SubViewport
var fg_full_vp: SubViewport      # NEW: FG render with NO underwater mask
var fg_above_vp: SubViewport     # FG render WITH underwater mask
var bg_cam: Camera3D
var fg_full_cam: Camera3D
var fg_above_cam: Camera3D

var active_shader_material: ShaderMaterial
var cached_reflection_plane := Plane()
var cached_offset_xf := Transform3D.IDENTITY
var last_off_pos := Vector3.ZERO
var last_off_rot := Vector3.ZERO

var frame_counter := 0
var last_cam_pos := Vector3.ZERO
var last_cam_basis := Basis()

func _ready() -> void:
	_build_viewports()
	_update_all_immediate()

func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		# picked up next tick
		pass

# ---------- Build three viewports ----------
func _build_viewports() -> void:
	# BG
	bg_vp = _make_vp("ReflectionBG", false)
	bg_cam = _make_cam(bg_vp, background_layers)

	# FG_FULL (no mask)
	fg_full_vp = _make_vp("ReflectionFG_Full", true)
	fg_full_cam = _make_cam(fg_full_vp, foreground_layers)

	# FG_ABOVE (with mask → alpha=0 underwater)
	fg_above_vp = _make_vp("ReflectionFG_Above", true)
	fg_above_cam = _make_cam(fg_above_vp, foreground_layers)
	_attach_fg_mask_effect(fg_above_cam)

func _make_vp(name: String, transparent: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = name
	add_child(vp)
	vp.size = reflection_camera_resolution
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.transparent_bg = transparent
	vp.own_world_3d = false
	return vp

func _make_cam(vp: SubViewport, layers: int) -> Camera3D:
	var c := Camera3D.new()
	vp.add_child(c)
	c.cull_mask = layers
	c.current = true
	if main_camera:
		c.attributes = main_camera.attributes
		c.doppler_tracking = main_camera.doppler_tracking
	# Environment
	var env := Environment.new()
	if vp.transparent_bg:
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.background_color = Color(0,0,0,0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.75, 0.75, 0.75)
		env.ambient_light_energy = 1.0
	else:
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 1.0
	c.environment = env
	return c

func _attach_fg_mask_effect(cam: Camera3D) -> void:
	if use_custom_compositor and custom_compositor:
		cam.compositor = custom_compositor
	
	if not use_fg_underwater_mask:
		return
	
	if not cam.compositor:
		cam.compositor = Compositor.new()

	for e in cam.compositor.compositor_effects:
		if e is ReflectionCompositor:
			var rc: ReflectionCompositor = e
			rc.needs_normal_roughness = true
			rc.intersect_height = water_height_override if override_water_height else global_transform.origin.y
			break


# ---------- Update loop ----------
func _process(_dt: float) -> void:
	frame_counter += 1
	_update_offset_cache()
	if frame_counter % max(update_frequency, 1) != 0:
		return
	var cam := editor_camera if Engine.is_editor_hint() else main_camera
	if cam and _cam_moved(cam):
		_update_all_immediate()

func _cam_moved(cam: Camera3D) -> bool:
	var p := cam.global_transform.origin
	var b := cam.global_transform.basis
	var moved := (p - last_cam_pos).length() > 0.01 or (b.get_euler() - last_cam_basis.get_euler()).length() > 0.001
	if moved:
		last_cam_pos = p
		last_cam_basis = b
	return moved

# ---------- One-shot update ----------
func _update_all_immediate() -> void:
	_update_sizes()
	_update_cameras()
	_update_material_params()

func _update_sizes() -> void:
	var base := get_viewport().get_visible_rect().size
	var lod := 1.0
	if use_lod and main_camera:
		var d := global_transform.origin.distance_to(main_camera.global_transform.origin)
		if d > lod_distance_near:
			var t: float = clamp((d - lod_distance_near) / max(lod_distance_far - lod_distance_near, 0.001), 0.0, 1.0)
			lod = lerp(1.0, lod_resolution_multiplier, t)
	var sz := Vector2i(max(64, int(base.x * lod)), max(64, int(base.y * lod)))
	bg_vp.size = sz
	fg_full_vp.size = sz
	fg_above_vp.size = sz

func _update_cameras() -> void:
	var src := editor_camera if Engine.is_editor_hint() else main_camera
	if not src:
		return
	var plane := _calc_reflection_plane()
	cached_reflection_plane = plane

	var cam_pos := src.global_transform.origin
	var proj := plane.project(cam_pos)
	var mirrored := cam_pos + (proj - cam_pos) * 2.0

	var xf := Transform3D()
	xf.origin = mirrored
	var n := plane.normal
	var mb := src.global_transform.basis
	xf.basis = Basis(
		mb.x.normalized().bounce(n).normalized(),
		mb.y.normalized().bounce(n).normalized(),
		mb.z.normalized().bounce(n).normalized()
	)
	xf = _apply_offset(xf)

	bg_cam.global_transform = xf
	fg_full_cam.global_transform = xf
	fg_above_cam.global_transform = xf

	if auto_detect_camera_mode:
		bg_cam.projection = src.projection
		fg_full_cam.projection = src.projection
		fg_above_cam.projection = src.projection
	if bg_cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		bg_cam.size = src.size * ortho_scale_multiplier
		fg_full_cam.size = src.size * ortho_scale_multiplier
		fg_above_cam.size = src.size * ortho_scale_multiplier
	else:
		bg_cam.fov = src.fov
		fg_full_cam.fov = src.fov
		fg_above_cam.fov = src.fov

func _update_material_params() -> void:
	if active_shader_material == null:
		active_shader_material = get_active_material(0)
	if active_shader_material == null:
		return
	var is_ortho := (fg_full_cam.projection == Camera3D.PROJECTION_ORTHOGONAL)
	active_shader_material.set_shader_parameter("reflection_bg_texture", bg_vp.get_texture())
	active_shader_material.set_shader_parameter("reflection_fg_full_texture", fg_full_vp.get_texture())
	active_shader_material.set_shader_parameter("reflection_fg_above_texture", fg_above_vp.get_texture())
	active_shader_material.set_shader_parameter("is_orthogonal_camera", is_ortho)
	active_shader_material.set_shader_parameter("ortho_uv_scale", ortho_uv_scale)
	active_shader_material.set_shader_parameter("reflection_offset_enabled", enable_reflection_offset)
	active_shader_material.set_shader_parameter("reflection_offset_position", reflection_offset_position)
	active_shader_material.set_shader_parameter("reflection_offset_scale", reflection_offset_scale)
	active_shader_material.set_shader_parameter("reflection_plane_normal", cached_reflection_plane.normal)
	active_shader_material.set_shader_parameter("reflection_plane_distance", cached_reflection_plane.d)
	active_shader_material.set_shader_parameter("planar_surface_y", global_transform.origin.y)

# ---------- Helpers ----------
func _calc_reflection_plane() -> Plane:
	var t := global_transform * Transform3D().rotated(Vector3.RIGHT, PI/2.0)
	var o := t.origin
	var n := t.basis.z.normalized()
	return Plane(n, o.dot(n))

func _apply_offset(xf: Transform3D) -> Transform3D:
	if not enable_reflection_offset:
		return xf
	var out := xf
	match offset_blend_mode:
		0:
			out.origin += cached_offset_xf.origin
			if not reflection_offset_rotation.is_equal_approx(Vector3.ZERO):
				out.basis = out.basis * cached_offset_xf.basis
		1:
			out = out * cached_offset_xf
		2:
			if main_camera:
				var v := main_camera.global_transform.basis * cached_offset_xf.origin
				out.origin += v
				out.basis = out.basis * cached_offset_xf.basis
	return out

func _update_offset_cache() -> void:
	if not enable_reflection_offset:
		cached_offset_xf = Transform3D.IDENTITY
		return
	if last_off_pos == reflection_offset_position and last_off_rot == reflection_offset_rotation:
		return
	var b := Basis()
	b = b.rotated(Vector3.RIGHT, deg_to_rad(reflection_offset_rotation.x))
	b = b.rotated(Vector3.UP, deg_to_rad(reflection_offset_rotation.y))
	b = b.rotated(Vector3.FORWARD, deg_to_rad(reflection_offset_rotation.z))
	cached_offset_xf = Transform3D(b, reflection_offset_position * reflection_offset_scale)
	last_off_pos = reflection_offset_position
	last_off_rot = reflection_offset_rotation

func set_editor_camera(viewport_camera: Camera3D) -> void:
	editor_camera = viewport_camera
	_update_all_immediate()
