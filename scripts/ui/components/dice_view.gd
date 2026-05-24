extends HBoxContainer
class_name DiceView

const DiceTrayScene = preload("res://scenes/ui/components/dice_tray.tscn")

var _tray = null


func _ready() -> void:
	_ensure_tray()


func set_dice(dice: Array, animate: bool = false) -> void:
	_ensure_tray()
	_tray.set_tray_dice(dice, animate)


func _ensure_tray() -> void:
	if _tray != null:
		return
	add_theme_constant_override("separation", 0)
	_tray = DiceTrayScene.instantiate()
	_tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_tray)
