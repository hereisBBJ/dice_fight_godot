extends Control
class_name MenuScreen

signal start_local_requested
signal host_requested
signal join_requested(ip: String)

@onready var status_label: Label = $Margin/Column/StatusPanel/Margin/Column/Status
@onready var ip_input: LineEdit = $Margin/Column/StatusPanel/Margin/Column/JoinRow/IpInput
@onready var local_button: Button = $Margin/Column/StatusPanel/Margin/Column/LocalButton
@onready var host_button: Button = $Margin/Column/StatusPanel/Margin/Column/HostButton
@onready var join_button: Button = $Margin/Column/StatusPanel/Margin/Column/JoinRow/JoinButton


func _ready() -> void:
	local_button.pressed.connect(_on_local_button_pressed)
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)


func setup(status_message: String, default_ip: String, port: int) -> void:
	status_label.text = "状态：%s" % status_message
	ip_input.text = default_ip
	host_button.text = "创建 LAN 房间（端口 %d）" % port


func _on_local_button_pressed() -> void:
	start_local_requested.emit()


func _on_host_button_pressed() -> void:
	host_requested.emit()


func _on_join_button_pressed() -> void:
	var address = ip_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	join_requested.emit(address)
