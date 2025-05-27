extends Node3D
class_name TerrainTextureBlendController
# Export a NodePath to your main Terrain3D node. Assign this in the Godot Inspector.
@export var terrain3DNode: Terrain3D:
	set(value):
		terrain3DNode = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_attempt_editor_update_if_ready")

# Hardness preferences by Texture ID. Edit in Inspector.
#hard edges // smooth edges would be 0.0
@export var texture_id_to_hardness_map: Dictionary = {
	1: 1.0, 
	3: 1.0, 
	4: 1.0,
	5: 1.0, 
}:
	set(value):
		texture_id_to_hardness_map = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_attempt_editor_update_if_ready")

# Hardness preferences by Texture Name (case-insensitive). Edit in Inspector.
@export var texture_name_to_hardness_map: Dictionary = {
	"grasstext48px": 0.0, # Example name, ensure it's lowercase
	"rock_detail": 1.0,
}:
	set(value):
		texture_name_to_hardness_map = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_attempt_editor_update_if_ready")


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_attempt_editor_update_if_ready")

func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_attempt_editor_update_if_ready")
	else: # Game runtime
		_initialize_and_update_shader()

func _attempt_editor_update_if_ready() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	
	if terrain3DNode.is_empty(): return
	
	if not is_instance_valid(terrain3DNode): return

	# Check for .assets and its texture_assets array
	if not is_instance_valid(terrain3DNode.assets): return
	if not terrain3DNode.assets.get("texture_assets") is Array : return # texture_assets is an export var in Terrain3DAssets
	
	# Check for material
	if not is_instance_valid(terrain3DNode.material): return
	
	_initialize_and_update_shader()

func _initialize_and_update_shader() -> bool:
	if not is_instance_valid(terrain3DNode):
		if not Engine.is_editor_hint(): printerr("%s: Terrain3D Node Path is not set." % [name])
		return false
	
	update_shader_hardness_preferences()
	return true

func update_shader_hardness_preferences() -> void:
	if not is_instance_valid(terrain3DNode):
		return

	var hardness_values := PackedFloat32Array()
	hardness_values.resize(32) 
	for i: int in range(32):
		hardness_values[i] = 0.0

	# Access 'assets' property directly. Terrain3D class exports this.
	var assets: Terrain3DAssets = terrain3DNode.assets 
	if not is_instance_valid(assets):
		var msg_a_null: String = "%s: Terrain3D assets is not valid or not found on the Terrain3D node." % [name]
		if Engine.is_editor_hint(): print(msg_a_null) 
		else: printerr(msg_a_null)
		return

	# Access 'texture_assets' array from Terrain3DAssets.
	# This is an Array[Terrain3DTextureAsset] and may contain nulls for unassigned slots.
	var texture_assets_array: Array = assets.texture_list
	if not texture_assets_array is Array:
		var msg_a_tex_not_arr: String = "%s: assets.texture_assets is not an Array. Actual type: %s" % [name, typeof(texture_assets_array)]
		if Engine.is_editor_hint(): print(msg_a_tex_not_arr) 
		else: printerr(msg_a_tex_not_arr)
		return
	
	# Iterate through the texture_assets array. It's pre-sized to MAX_TEXTURES (32).
	# Elements can be null if a texture slot is not filled.
	for i: int in range(texture_assets_array.size()): # Should be 32
		var texture_asset_variant = texture_assets_array[i]
		if texture_asset_variant == null: # Skip empty slots
			continue

		var texture_asset := texture_asset_variant as Terrain3DTextureAsset
		if is_instance_valid(texture_asset):
			# The ID of the texture asset should match its slot 'i' if properly set by Terrain3DAssets.set_texture(),
			# or use texture_asset.id directly as it's set there.
			var tex_id: int = texture_asset.id 
			var tex_name_str: String = str(texture_asset.name).to_lower()

			if tex_id >= 0 and tex_id < 32: # Ensure ID is valid for our hardness_values array
				var desired_hardness: float = 0.0 
				
				if texture_id_to_hardness_map.has(tex_id):
					desired_hardness = texture_id_to_hardness_map[tex_id]
				elif texture_name_to_hardness_map.has(tex_name_str):
					desired_hardness = texture_name_to_hardness_map[tex_name_str]
				
				hardness_values[tex_id] = desired_hardness
	
	# var target_material = _terrain_3d_node.material
	# if not is_instance_valid(target_material):
	# 	target_material = _terrain_3d_node.material

	# if is_instance_valid(target_material) and target_material.has_method("set_shader_parameter"):
	# 	target_material.set_shader_parameter("texture_edge_hardness", hardness_values)
	if is_instance_valid(terrain3DNode.material):
		terrain3DNode.material.set_shader_param("texture_edge_hardness", hardness_values)
	else:
		# (Logging for invalid material as before)
		var msg_mat_err: String = "%s: Could not find a suitable material to set shader parameter." % [name]
		if is_instance_valid(terrain3DNode.material): msg_mat_err += " Found material of type: %s." % terrain3DNode.material.get_class()
		else: msg_mat_err += " No valid material found (override or internal)."
		if Engine.is_editor_hint(): print(msg_mat_err) 
		else: printerr(msg_mat_err)
