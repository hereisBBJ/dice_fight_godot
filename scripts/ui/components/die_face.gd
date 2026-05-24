extends PanelContainer
class_name DieFace

const STATE_FACE = "face"
const STATE_HIDDEN = "hidden"
const STATE_EMPTY = "empty"

const FACE_TEXTURE_PATHS = {
	1: "res://assets/ui/dice/die_1_normal.svg",
	2: "res://assets/ui/dice/die_2_normal.svg",
	3: "res://assets/ui/dice/die_3_normal.svg",
	4: "res://assets/ui/dice/die_4_normal.svg",
	5: "res://assets/ui/dice/die_5_normal.svg",
	6: "res://assets/ui/dice/die_6_normal.svg",
}
const HIDDEN_TEXTURE_PATH = "res://assets/ui/dice/die_back_hidden.svg"
const EMPTY_TEXTURE_PATH = "res://assets/ui/dice/die_empty_normal.svg"

@export var die_size: int = 52

var _value: int = 0
var _state: String = STATE_EMPTY
var _selected: bool = false

@onready var _texture_rect: TextureRect = $Texture
@onready var _pip_layer: Control = $Pips
@onready var _hidden_label: Label = $HiddenLabel


func _ready() -> void:
	custom_minimum_size = Vector2(die_size, die_size)
	_render()


func set_die(value: int, state: String = STATE_FACE, selected: bool = false) -> void:
	_value = value
	_state = state
	_selected = selected
	if _state == STATE_FACE and (_value < 1 or _value > 6):
		_state = STATE_EMPTY
	_render()


func play_snapshot_animation(delay: float = 0.0) -> void:
	pivot_offset = Vector2(die_size, die_size) * 0.5
	scale = Vector2(0.82, 0.82)
	rotation = -0.08 if int(delay * 1000.0) % 2 == 0 else 0.08
	var tween = create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "rotation", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _render() -> void:
	add_theme_stylebox_override("panel", _panel_style())
	if _texture_rect == null:
		return
	_texture_rect.texture = null
	_texture_rect.modulate = Color(1, 1, 1, 1)
	if _state == STATE_HIDDEN:
		_texture_rect.texture = _texture_for_state()
		_texture_rect.modulate = Color(0.78, 0.84, 0.96, 0.22)
		tooltip_text = "隐藏骰子"
	elif _state == STATE_EMPTY:
		_texture_rect.texture = _texture_for_state()
		_texture_rect.modulate = Color(0.72, 0.75, 0.82, 0.18)
		tooltip_text = "空骰位"
	else:
		tooltip_text = "骰子 %d" % _value
	_render_pips()


func _render_pips() -> void:
	if _pip_layer == null or _hidden_label == null:
		return
	for child in _pip_layer.get_children():
		child.queue_free()
	_hidden_label.visible = _state != STATE_FACE
	_hidden_label.text = "?" if _state == STATE_HIDDEN else "-"
	if _state != STATE_FACE:
		return
	for pip_position in _pip_positions(_value):
		_pip_layer.add_child(_make_pip(pip_position))


func _pip_positions(value: int) -> Array:
	match value:
		1:
			return [Vector2(0.5, 0.5)]
		2:
			return [Vector2(0.30, 0.30), Vector2(0.70, 0.70)]
		3:
			return [Vector2(0.30, 0.30), Vector2(0.5, 0.5), Vector2(0.70, 0.70)]
		4:
			return [Vector2(0.30, 0.30), Vector2(0.70, 0.30), Vector2(0.30, 0.70), Vector2(0.70, 0.70)]
		5:
			return [Vector2(0.30, 0.30), Vector2(0.70, 0.30), Vector2(0.5, 0.5), Vector2(0.30, 0.70), Vector2(0.70, 0.70)]
		6:
			return [Vector2(0.30, 0.26), Vector2(0.70, 0.26), Vector2(0.30, 0.50), Vector2(0.70, 0.50), Vector2(0.30, 0.74), Vector2(0.70, 0.74)]
	return []


func _make_pip(pip_position: Vector2) -> ColorRect:
	var pip = ColorRect.new()
	pip.color = Color("#11151D")
	pip.custom_minimum_size = Vector2(7, 7)
	pip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pip.anchor_left = pip_position.x
	pip.anchor_top = pip_position.y
	pip.anchor_right = pip_position.x
	pip.anchor_bottom = pip_position.y
	pip.offset_left = -4
	pip.offset_top = -4
	pip.offset_right = 4
	pip.offset_bottom = 4
	return pip


func _texture_for_state() -> Texture2D:
	var path = EMPTY_TEXTURE_PATH
	var fallback_color = Color("#252C3D")
	if _state == STATE_HIDDEN:
		path = HIDDEN_TEXTURE_PATH
		fallback_color = Color("#1B2130")
	elif _state == STATE_FACE:
		var path_value = FACE_TEXTURE_PATHS.get(_value, EMPTY_TEXTURE_PATH)
		path = str(path_value)
		fallback_color = Color("#E5D6AA")
	return UIAssets.texture_from_path(path, fallback_color, Vector2i(128, 128))


func _panel_style() -> StyleBoxFlat:
	var bg_color = Color("#151A25")
	var border_color = UIAssets.COLOR_GOLD_DARK
	var border_width = 1
	if _state == STATE_FACE:
		bg_color = Color("#D8CDAF")
		border_color = UIAssets.COLOR_GOLD
		border_width = 2
	elif _state == STATE_HIDDEN:
		bg_color = Color("#111824")
		border_color = Color("#355D86")
	if _selected:
		border_color = UIAssets.COLOR_ARCANE
		border_width = 2
	var style = UIAssets.formal_panel_style(bg_color, border_color, 6, border_width)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
