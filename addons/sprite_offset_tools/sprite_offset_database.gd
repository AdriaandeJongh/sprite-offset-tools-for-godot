@tool
class_name SpriteOffsetDatabase
extends Object

const DATABASE_PATH = "res://sprite_offset_database.dat"

static var _db_initialized: bool = false
static var _db: Dictionary[String, Vector2] = {}


## Loads the database into cache.
static func _load_database() -> void:
	var f: FileAccess = FileAccess.open(DATABASE_PATH, FileAccess.READ)
	if f:
		_db = str_to_var(f.get_as_text())
		_db_initialized = true
	else:
		save_database()


## Save the cached sprite offset database to SpriteOffsetDatabase.DATABASE_PATH.
static func save_database() -> void:
	if _db.is_empty():
		return
	var f: FileAccess = FileAccess.open(DATABASE_PATH, FileAccess.WRITE)
	f.store_string(var_to_str(_db))


## Check whether a texture has an offset saved to the sprite offset database.
static func has_offset_for_texture(texture: Texture2D) -> bool:
	return has_offset_for_texture_uid(ResourceUID.path_to_uid(texture.resource_path))


## Check whether a texture has an offset saved to the sprite offset database.
static func has_offset_for_texture_uid(texture_uid: String) -> bool:
	if not _db_initialized:
		_load_database()
	return _db.has(texture_uid)


## Get the offset for a texture.
static func get_offset_for_texture(texture: Texture2D) -> Vector2:
	return get_offset_for_texture_uid(ResourceUID.path_to_uid(texture.resource_path))


## Get the offset for a texture.
static func get_offset_for_texture_uid(texture_uid: String) -> Vector2:
	if not _db_initialized:
		_load_database()
	return _db.get(texture_uid, Vector2.ZERO)


## Set the offset for a texture. Offset should be relative to the left top corner; not the center. If Sprite2D.centered is enabled, simply substract `texture.get_size() * 0.5` from the offset.
static func set_offset_for_texture(texture: Texture2D, offset: Vector2) -> void:
	set_offset_for_texture_uid(ResourceUID.path_to_uid(texture.resource_path), offset)


## Set the offset for a texture. Offset should be relative to the left top corner; not the center. If Sprite2D.centered is enabled, simply substract `texture.get_size() * 0.5` from the offset.
static func set_offset_for_texture_uid(texture_uid: String, offset: Vector2) -> void:
	if not _db_initialized:
		_load_database()
	_db[texture_uid] = offset


## Update a Sprite2D's offset to the offset found in the database. If `preserve_position` is `true`, the Sprite2D's position will also be updated to counteract the visual repositioning of the sprite.
static func update_offset(sprite: Sprite2D, preserve_position: bool) -> void:
	if not _db_initialized:
		_load_database()
	
	var texture_uid = ResourceUID.path_to_uid(sprite.texture.resource_path)
	var target_offset: Vector2
	if has_offset_for_texture_uid(texture_uid):
		target_offset = get_offset_for_texture_uid(texture_uid)
	else:
		target_offset = sprite.texture.get_size() * 0.5
	
	if not preserve_position:
		sprite.offset = sprite.texture.get_size() * 0.5 - target_offset
		return
	
	var current_offset: Vector2 = sprite.texture.get_size() * 0.5 - sprite.offset
	
	if target_offset != current_offset:
		var prev_offset: Vector2 = sprite.offset
		sprite.offset = sprite.texture.get_size() * 0.5 - target_offset
		sprite.position -= sprite.offset - prev_offset


## Clean up the database by removing 
static func cleanup() -> void:
	if not _db_initialized:
		_load_database()
	
	var keys_to_remove: Array[String] = []
	for s: String in _db.keys():
		var p: String = ResourceUID.uid_to_path(s)
		if not ResourceLoader.exists(p):
			keys_to_remove.append(s)
	
	if not keys_to_remove.is_empty():
		for s: String in keys_to_remove:
			_db.erase(s)
		Engine.get_singleton(&"EditorInterface").get_editor_toaster().push_toast("Removed " + str(keys_to_remove.size()) + " offsets from the database, most likely due to those assets no longer being in the project.")
	else:
		Engine.get_singleton(&"EditorInterface").get_editor_toaster().push_toast("No Sprite Offset items had to be cleaned up. You're good!")
	
	save_database()
