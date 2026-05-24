extends HBoxContainer
class_name DiceTray

const DieFaceScene = preload("res://scenes/ui/components/die_face.tscn")
const DIE_STATE_FACE = "face"
const DIE_STATE_HIDDEN = "hidden"
const DIE_STATE_EMPTY = "empty"

@export var hidden_die_count: int = 4
@export var tray_label_text: String = ""

var _last_key = ""
var _label: Label
var _faces: HBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_ensure_nodes()


func set_tray_label(text: String) -> void:
	tray_label_text = text
	_ensure_nodes()
	_label.text = tray_label_text
	_label.visible = not tray_label_text.is_empty()


func set_tray_dice(dice: Array, animate: bool = false) -> void:
	_ensure_nodes()
	var key = _dice_key(dice)
	var should_animate = animate and key != _last_key
	_last_key = key
	for child in _faces.get_children():
		_faces.remove_child(child)
		child.queue_free()
	if dice.is_empty():
		_add_hidden_faces(should_animate)
		return
	var index = 0
	for die in dice:
		var value = _die_value(die)
		var state = DIE_STATE_FACE if value >= 1 and value <= 6 else DIE_STATE_EMPTY
		_add_face(value, state, should_animate, index)
		index += 1


func _ensure_nodes() -> void:
	if _label == null:
		_label = Label.new()
		_label.name = "TrayLabel"
		_label.text = tray_label_text
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.custom_minimum_size = Vector2(34, 34)
		_label.add_theme_font_size_override("font_size", 15)
		_label.add_theme_color_override("font_color", UIAssets.COLOR_TEXT)
		_label.add_theme_stylebox_override("normal", UIAssets.inset_panel_style(Color("#172033"), UIAssets.COLOR_GOLD_DARK, 4))
		_label.visible = not tray_label_text.is_empty()
		add_child(_label)
	if _faces == null:
		_faces = HBoxContainer.new()
		_faces.name = "Faces"
		_faces.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_faces.alignment = BoxContainer.ALIGNMENT_CENTER
		_faces.add_theme_constant_override("separation", 8)
		add_child(_faces)


func _add_hidden_faces(animate: bool) -> void:
	var count = max(1, hidden_die_count)
	for index in range(count):
		_add_face(0, DIE_STATE_HIDDEN, animate, index)


func _add_face(value: int, state: String, animate: bool, index: int) -> void:
	var face = DieFaceScene.instantiate()
	_faces.add_child(face)
	face.set_die(value, state)
	if animate:
		face.play_snapshot_animation(float(index) * 0.025)


func _dice_key(dice: Array) -> String:
	if dice.is_empty():
		return "hidden:%d" % max(1, hidden_die_count)
	var parts = []
	for die in dice:
		parts.append(str(_die_value(die)))
	return ",".join(parts)


func _die_value(die) -> int:
	if typeof(die) == TYPE_INT or typeof(die) == TYPE_FLOAT:
		return int(die)
	var text = str(die)
	if text.is_valid_int():
		return int(text)
	return 0
