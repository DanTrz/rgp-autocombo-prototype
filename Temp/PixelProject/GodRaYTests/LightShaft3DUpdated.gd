@tool
class_name LightShaft3DUpdated
extends MeshInstance3D

@export var outline: Path3D:
	get: return outline; 
	set(value): outline = value; if is_node_ready(): call_deferred("_rebuild", self) 

@export var origin: Marker3D:
	get: return origin; 
	set(value): origin = value; if is_node_ready(): call_deferred("_rebuild", self) 

@export var length: float = 5.0:
	get: return length; 
	set(value): length = value; if is_node_ready(): call_deferred("_rebuild", self) 
@export var spread: bool = true:
	get: return spread; 
	set(value): spread = value; if is_node_ready(): call_deferred("_rebuild", self) 
@export var color: Color = Color(1, 0.95, 0.8, 0.3):
	get: return color; 
	set(value): color = value; if is_node_ready(): call_deferred("_rebuild", self) 
@export var uv_tile_count: int = 1:
	get: return uv_tile_count; 
	set(value): uv_tile_count = value; if is_node_ready(): call_deferred("_rebuild", self) 
@export var collision_mask: int = 524288: # Default to layer 1, 524288 = 20 // all = 4294967295  (they are in 32Bits)
	get: return collision_mask; 
	set(value): collision_mask = value; if is_node_ready(): call_deferred("_rebuild", self) 

@export_range(-2.0, 8.0, 0.5) var hit_penetration_offset: float = 3.0: # New variable
	get: return hit_penetration_offset; 
	set(value): hit_penetration_offset = value; if is_node_ready(): call_deferred("_rebuild", self) 


func _ready() -> void:
	# print("--- LightShaft3DUpdated: _ready() called ---") # You can uncomment for debugging
	outline.connect("local_transform_changed", Callable(self, "_rebuild"))
	outline.curve.changed.connect(Callable(self, "_rebuild"))
	origin.connect("local_transform_changed", Callable(self, "_rebuild"))

	call_deferred("_rebuild", self) 

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	call_deferred("_rebuild", self) 
	return


func _rebuild(caller_parent:Node) -> void:
	# print("--- LightShaft3DUpdated: _rebuild() CALLED --- with caller_parent: ", caller_parent.name)

	if caller_parent != self:
		print("LightShaft3DUpdated: _rebuild() called by non-self node =>" + caller_parent.name)
		return	

	if not is_node_ready():
		await ready 
		if not is_node_ready():
			return


	if not is_instance_valid(mesh) or not (mesh is ArrayMesh): mesh = ArrayMesh.new()

	if not is_instance_valid(origin) or not is_instance_valid(outline) or not is_instance_valid(outline.curve):
		printerr("LightShaft3DUpdated: EXITING _rebuild - Critical: Origin or Outline or Outline.Curve is not valid.")
		return 
	if outline.curve.point_count == 0:
		printerr("LightShaft3DUpdated: EXITING _rebuild - Critical: Outline curve has no points.")
		return

	# print("LightShaft3DUpdated: _rebuild - Origin, Outline, and Curve are valid. Point count: ", outline.curve.point_count)

	var space_state: PhysicsDirectSpaceState3D
	var current_world_3d = get_world_3d()
	if current_world_3d != null: 
		space_state = current_world_3d.direct_space_state
		# print("LightShaft3DUpdated: Physics space_state is valid: ", is_instance_valid(space_state))
	# else:
		# print("LightShaft3DUpdated: get_world_3d() is NULL. Cannot perform raycasts.")
		# pass

	var verts: PackedVector3Array; var normals: PackedVector3Array; var colors: PackedColorArray; var uvs: PackedVector2Array; var indices: PackedInt32Array
	var origin_global_pos := origin.global_position
	var outline_curve_ref := outline.curve
	var outline_baked_length := outline_curve_ref.get_baked_length()
	if outline_baked_length == 0.0: outline_baked_length = 1.0 
	var num_actual_outline_points_for_loop = outline_curve_ref.point_count
	var num_segments = outline_curve_ref.point_count
	if not outline_curve_ref.closed: num_segments = max(0, outline_curve_ref.point_count -1)

	# print("LightShaft3DUpdated: Starting vertex loop for %d points." % num_actual_outline_points_for_loop)

	for i in num_actual_outline_points_for_loop: 
		var p_on_outline_global := outline.to_global(outline_curve_ref.get_point_position(i))
		var p_local := to_local(p_on_outline_global) 
		verts.append(p_local)

		var ray_dir_global: Vector3
		if spread: ray_dir_global = (p_on_outline_global - origin_global_pos).normalized()
		else: ray_dir_global = -origin.global_transform.basis.z.normalized()

		var current_ray_length = length # Default to full length
		
		if is_instance_valid(space_state):
			var ray_from_global = p_on_outline_global 
			# Define ray_to_global based on the original maximum length for the query
			var ray_to_query_end = ray_from_global + ray_dir_global * length 
			
			# Start ray slightly off the surface to avoid immediate self-hits
			var query_start_point = ray_from_global + ray_dir_global * 0.001
			
			var query := PhysicsRayQueryParameters3D.create(query_start_point, ray_to_query_end) 
			query.collide_with_areas = false
			query.collide_with_bodies = true
			query.collision_mask = collision_mask
			
			# print("Segment ", i, ": Casting ray from ", query.from, " to ", query.to, " mask: ", query.collision_mask)
			
			var result: Dictionary = space_state.intersect_ray(query)
			
			if result.size() > 0: # A non-empty dictionary means a hit
				var hit_point_global: Vector3 = result.get("position", ray_to_query_end) # Fallback to original end if no position
				
				# Calculate distance from the actual outline point (p_on_outline_global) to the hit point
				var distance_to_hit = p_on_outline_global.distance_to(hit_point_global)
				
				# Apply the penetration offset
				var length_after_hit_and_offset = distance_to_hit + hit_penetration_offset
				
				# Clamp the length:
				# 1. It should not exceed the original max 'length' of the ray.
				# 2. It should not be less than a small epsilon (e.g., 0.01).
				current_ray_length = clamp(length_after_hit_and_offset, 0.01, length)
				
				# var hit_collider = result.get("collider") 
				# print("Segment ", i, ": Ray HIT. Collider: ", hit_collider.name if hit_collider is Node else "Non-Node", ". At: ", hit_point_global, ". New Length: ", current_ray_length)
			# else: 
				# current_ray_length = length # Already set, ray missed
				# print("Segment ", i, ": Ray MISSED. (Mask: %d)" % query.collision_mask)
		# else:
			# print("Segment ", i, ": space_state was NOT valid, ray uses full length.")
		
		var end_p_global = p_on_outline_global + ray_dir_global * current_ray_length
		var end_p_local = to_local(end_p_global)
		verts.append(end_p_local)
		
		var tangent = (end_p_local - p_local).normalized(); var normal = Vector3.UP
		if not tangent.is_zero_approx(): normal = tangent.cross( (to_local(origin_global_pos) - p_local).normalized() ).normalized()
		if normal.is_zero_approx(): normal = (p_local - to_local(origin_global_pos)).cross(tangent).normalized() 
		if normal.is_zero_approx(): normal = (global_transform.basis * Vector3.UP).cross(tangent).normalized() 
		if normal.is_zero_approx(): normal = Vector3.UP 
		normals.append(normal); normals.append(normal)

	# ... (UVs, Indices, Color, Mesh Surface Creation as before - ensure variable names i_uv, i_idx are used if you kept them from previous full script) ...
	var prev_p_uv_base := verts[0] if verts.size() > 0 else Vector3.ZERO
	var current_outline_dist_uv: float = 0.0
	var loop_limit_uvs = verts.size() / 2
	for i_uv in loop_limit_uvs: 
		var p_base_uv := verts[i_uv * 2] 
		if i_uv > 0: current_outline_dist_uv += prev_p_uv_base.distance_to(p_base_uv)
		var u_coord_val = 0.0
		if outline_baked_length > 0.001: u_coord_val = (current_outline_dist_uv / outline_baked_length) * float(uv_tile_count)
		uvs.append(Vector2(u_coord_val, 1)); uvs.append(Vector2(u_coord_val, 0)) 
		prev_p_uv_base = p_base_uv

	var loop_limit_indices = num_segments 
	for i_idx in loop_limit_indices: 
		var b0 = i_idx * 2; var b1 = ((i_idx + 1) % num_actual_outline_points_for_loop) * 2 
		indices.append(b0 + 0); indices.append(b0 + 1); indices.append(b1 + 0) 
		indices.append(b0 + 1); indices.append(b1 + 1); indices.append(b1 + 0) 

	colors.resize(verts.size()); colors.fill(color)
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_COLOR] = colors; arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_INDEX] = indices

	var old_mat: Material
	if mesh is ArrayMesh and mesh.get_surface_count() > 0: old_mat = mesh.surface_get_material(0)
	
	if mesh is ArrayMesh: 
		mesh.clear_surfaces()
		if verts.size() > 0 and indices.size() > 2 and indices.size() % 3 == 0 : 
			# print("LightShaft3DUpdated: Adding surface. Verts: ", verts.size(), ", Indices: ", indices.size())
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			if old_mat: mesh.surface_set_material(0, old_mat)
			else:
				var default_shaft_material = StandardMaterial3D.new()
				default_shaft_material.albedo_color = Color(1,1,1,0.5) 
				default_shaft_material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
				default_shaft_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
				default_shaft_material.cull_mode = BaseMaterial3D.CULL_DISABLED 
				mesh.surface_set_material(0, default_shaft_material)
		# else:
			# printerr("LightShaft3DUpdated: No valid mesh data. Verts: ", verts.size(), ", Indices: ", indices.size())

	visible = (mesh is ArrayMesh and mesh.get_surface_count() > 0)
	# print("--- LightShaft3DUpdated: _rebuild() finished. Visible: ", visible, " ---")
