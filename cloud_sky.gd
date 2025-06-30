extends Node3D

@export var dissolve_time: float = 0.1
@export var is_dissolve_clouds: bool = false
var clouds: Array

func _ready() -> void:
	clouds = self.get_children()
	dissolve_clouds()

func dissolve_clouds():
	if is_dissolve_clouds:
		for cloud in clouds:
			await get_tree().create_timer(dissolve_time).timeout
			remove_child(cloud)
			cloud.call_deferred("queue_free")	
