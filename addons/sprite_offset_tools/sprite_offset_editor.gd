@tool
extends EditorDock

enum Tools {
	CLEANUP,
	REAPPLY_IN_SCENES,
}

@onready var texture_rect: TextureRect = %TextureRect
@onready var timer: Timer = %SaveTimer
@onready var no_select_label: Label = %NoSelectLabel
@onready var reference_rect: ReferenceRect = %ReferenceRect
@onready var tools_menu: MenuButton = %MenuButton
@onready var scale_slider: EditorSpinSlider = %EditorSpinSlider

var texture_scale: float = 4.0
var current_texture: String


func _ready() -> void:
	EditorInterface.get_file_system_dock().selection_changed.connect(_try_select_from_fs)
	visibility_changed.connect(_on_visibility_changed)
	
	tools_menu.get_popup().clear()
	tools_menu.get_popup().id_pressed.connect(_on_tools_menu_item_pressed)
	tools_menu.get_popup().add_item("Clear old & invalid offsets from database", Tools.CLEANUP)
	tools_menu.get_popup().add_item("Update offsets in all scenes…", Tools.REAPPLY_IN_SCENES)
	
	scale_slider.value_changed.connect(_on_slider_value_changed)
	
	_try_select_from_fs()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_deselect_texture()
		tools_menu.get_popup().clear()


func _load_layout_from_config(config: ConfigFile, section: String) -> void:
	texture_scale = config.get_value("Sprite Offset Editor", "texture_scale", 4.0)
	texture_scale = clampf(texture_scale, 1.0, 10.0)
	scale_slider.set_value_no_signal(texture_scale)
	_try_select_from_fs()


func _save_layout_to_config(config: ConfigFile, section: String) -> void:
	config.set_value("Sprite Offset Editor", "texture_scale", texture_scale)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_try_select_from_fs()


func _try_select_from_fs():
	if not is_visible_in_tree():
		return
	
	var selected: PackedStringArray = EditorInterface.get_selected_paths()
	var selected_png: String = ""
	for s: String in selected:
		var ext: String = s.get_extension()
		if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "svg":
			if selected_png.is_empty():
				selected_png = s
			else:
				_deselect_texture()
				return
	
	if selected_png.is_empty():
		_deselect_texture()
		return
	
	timer.stop()
	_select_texture(selected_png)


func _deselect_texture() -> void:
	no_select_label.show()
	current_texture = ""
	texture_rect.texture = null
	texture_rect.custom_minimum_size = Vector2.ONE * 200.0
	reference_rect.hide()


func _select_texture(path: String):
	no_select_label.hide()
	current_texture = ResourceUID.path_to_uid(path)
	texture_rect.texture = load(path)
	texture_rect.custom_minimum_size = texture_rect.texture.get_size() * texture_scale
	reference_rect.show()
	
	# Save the default offset (center) to the database if it isn't present there yet, so that there is
	# no confusion when someone looks at the offset, sees it at the center, but doesn't get the center when
	# programmatically getting the offset for that texture later.
	if not SpriteOffsetDatabase.has_offset_for_texture_uid(current_texture):
		SpriteOffsetDatabase.set_offset_for_texture_uid(current_texture, texture_rect.texture.get_size() * 0.5)
		_save_database()


func _on_texture_rect_gui_input(event: InputEvent) -> void:
	var new_pos: Vector2 = Vector2.ZERO
	var update_pos: bool = false
	
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		new_pos = mb.position
		update_pos = true
	
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm and mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
		new_pos = mm.position
		update_pos = true
	
	if update_pos:
		new_pos = new_pos / texture_scale
		SpriteOffsetDatabase.set_offset_for_texture_uid(current_texture, new_pos)
		texture_rect.queue_redraw()
		timer.start()


func _save_database() -> void:
	SpriteOffsetDatabase.save_database()


func _on_texture_rect_draw() -> void:
	if current_texture.is_empty():
		return
	
	var texture := get_theme_icon(&"EditorPivot", &"EditorIcons")
	var pivot: Vector2
	
	if SpriteOffsetDatabase.has_offset_for_texture_uid(current_texture):
		pivot = SpriteOffsetDatabase.get_offset_for_texture_uid(current_texture)
	else:
		pivot = texture_rect.texture.get_size() * 0.5
	
	texture_rect.draw_texture(texture, pivot * texture_scale - texture.get_size() * 0.5)


func _on_tools_menu_item_pressed(id: int) -> void:
	match id:
		Tools.CLEANUP:
			SpriteOffsetDatabase.cleanup()
		Tools.REAPPLY_IN_SCENES:
			var cd: ConfirmationDialog = ConfirmationDialog.new()
			cd.dialog_text = "This will open every scene in your project, update the offset of every Sprite2D node in the scene (maintaining its position), and save and close the scenes. This action can take a while and can't be undone in the editor  – only through version control software. Are you sure you want to continue?"
			cd.dialog_autowrap = true
			cd.confirmed.connect(_reapply_offsets_in_all_scenes)
			EditorInterface.popup_dialog_centered(cd)


func _reapply_offsets_in_all_scenes() -> void:
	var scene_list: PackedStringArray
	_find_scenes("res://", scene_list)
	
	var open_scenes: PackedStringArray = EditorInterface.get_open_scenes()
	var open_roots: Array[Node] = EditorInterface.get_open_scene_roots()
	
	for scene: String in scene_list:
		if scene in open_scenes:
			for root: Node in open_roots:
				if root.scene_file_path == scene:
					_fix_scene(root)
					break
		else:
			EditorInterface.open_scene_from_path(scene)
			_fix_scene(EditorInterface.get_edited_scene_root())
			EditorInterface.save_scene()
			EditorInterface.close_scene()
	
	EditorInterface.save_all_scenes()
	EditorInterface.get_editor_toaster().push_toast("Updated the offsets of all Sprite2D nodes in " + str(scene_list.size()) + " scenes.")


func _find_scenes(dir: String, list: PackedStringArray):
	var da: DirAccess = DirAccess.open(dir)
	da.include_navigational = false
	da.list_dir_begin()
	
	var f: String = da.get_next()
	while not f.is_empty():
		if da.current_is_dir() and not f.begins_with(".") and f != "addons":
			_find_scenes(dir.path_join(f), list)
		elif f.get_extension() == "tscn":
			list.append(dir.path_join(f))
		
		f = da.get_next()
	
	da.list_dir_end()


func _fix_scene(node: Node):
	if node is Sprite2D:
		var s: Sprite2D = node as Sprite2D
		if SpriteOffsetDatabase.has_offset_for_texture(s.texture):
			SpriteOffsetDatabase.update_offset(s, true)
	
	for child in node.get_children():
		_fix_scene(child)


func _on_slider_value_changed(v: float) -> void:
	texture_scale = v
	
	if current_texture.is_empty():
		return
	
	_select_texture(ResourceUID.uid_to_path(current_texture))
