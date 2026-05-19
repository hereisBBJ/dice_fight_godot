extends Node
class_name AudioFeedback

@export var click_stream: AudioStream
@export var dice_stream: AudioStream
@export var skill_stream: AudioStream
@export var hit_stream: AudioStream
@export var shield_stream: AudioStream
@export var heal_stream: AudioStream
@export var status_stream: AudioStream
@export var win_stream: AudioStream
@export var lose_stream: AudioStream

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)


func play_event(event_name: String) -> void:
	var stream = _stream_for_event(event_name)
	if stream == null:
		return
	_player.stream = stream
	_player.play()


func _stream_for_event(event_name: String) -> AudioStream:
	match event_name:
		"click":
			return click_stream
		"dice":
			return dice_stream
		"skill":
			return skill_stream
		"hit":
			return hit_stream
		"shield":
			return shield_stream
		"heal":
			return heal_stream
		"status":
			return status_stream
		"win":
			return win_stream
		"lose":
			return lose_stream
	return null
