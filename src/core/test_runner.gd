# res://src/core/test_runner.gd
# GDScript / test_runner.gd / Godot 4.7 / headless
extends SceneTree

func _init() -> void:
	print("Hello from SceneTree headless test!")
	quit(0)
