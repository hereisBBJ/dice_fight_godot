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

const PANEL_DARK_GOLD = "res://assets/ui/panels/panel_dark_gold_normal.png"
const BUTTON_HEAVY_NORMAL = "res://assets/ui/buttons/btn_heavy_normal.png"
const BUTTON_HEAVY_HOVER = "res://assets/ui/buttons/btn_heavy_hover.png"
const BUTTON_HEAVY_PRESSED = "res://assets/ui/buttons/btn_heavy_pressed.png"
const BUTTON_HEAVY_DISABLED = "res://assets/ui/buttons/btn_heavy_disabled.png"
const PORTRAIT_FRAME_GOLD = "res://assets/ui/frames/frame_portrait_gold_normal.png"
const STATUS_BADGE_FRAME = "res://assets/ui/frames/frame_status_badge_normal.png"
const RESOURCE_BAR_FRAME = "res://assets/ui/frames/frame_resource_bar_gold.png"
const SKILL_CARD_NORMAL = "res://assets/ui/panels/panel_skill_card_normal.png"
const SKILL_CARD_DISABLED = "res://assets/ui/panels/panel_skill_card_disabled.png"


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


static func texture_style(path: String, fallback_style: StyleBox, texture_margins: Vector4, content_margins: Vector4, modulate: Color = Color.WHITE) -> StyleBox:
	if path.is_empty() or not FileAccess.file_exists(path):
		return fallback_style
	var loaded = load(path)
	var texture = loaded as Texture2D
	if texture == null:
		return fallback_style
	var style = StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = int(texture_margins.x)
	style.texture_margin_top = int(texture_margins.y)
	style.texture_margin_right = int(texture_margins.z)
	style.texture_margin_bottom = int(texture_margins.w)
	style.content_margin_left = content_margins.x
	style.content_margin_top = content_margins.y
	style.content_margin_right = content_margins.z
	style.content_margin_bottom = content_margins.w
	style.modulate_color = modulate
	return style


static func formal_panel_texture_style(bg_color: Color = COLOR_PANEL, border_color: Color = COLOR_GOLD) -> StyleBox:
	var fallback = formal_panel_style(bg_color, border_color, 6, 2)
	return texture_style(PANEL_DARK_GOLD, fallback, Vector4(56, 56, 56, 56), Vector4(22, 18, 22, 18))


static func inset_panel_texture_style(bg_color: Color = COLOR_PANEL_INNER, border_color: Color = COLOR_GOLD_DARK) -> StyleBox:
	var fallback = inset_panel_style(bg_color, border_color, 5)
	return texture_style(PANEL_DARK_GOLD, fallback, Vector4(56, 56, 56, 56), Vector4(14, 12, 14, 12), Color(0.82, 0.86, 0.92, 0.92))


static func portrait_frame_texture_style(border_color: Color = COLOR_GOLD) -> StyleBox:
	var fallback = inset_panel_style(Color(0.07, 0.08, 0.11, 1.0), border_color, 5)
	return texture_style(PORTRAIT_FRAME_GOLD, fallback, Vector4(54, 54, 54, 54), Vector4(12, 12, 12, 12))


static func status_badge_texture_style(border_color: Color = COLOR_GOLD) -> StyleBox:
	var fallback = panel_style(Color(0.08, 0.09, 0.11, 0.86), border_color, 5)
	return texture_style(STATUS_BADGE_FRAME, fallback, Vector4(18, 18, 18, 18), Vector4(6, 6, 6, 6))


static func resource_bar_texture_style() -> StyleBox:
	var fallback = panel_style(Color(0.05, 0.06, 0.09, 0.94), COLOR_GOLD_DARK, 4)
	return texture_style(RESOURCE_BAR_FRAME, fallback, Vector4(48, 8, 48, 8), Vector4(8, 3, 8, 3))


static func button_texture_style(state: String = "normal") -> StyleBox:
	var path = BUTTON_HEAVY_NORMAL
	var fallback_color = Color("#1B2130")
	var fallback_border = COLOR_GOLD
	if state == "hover":
		path = BUTTON_HEAVY_HOVER
		fallback_color = Color("#222C40")
		fallback_border = COLOR_ARCANE
	elif state == "pressed":
		path = BUTTON_HEAVY_PRESSED
		fallback_color = Color("#111722")
		fallback_border = COLOR_ARCANE
	elif state == "disabled":
		path = BUTTON_HEAVY_DISABLED
		fallback_color = Color("#24262A")
		fallback_border = Color("#5D6470")
	var fallback = formal_panel_style(fallback_color, fallback_border, 6, 2)
	return texture_style(path, fallback, Vector4(56, 30, 56, 30), Vector4(16, 8, 16, 8))


static func skill_card_texture_style(disabled: bool = false) -> StyleBox:
	var path = SKILL_CARD_DISABLED if disabled else SKILL_CARD_NORMAL
	var fallback_color = Color("#24262A") if disabled else Color("#1B2130")
	var fallback_border = Color("#5D6470") if disabled else COLOR_GOLD
	var fallback = formal_panel_style(fallback_color, fallback_border, 6, 2)
	return texture_style(path, fallback, Vector4(76, 36, 46, 36), Vector4(12, 10, 12, 10))


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
