extends RefCounted
class_name UIAssets


static func color_from_hex(value: String, fallback: Color = Color(0.36, 0.45, 0.65)) -> Color:
	if value.is_empty():
		return fallback
	if not value.begins_with("#"):
		return fallback
	return Color.html(value)


static func texture_from_path(path: String, fallback_color: Color, size: Vector2i = Vector2i(128, 128)) -> Texture2D:
	if not path.is_empty():
		var loaded = load(path)
		if loaded is Texture2D:
			return loaded
	return make_color_texture(fallback_color, size)


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
