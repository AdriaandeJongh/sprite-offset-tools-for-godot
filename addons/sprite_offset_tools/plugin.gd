@tool
extends EditorPlugin

var sprite_offset_editor: EditorDock
var sprite_2d_inspector: EditorInspectorPlugin


func _enter_tree() -> void:
	sprite_offset_editor = preload("uid://ngrx3lxeecv3").instantiate()
	add_dock(sprite_offset_editor)
	
	sprite_2d_inspector = preload("uid://mvbur8ljor5g").new()
	add_inspector_plugin(sprite_2d_inspector)


func _exit_tree() -> void:
	remove_dock(sprite_offset_editor)
	remove_inspector_plugin(sprite_2d_inspector)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		get_tree().node_added.connect(_on_node_added)
	elif what == NOTIFICATION_DRAG_END:
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node):
	var sprite := node as Sprite2D
	if not sprite:
		return
	
	if not EditorInterface.get_edited_scene_root() or not EditorInterface.get_edited_scene_root().is_ancestor_of(sprite):
		return
	
	update_offset(sprite)


func update_offset(sprite: Sprite2D) -> void:
	await get_editor_interface().get_base_control().get_tree().process_frame
	SpriteOffsetDatabase.update_offset(sprite, true)
