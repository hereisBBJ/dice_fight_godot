extends TextureRect
class_name AnimatedSpriteTextureRect


const UIAssetsScript = preload("res://scripts/ui/components/ui_assets.gd")

var _frames: Array[Texture2D] = []
var _frame_index = 0
var _elapsed = 0.0
var _fps = 6.0
var _loop = true


func set_character_animation(character: Dictionary, fallback_color: Color, fallback_size: Vector2i = Vector2i(192, 192), preferred_animation: String = "battle_idle") -> void:
	_frames.clear()
	_frame_index = 0
	_elapsed = 0.0
	set_process(false)

	var manifest_path = String(character.get("animation_manifest_path", ""))
	if not manifest_path.is_empty() and _load_manifest_frames(manifest_path, preferred_animation):
		texture = _frames[0]
		set_process(_frames.size() > 1)
		return

	if manifest_path.is_empty() and _load_sprite_frames(String(character.get("animation_sprite_frames_path", "")), preferred_animation):
		texture = _frames[0]
		set_process(_frames.size() > 1)
		return

	texture = UIAssetsScript.texture_from_path(String(character.get("portrait_path", "")), fallback_color, fallback_size)


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
				_frame_index = _frames.size() - 1
				set_process(false)
				break
			_frame_index = 0
		texture = _frames[_frame_index]


func _load_sprite_frames(path: String, preferred_animation: String) -> bool:
	if path.is_empty():
		return false
	if not ResourceLoader.exists(path):
		return false
	var loaded = load(path)
	if not loaded is SpriteFrames:
		return false
	var sprite_frames: SpriteFrames = loaded
	var animation = _pick_animation(sprite_frames, preferred_animation)
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


func _load_manifest_frames(path: String, preferred_animation: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	var manifest: Dictionary = parsed
	var animation = _pick_manifest_animation(manifest, preferred_animation)
	if animation.is_empty():
		return false
	var animations: Dictionary = manifest.get("animations", {})
	var spec: Dictionary = animations.get(animation, {})
	var atlas_path = String(manifest.get("atlas_path", ""))
	if atlas_path.is_empty() or not FileAccess.file_exists(atlas_path):
		return false
	var image = Image.new()
	if image.load(atlas_path) != OK:
		return false
	var atlas_texture = ImageTexture.create_from_image(image)
	var cell_size: Array = manifest.get("cell_size", [128, 128])
	if cell_size.size() < 2:
		return false
	var cell_width = int(cell_size[0])
	var cell_height = int(cell_size[1])
	var frame_count = int(spec.get("frames", 0))
	var row = int(spec.get("row", 0))
	if cell_width <= 0 or cell_height <= 0 or frame_count <= 0:
		return false
	for frame_index in range(frame_count):
		var frame_texture = AtlasTexture.new()
		frame_texture.atlas = atlas_texture
		frame_texture.region = Rect2(frame_index * cell_width, row * cell_height, cell_width, cell_height)
		_frames.append(frame_texture)
	_fps = float(spec.get("fps", 6.0))
	_loop = bool(spec.get("loop", true))
	return not _frames.is_empty()


func _pick_animation(sprite_frames: SpriteFrames, preferred_animation: String) -> String:
	var candidates = [preferred_animation, "battle_idle", "select_idle", "idle"]
	for candidate in candidates:
		if not String(candidate).is_empty() and sprite_frames.has_animation(String(candidate)):
			return String(candidate)
	var animation_names = sprite_frames.get_animation_names()
	if animation_names.size() > 0:
		return String(animation_names[0])
	return ""


func _pick_manifest_animation(manifest: Dictionary, preferred_animation: String) -> String:
	var animations: Dictionary = manifest.get("animations", {})
	var candidates = [preferred_animation, "battle_idle", "select_idle", "idle"]
	for candidate in candidates:
		var candidate_name = String(candidate)
		if not candidate_name.is_empty() and animations.has(candidate_name):
			return candidate_name
	var animation_names = animations.keys()
	if animation_names.size() > 0:
		return String(animation_names[0])
	return ""
