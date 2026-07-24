extends CanvasLayer
## Virtual gamepad overlay: shown only on devices with a touchscreen.


func _ready() -> void:
	visible = DisplayServer.is_touchscreen_available()
