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

	if _load_sprite_frames(String(character.get("animation_sprite_frames_path", "")), preferred_animation):
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


func _pick_animation(sprite_frames: SpriteFrames, preferred_animation: String) -> String:
	var candidates = [preferred_animation, "battle_idle", "select_idle", "idle"]
	for candidate in candidates:
		if not String(candidate).is_empty() and sprite_frames.has_animation(String(candidate)):
			return String(candidate)
	var animation_names = sprite_frames.get_animation_names()
	if animation_names.size() > 0:
		return String(animation_names[0])
	return ""
