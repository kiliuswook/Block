extends CanvasLayer
## Virtual gamepad overlay: shown only on devices with a touchscreen.


func _ready() -> void:
	# 모바일 빌드는 항상 표시, 그 외(웹 등)는 터치스크린이 있을 때만.
	visible = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
