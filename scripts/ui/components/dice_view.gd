extends HBoxContainer
class_name DiceView

var _last_text = ""


func set_dice(dice: Array, animate: bool = false) -> void:
	var text = ",".join(_dice_parts(dice))
	var should_animate = animate and text != _last_text
	_last_text = text
	for child in get_children():
		child.queue_free()
	if dice.is_empty():
		var empty = _make_die_label("-")
		empty.modulate = Color(0.58, 0.61, 0.68)
		add_child(empty)
		return
	for die in dice:
		var label = _make_die_label(str(int(die)))
		add_child(label)
		if should_animate:
			label.scale = Vector2(0.84, 0.84)
			var tween = create_tween()
			tween.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _dice_parts(dice: Array) -> Array:
	var parts = []
	for die in dice:
		parts.append(str(int(die)))
	return parts


func _make_die_label(value: String) -> Label:
	var label = Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(46, 46)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_stylebox_override("normal", UIAssets.panel_style(Color(0.91, 0.92, 0.88), Color(0.18, 0.19, 0.22), 6))
	label.add_theme_color_override("font_color", Color(0.11, 0.12, 0.14))
	return label
