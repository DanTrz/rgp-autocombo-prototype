@tool
class_name EdgeDectionCompositorUpdatedWater
extends CompositorEffect

# ------------------------------------------------------------------------------
# RenderingDevice resources
# ------------------------------------------------------------------------------
var rd: RenderingDevice
var shader: RID
var pipeline: RID
var parameter_storage_buffer: RID
var sampler_rid: RID

# ------------------------------------------------------------------------------
# Artist-facing tunables (unchanged semantics)
# ------------------------------------------------------------------------------
@export_range(0.0, 1.0, 0.01) var line_highlight: float = 0.3
@export_range(0.0, 1.0, 0.01) var line_shadow: float   = 0.65
@export_range(0.0, 1.0, 0.01) var depth_smooth_low:  float = 0.45
@export_range(0.0, 1.0, 0.01) var depth_smooth_high: float = 0.50
@export_range(0.0, 1.0, 0.01) var inv_depth_step_thresh: float = 0.90
@export_range(0.0, 20.0, 0.1) var inv_depth_scale:       float = 10.0
@export_range(0.0, 1.0, 0.01) var normal_threshold: float = 0.20
@export_range(0.0, 0.001, 0.00001) var offset_scale: float = 0.0001

# Roughness gate (show lines when roughness >= threshold)
@export_range(0.0, 1.0, 0.01) var roughness_ignore_threshold: float = 0.95

# Water cutoff (now using true world-space Y)
@export var water_mask_enabled: bool = false
@export var water_y_height: float = 0.0
@export_range(0.0, 10.0, 0.1) var water_feather: float = 2.0
@export_enum("Binary:0", "Fade:1") var water_mode: int = 1

# ------------------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------------------
func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)

	# STORAGE BUFFER LAYOUT (std430):
	#  0..1   : vec2  raster_size
	#  2..3   : vec2  reserved (x = roughness_threshold, y = unused)
	#  4..19  : mat4  inv_proj_mat
	# 20..23  : vec4  tune0
	# 24..27  : vec4  tune1
	# 28..31  : vec4  water0
	# 32..47  : mat4  inv_view_mat  (NEW)
	# total = 48 floats
	var data := PackedFloat32Array()
	data.resize(48)
	data.fill(0.0)
	var parameter_data := data.to_byte_array()
	parameter_storage_buffer = rd.storage_buffer_create(parameter_data.size(), parameter_data)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if sampler_rid.is_valid():
			rd.free_rid(sampler_rid)
		if parameter_storage_buffer.is_valid():
			rd.free_rid(parameter_storage_buffer)
		if pipeline.is_valid():
			rd.free_rid(pipeline)
		if shader.is_valid():
			rd.free_rid(shader)

# ------------------------------------------------------------------------------
# Render thread setup
# ------------------------------------------------------------------------------
func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return

	var shader_file := load("res://3DPixelCompositorDemo/Shaders/edge_detection_shader_updated_water.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)

	# One persistent sampler (nearest for pixel-crisp lines)
	var s := RDSamplerState.new()
	s.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	s.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	s.mip_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_rid = rd.sampler_create(s)

# ------------------------------------------------------------------------------
# Render callback (on render thread)
# ------------------------------------------------------------------------------
func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return
	if not rd or not shader.is_valid() or not pipeline.is_valid() or not sampler_rid.is_valid():
		return

	var rsb := p_render_data.get_render_scene_buffers()
	if not rsb:
		return

	var size: Vector2i = rsb.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	# Workgroup count for 8x8 local size
	var x_groups: int = int((size.x + 7) / 8)
	var y_groups: int = int((size.y + 7) / 8)

	var view_count: int = rsb.get_view_count()
	for view in view_count:
		var input_image: RID  = rsb.get_color_layer(view)
		var input_depth: RID  = rsb.get_depth_layer(view)
		var input_normal: RID = rsb.get_texture("forward_clustered", "normal_roughness")
		if not input_image.is_valid() or not input_depth.is_valid() or not input_normal.is_valid():
			continue

		# ------------- Build param payload (48 floats) ------------------------
		var params := PackedFloat32Array()
		params.resize(48)

		# 0..1 : raster_size
		params[0] = float(size.x)
		params[1] = float(size.y)

		# 2..3 : reserved → x holds roughness threshold
		params[2] = roughness_ignore_threshold
		params[3] = 0.0

		# 4..19: inv_proj_mat (mat4 as 4 vec4 columns)
		var inv_proj := p_render_data.get_render_scene_data().get_cam_projection().inverse()
		params[4]  = inv_proj.x.x; params[5]  = inv_proj.x.y; params[6]  = inv_proj.x.z; params[7]  = inv_proj.x.w
		params[8]  = inv_proj.y.x; params[9]  = inv_proj.y.y; params[10] = inv_proj.y.z; params[11] = inv_proj.y.w
		params[12] = inv_proj.z.x; params[13] = inv_proj.z.y; params[14] = inv_proj.z.z; params[15] = inv_proj.z.w
		params[16] = inv_proj.w.x; params[17] = inv_proj.w.y; params[18] = inv_proj.w.z; params[19] = inv_proj.w.w

		# 20..23: tune0
		params[20] = line_highlight
		params[21] = line_shadow
		params[22] = depth_smooth_low
		params[23] = depth_smooth_high

		# 24..27: tune1
		params[24] = inv_depth_step_thresh
		params[25] = inv_depth_scale
		params[26] = normal_threshold
		params[27] = offset_scale

		# 28..31: water0
		params[28] = 1.0 if water_mask_enabled else 0.0
		params[29] = water_y_height
		params[30] = water_feather
		params[31] = float(water_mode)

		# 32..47: inv_view_mat (NEW) — camera transform (view→world)
		# get_cam_transform() is the camera's world transform, i.e. inverse of view
		var cam_xform: Transform3D = p_render_data.get_render_scene_data().get_cam_transform()
		# Convert Transform3D → column-major mat4 (basis columns + origin)
		# Column 0 = X axis, Column 1 = Y axis, Column 2 = Z axis, Column 3 = origin + 1
		params[32] = cam_xform.basis.x.x; params[33] = cam_xform.basis.x.y; params[34] = cam_xform.basis.x.z; params[35] = 0.0
		params[36] = cam_xform.basis.y.x; params[37] = cam_xform.basis.y.y; params[38] = cam_xform.basis.y.z; params[39] = 0.0
		params[40] = cam_xform.basis.z.x; params[41] = cam_xform.basis.z.y; params[42] = cam_xform.basis.z.z; params[43] = 0.0
		params[44] = cam_xform.origin.x;  params[45] = cam_xform.origin.y;  params[46] = cam_xform.origin.z;  params[47] = 1.0

		var parameter_data := params.to_byte_array()
		rd.buffer_update(parameter_storage_buffer, 0, parameter_data.size(), parameter_data)

		# ---------------- Uniform set -----------------------------------------
		var u_params := RDUniform.new()
		u_params.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u_params.binding = 0
		u_params.add_id(parameter_storage_buffer)

		var u_color := RDUniform.new()
		u_color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u_color.binding = 1
		u_color.add_id(input_image)

		var u_depth := RDUniform.new()
		u_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u_depth.binding = 2
		u_depth.add_id(sampler_rid)
		u_depth.add_id(input_depth)

		var u_normal := RDUniform.new()
		u_normal.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u_normal.binding = 3
		u_normal.add_id(sampler_rid)
		u_normal.add_id(input_normal)

		var uniforms := [u_params, u_color, u_depth, u_normal]
		var uniform_set := UniformSetCacheRD.get_cache(shader, 0, uniforms)
		if not uniform_set.is_valid():
			uniform_set = rd.uniform_set_create(uniforms, shader, 0)
			if not uniform_set.is_valid():
				continue

		# ---------------- Dispatch --------------------------------------------
		var cl := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl, pipeline)
		rd.compute_list_bind_uniform_set(cl, uniform_set, 0)
		rd.compute_list_dispatch(cl, x_groups, y_groups, 1)
		rd.compute_list_end()
