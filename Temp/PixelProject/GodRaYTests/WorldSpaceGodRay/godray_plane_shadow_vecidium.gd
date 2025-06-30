# Simple Working Ray Controller - One Raycast Per Ray
extends Node3D

@export var sun_light: DirectionalLight3D
@export var check_frequency: int = 5  # Check every N frames for performance
@export var hide_all_ray: bool = true

var frame_counter: int = 0

func _process(_delta):
	if not sun_light:
		return
		
	frame_counter += 1
	if frame_counter % check_frequency != 0:
		return
	
	# Check each ray segment in order
	for i in get_child_count():
		var segment = get_child(i) as MeshInstance3D
		if not segment:
			continue
		
		# Check if this segment's position is in shadow using ONE raycast
		if is_position_in_shadow(segment.global_position):
			# Hide this segment and all after it
			if hide_all_ray:
				hide_segments_from_index(0)
			else:
				hide_segments_from_index(i)
			return
	
	# No shadows found - show all segments
	show_all_segments()

func is_position_in_shadow(world_pos: Vector3) -> bool:
	"""Single raycast to check if position is in shadow"""
	
	# Get sun direction
	var sun_direction = -sun_light.global_transform.basis.z
	
	# Cast ray from position toward sun
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		world_pos,
		world_pos + sun_direction * -500.0  # 100 units toward sun
	)

	print(self.name, " raycasting to: " , sun_direction) # (-0.746199, -0.663991, -0.047988)

	
	# Exclude ray segments themselves
	query.exclude = get_ray_segment_rids()
	
	var result = space_state.intersect_ray(query)

	
	# #debug
	# if result.has("collider"):
	# 	print(self.name, "collided with: ", result.get("collider").name)

	# #debug
	
	# If ray hits something, position is in shadow
	return result.has("position")

func get_ray_segment_rids() -> Array[RID]:
	"""Get RIDs to exclude ray segments from collision"""
	var rids: Array[RID] = []
	for child in get_children():
		if child is MeshInstance3D:
			# Add any collision shapes associated with ray segments
			pass  # Most ray segments won't have collision
	return rids

func hide_segments_from_index(start_index: int):
	"""Hide this segment and all segments after it"""
	for i in range(start_index, get_child_count()):
		var child = get_child(i)
		if child is MeshInstance3D:
			child.visible = false

func show_all_segments():
	"""Show all segments"""
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = true
