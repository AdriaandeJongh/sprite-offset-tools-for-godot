extends EditorInspectorPlugin

var is_last_property_offset: bool = false

var _is_multi_selected: bool = false
var _multiple_sprites: Array[Sprite2D] = []

func _can_handle(object) -> bool:
	_is_multi_selected = false
	_multiple_sprites.clear()
	
	if object is Sprite2D:
		return true
	
	if object.get_class() == "MultiNodeEdit":
		var all_sprite_2d_nodes: bool = true
		for n: Node in EditorInterface.get_selection().get_selected_nodes():
			if n is not Sprite2D:
				all_sprite_2d_nodes = false
				break
			_multiple_sprites.append(n)
		_is_multi_selected = true
		return all_sprite_2d_nodes
	
	return false


func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if name == "offset":
		is_last_property_offset = true
		return false
	
	if not is_last_property_offset:
		return false
	
	var sprite: Sprite2D = object as Sprite2D
	var vbox: VBoxContainer = VBoxContainer.new()
	
	var update_offset_preserved: Button = Button.new()
	vbox.add_child(update_offset_preserved)
	update_offset_preserved.text = "Load Offset & Preserve Position"
	update_offset_preserved.tooltip_text = "If this Sprite2D's texture is present in the Sprite Offset Database, apply the offset to this Sprite2D. If the offset is changed, this node's position will be updated in the opposite direction so the location of the sprite stays the same."
	if _is_multi_selected:
		update_offset_preserved.pressed.connect(_on_update_multiple_offsets.bindv([true]))
	else:
		update_offset_preserved.pressed.connect(_on_update_offset.bindv([sprite, true]))
	
	var update_offset_unpreserved: Button = Button.new()
	vbox.add_child(update_offset_unpreserved)
	update_offset_unpreserved.text = "Load Offset & Update Position"
	update_offset_unpreserved.tooltip_text = "If this Sprite2D's texture is present in the Sprite Offset Database, apply the offset to this Sprite2D. If the offset is changed, the location of the sprite will jump as the node's position remains the same."
	if _is_multi_selected:
		update_offset_unpreserved.pressed.connect(_on_update_multiple_offsets.bindv([false]))
	else:
		update_offset_unpreserved.pressed.connect(_on_update_offset.bindv([sprite, false]))
	
	if not _is_multi_selected:
		var save_offset: Button = Button.new()
		vbox.add_child(save_offset)
		save_offset.text = "Save Offset to Database"
		save_offset.pressed.connect(_on_save_offset.bindv([sprite]))
	
	add_custom_control(vbox)
	
	is_last_property_offset = false
	
	return false


func _on_update_offset(sprite: Sprite2D, preserve_position: bool) -> void:
	var undoredo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undoredo.create_action("Load Offset from Sprite Offset Database")
	undoredo.add_undo_property(sprite, &"position", sprite.position)
	undoredo.add_undo_property(sprite, &"offset", sprite.offset)
	undoredo.add_do_method(self, &"_do_update_offset", sprite, preserve_position)
	undoredo.commit_action()


func _on_update_multiple_offsets(preserve_position: bool) -> void:
	var undoredo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undoredo.create_action("Load Offsets from Sprite Offset Database")
	for s: Sprite2D in _multiple_sprites:
		undoredo.add_undo_property(s, &"position", s.position)
		undoredo.add_undo_property(s, &"offset", s.offset)
		undoredo.add_do_method(self, &"_do_update_offset", s, preserve_position)
	undoredo.commit_action()


func _do_update_offset(sprite: Sprite2D, preserve_position: bool) -> void:
	SpriteOffsetDatabase.update_offset(sprite, preserve_position)


func _on_save_offset(sprite: Sprite2D) -> void:
	var o: Vector2 = -sprite.offset
	if sprite.centered:
		o += sprite.texture.get_size() * 0.5
	SpriteOffsetDatabase.set_offset_for_texture(sprite.texture, o)
	SpriteOffsetDatabase.save_database()
