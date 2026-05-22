extends TextureRect
class_name AnimatedSpriteTextureRect


const UIAssetsScript = preload("res://scripts/ui/components/ui_assets.gd")

var _frames: Array[Texture2D] = []
var _frame_index = 0
var _elapsed = 0.0
var _fps = 6.0
var _loop = true
var _character: Dictionary = {}
var _character_id = ""
var _fallback_color = Color.WHITE
var _fallback_size = Vector2i(192, 192)
var _idle_animation = "battle_idle"
var _return_animation = ""
var _one_shot_active = false


func set_character_animation(character: Dictionary, fallback_color: Color, fallback_size: Vector2i = Vector2i(192, 192), preferred_animation: String = "battle_idle") -> void:
	var next_character_id = String(character.get("id", ""))
	if _one_shot_active and next_character_id == _character_id:
		return
	_character = character.duplicate(true)
	_character_id = next_character_id
	_fallback_color = fallback_color
	_fallback_size = fallback_size
	_idle_animation = preferred_animation
	_return_animation = ""
	_one_shot_active = false

	if _load_character_frames(preferred_animation, true):
		texture = _frames[0]
		set_process(_frames.size() > 1)
		return

	_show_fallback_texture()


func play_character_animation(animation_name: String, return_animation: String = "battle_idle") -> bool:
	if animation_name.is_empty() or _character.is_empty():
		return false
	var fallback_animation = return_animation
	if fallback_animation.is_empty():
		fallback_animation = _idle_animation
	if not _load_character_frames(animation_name, false):
		set_character_animation(_character, _fallback_color, _fallback_size, fallback_animation)
		return false
	_return_animation = fallback_animation
	_one_shot_active = true
	texture = _frames[0]
	if _frames.size() <= 1:
		_finish_one_shot()
	else:
		set_process(true)
	return true


func _process(delta: float) -> void:
	if _frames.is_empty():
		set_process(false)
		return
	_elapsed += delta
	var step = 1.0 / max(_fps, 1.0)
	while _elapsed >= step:
		_elapsed -= step
		_frame_index += 1
		if _frame_index >= _frames.size():
			if not _loop:
				if _one_shot_active and not _return_animation.is_empty():
					_finish_one_shot()
				else:
					_frame_index = _frames.size() - 1
					set_process(false)
				break
			_frame_index = 0
		texture = _frames[_frame_index]


func _load_character_frames(preferred_animation: String, allow_fallback: bool) -> bool:
	_frames.clear()
	_frame_index = 0
	_elapsed = 0.0
	set_process(false)

	var manifest_path = String(_character.get("animation_manifest_path", ""))
	if not manifest_path.is_empty() and _load_manifest_frames(manifest_path, preferred_animation, allow_fallback):
		return true
	var sprite_frames_path = String(_character.get("animation_sprite_frames_path", ""))
	if not sprite_frames_path.is_empty() and _load_sprite_frames(sprite_frames_path, preferred_animation, allow_fallback):
		return true
	return false


func _show_fallback_texture() -> void:
	texture = UIAssetsScript.texture_from_path(String(_character.get("portrait_path", "")), _fallback_color, _fallback_size)


func _finish_one_shot() -> void:
	var return_animation = _return_animation
	_return_animation = ""
	_one_shot_active = false
	set_character_animation(_character, _fallback_color, _fallback_size, return_animation)


func _load_sprite_frames(path: String, preferred_animation: String, allow_fallback: bool) -> bool:
	if path.is_empty():
		return false
	if not ResourceLoader.exists(path):
		return false
	var loaded = load(path)
	if not loaded is SpriteFrames:
		return false
	var sprite_frames: SpriteFrames = loaded
	var animation = _pick_animation(sprite_frames, preferred_animation, allow_fallback)
	if animation.is_empty():
		return false
	var frame_count = sprite_frames.get_frame_count(animation)
	if frame_count <= 0:
		return false
	for frame_index in range(frame_count):
		var frame_texture = sprite_frames.get_frame_texture(animation, frame_index)
		if frame_texture != null:
			_frames.append(frame_texture)
	if _frames.is_empty():
		return false
	_fps = float(sprite_frames.get_animation_speed(animation))
	_loop = bool(sprite_frames.get_animation_loop(animation))
	return true


func _load_manifest_frames(path: String, preferred_animation: String, allow_fallback: bool) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	var manifest: Dictionary = parsed
	var animation = _pick_manifest_animation(manifest, preferred_animation, allow_fallback)
	if animation.is_empty():
		return false
	var animations: Dictionary = manifest.get("animations", {})
	var spec: Dictionary = animations.get(animation, {})
	var atlas_path = String(manifest.get("atlas_path", ""))
	if atlas_path.is_empty() or not FileAccess.file_exists(atlas_path):
		return false
	var cell_size: Array = manifest.get("cell_size", [128, 128])
	if cell_size.size() < 2:
		return false
	var cell_width = int(cell_size[0])
	var cell_height = int(cell_size[1])
	var frame_count = int(spec.get("frames", 0))
	var row = int(spec.get("row", 0))
	if cell_width <= 0 or cell_height <= 0 or frame_count <= 0:
		return false
	var required_size = Vector2i(frame_count * cell_width, (row + 1) * cell_height)
	var atlas_size: Array = manifest.get("atlas_size", [])
	if atlas_size.size() >= 2:
		required_size.x = max(required_size.x, int(atlas_size[0]))
		required_size.y = max(required_size.y, int(atlas_size[1]))
	var atlas_texture = _load_atlas_texture(atlas_path, required_size)
	if atlas_texture == null:
		return false
	for frame_index in range(frame_count):
		var frame_texture = AtlasTexture.new()
		frame_texture.atlas = atlas_texture
		frame_texture.region = Rect2(frame_index * cell_width, row * cell_height, cell_width, cell_height)
		_frames.append(frame_texture)
	_fps = float(spec.get("fps", 6.0))
	_loop = bool(spec.get("loop", true))
	return not _frames.is_empty()


func _load_atlas_texture(path: String, required_size: Vector2i) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded_texture = load(path)
		if loaded_texture is Texture2D:
			var imported_texture: Texture2D = loaded_texture
			if imported_texture.get_width() >= required_size.x and imported_texture.get_height() >= required_size.y:
				return imported_texture
	var bytes = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var image = Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _pick_animation(sprite_frames: SpriteFrames, preferred_animation: String, allow_fallback: bool) -> String:
	var candidates = [preferred_animation]
	if allow_fallback:
		candidates.append_array(["battle_idle", "select_idle", "idle"])
	for candidate in candidates:
		if not String(candidate).is_empty() and sprite_frames.has_animation(String(candidate)):
			return String(candidate)
	if not allow_fallback:
		return ""
	var animation_names = sprite_frames.get_animation_names()
	if animation_names.size() > 0:
		return String(animation_names[0])
	return ""


func _pick_manifest_animation(manifest: Dictionary, preferred_animation: String, allow_fallback: bool) -> String:
	var animations: Dictionary = manifest.get("animations", {})
	var candidates = [preferred_animation]
	if allow_fallback:
		candidates.append_array(["battle_idle", "select_idle", "idle"])
	for candidate in candidates:
		var candidate_name = String(candidate)
		if not candidate_name.is_empty() and animations.has(candidate_name):
			return candidate_name
	if not allow_fallback:
		return ""
	var animation_names = animations.keys()
	if animation_names.size() > 0:
		return String(animation_names[0])
	return ""
