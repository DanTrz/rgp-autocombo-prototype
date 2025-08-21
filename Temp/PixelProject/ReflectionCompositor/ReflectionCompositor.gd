@tool
class_name ReflectionCompositor
extends CompositorEffect

# --- GPU resources ---
var rd: RenderingDevice
var shader: RID
var pipeline: RID
var parameter_storage_buffer: RID
var sampler_rid: RID

# --- Controls (v1: simple flat plane) ---
@export var user_intersect_effect: bool = true
@export var intersect_height: float = 0.0

# Storage buffer layout (std430), float count:
#  0..1   : vec2  raster_size
#  2      : float intersect_height
#  3      : float pad0
#  4..19  : mat4  inv_proj_mat
# 20..35  : mat4  inv_view_mat
const PARAM_FLOATS := 36

func _init() -> void:
	# Run late so color is fully shaded before we mask it.
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(self):
			RenderingServer.call_on_render_thread(_free_gpu)

func _free_gpu() -> void:
	if not rd:
		return
	if sampler_rid.is_valid():
		rd.free_rid(sampler_rid)
	if parameter_storage_buffer.is_valid():
		rd.free_rid(parameter_storage_buffer)
	if pipeline.is_valid():
		rd.free_rid(pipeline)
	if shader.is_valid():
		rd.free_rid(shader)

func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return

	# Compile compute shader
	var shader_file: RDShaderFile = load("res://Temp/PixelProject/ReflectionCompositor/reflection_mask_compute.glsl")
	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(spirv)
	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)

	# Nearest sampling for depth reads
	var s := RDSamplerState.new()
	s.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	s.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	s.mip_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_rid = rd.sampler_create(s)

	# Persistent parameter buffer
	var data := PackedFloat32Array()
	data.resize(PARAM_FLOATS)
	data.fill(0.0)
	var bytes := data.to_byte_array()
	parameter_storage_buffer = rd.storage_buffer_create(bytes.size(), bytes)

func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return
	if not user_intersect_effect:
		return
	if not rd or not shader.is_valid() or not pipeline.is_valid() or not sampler_rid.is_valid():
		return

	var rsb := p_render_data.get_render_scene_buffers()
	if not rsb:
		return

	var size: Vector2i = rsb.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	# Workgroup sizes match local_size_x/y in GLSL (8x8)
	var x_groups: int = int((size.x + 7) / 8)
	var y_groups: int = int((size.y + 7) / 8)

	var view_count: int = rsb.get_view_count()
	for view in view_count:
		var color_tex: RID = rsb.get_color_layer(view)               # writable as image2D
		var depth_tex: RID = rsb.get_depth_layer(view)               # sampled as sampler2D
		if not color_tex.is_valid() or not depth_tex.is_valid():
			continue

		# ---------- Pack params ----------
		var params := PackedFloat32Array()
		params.resize(PARAM_FLOATS)

		# 0..1 : raster_size
		params[0] = float(size.x)
		params[1] = float(size.y)

		# 2..3 : intersect_height + pad
		params[2] = intersect_height
		params[3] = 0.0

		# 4..19 : inv_proj_mat
		var inv_proj := p_render_data.get_render_scene_data().get_cam_projection().inverse()
		params[4]  = inv_proj.x.x; params[5]  = inv_proj.x.y; params[6]  = inv_proj.x.z; params[7]  = inv_proj.x.w
		params[8]  = inv_proj.y.x; params[9]  = inv_proj.y.y; params[10] = inv_proj.y.z; params[11] = inv_proj.y.w
		params[12] = inv_proj.z.x; params[13] = inv_proj.z.y; params[14] = inv_proj.z.z; params[15] = inv_proj.z.w
		params[16] = inv_proj.w.x; params[17] = inv_proj.w.y; params[18] = inv_proj.w.z; params[19] = inv_proj.w.w

		# 20..35 : inv_view_mat  (camera world transform)
		var cam_xform: Transform3D = p_render_data.get_render_scene_data().get_cam_transform()
		params[20] = cam_xform.basis.x.x; params[21] = cam_xform.basis.x.y; params[22] = cam_xform.basis.x.z; params[23] = 0.0
		params[24] = cam_xform.basis.y.x; params[25] = cam_xform.basis.y.y; params[26] = cam_xform.basis.y.z; params[27] = 0.0
		params[28] = cam_xform.basis.z.x; params[29] = cam_xform.basis.z.y; params[30] = cam_xform.basis.z.z; params[31] = 0.0
		params[32] = cam_xform.origin.x;  params[33] = cam_xform.origin.y;  params[34] = cam_xform.origin.z;  params[35] = 1.0

		var param_bytes := params.to_byte_array()
		rd.buffer_update(parameter_storage_buffer, 0, param_bytes.size(), param_bytes)

		# ---------- Uniforms ----------
		var u_params := RDUniform.new()
		u_params.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u_params.binding = 0
		u_params.add_id(parameter_storage_buffer)

		var u_color := RDUniform.new()
		u_color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u_color.binding = 1
		u_color.add_id(color_tex)

		var u_depth := RDUniform.new()
		u_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u_depth.binding = 2
		u_depth.add_id(sampler_rid)
		u_depth.add_id(depth_tex)

		var uniforms := [u_params, u_color, u_depth]
		var uniform_set := UniformSetCacheRD.get_cache(shader, 0, uniforms)
		if not uniform_set.is_valid():
			uniform_set = rd.uniform_set_create(uniforms, shader, 0)
			if not uniform_set.is_valid():
				continue

		# ---------- Dispatch ----------
		var cl := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl, pipeline)
		rd.compute_list_bind_uniform_set(cl, uniform_set, 0)
		rd.compute_list_dispatch(cl, x_groups, y_groups, 1)
		rd.compute_list_end()
