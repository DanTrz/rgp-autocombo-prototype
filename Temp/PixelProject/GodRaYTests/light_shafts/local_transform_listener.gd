@tool
extends Node3D


signal local_transform_changed(caller_node:Node)
@export var parent: MeshInstance3D


func _ready() -> void:
	set_notify_local_transform(true)


func _notification(what: int) -> void:

	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		print("Emitting transform_changed from " + self.name + " For " + parent.name)
		local_transform_changed.emit(parent)
