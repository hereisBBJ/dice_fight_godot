extends RefCounted
class_name UIAssets

const COLOR_BACKGROUND = Color("#10131A")
const COLOR_PANEL = Color("#1B2130")
const COLOR_PANEL_INNER = Color("#252C3D")
const COLOR_GOLD = Color("#C9973F")
const COLOR_GOLD_DARK = Color("#6F4B1E")
const COLOR_ARENA_BLUE = Color("#2F7FD8")
const COLOR_ARCANE = Color("#47C7D9")
const COLOR_TEXT = Color("#E8E2D6")
const COLOR_TEXT_MUTED = Color("#B8B0A3")


static func color_from_hex(value: String, fallback: Color = Color(0.36, 0.45, 0.65)) -> Color:
	if value.is_empty():
		return fallback
	if not value.begins_with("#"):
		return fallback
	return Color.html(value)


static func texture_from_path(path: String, fallback_color: Color, size: Vector2i = Vector2i(128, 128)) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return make_color_texture(fallback_color, size)

	if path.to_lower().ends_with(".svg"):
		var svg_texture = _texture_from_svg(path)
		if svg_texture != null:
			return svg_texture

	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Texture2D:
			return loaded
	return make_color_texture(fallback_color, size)


static func _texture_from_svg(path: String) -> Texture2D:
	if not path.to_lower().ends_with(".svg"):
		return null
	var raw = FileAccess.get_file_as_string(path)
	if raw.is_empty():
		return null
	var image = Image.new()
	var error = image.load_svg_from_string(raw)
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)


static func make_color_texture(color: Color, size: Vector2i = Vector2i(128, 128)) -> Texture2D:
	var image = Image.create(max(1, size.x), max(1, size.y), false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


static func panel_style(bg_color: Color, border_color: Color = Color(0.25, 0.27, 0.31), radius: int = 6) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


static func formal_panel_style(bg_color: Color = COLOR_PANEL, border_color: Color = COLOR_GOLD, radius: int = 6, border_width: int = 2) -> StyleBoxFlat:
	var style = panel_style(bg_color, border_color, radius)
	style.set_border_width_all(border_width)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style


static func inset_panel_style(bg_color: Color = COLOR_PANEL_INNER, border_color: Color = COLOR_GOLD_DARK, radius: int = 5) -> StyleBoxFlat:
	var style = formal_panel_style(bg_color, border_color, radius, 1)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 1)
	return style


static func arena_style() -> StyleBoxFlat:
	var style = formal_panel_style(Color("#0E233D"), COLOR_ARENA_BLUE, 4, 2)
	style.bg_color = Color(0.05, 0.12, 0.22, 1.0)
	style.border_color = COLOR_ARENA_BLUE
	return style


static func apply_label_color(label: Label, color: Color = COLOR_TEXT, muted: bool = false) -> void:
	label.add_theme_color_override("font_color", COLOR_TEXT_MUTED if muted else color)
