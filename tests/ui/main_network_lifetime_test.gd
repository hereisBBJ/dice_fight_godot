extends SceneTree

const MainScene = preload("res://scenes/main/main.tscn")

var failures: Array = []


func _init() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	var network = main.network_controller
	_expect(is_instance_valid(network), "network controller should exist after first render")

	main._render()
	await process_frame
	_expect(is_instance_valid(network), "network controller should survive rerender")
	_expect(main.network_controller == network, "main should keep the same network controller instance")

	if failures.is_empty():
		print("MAIN_NETWORK_LIFETIME_TEST_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(str(failure))
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
