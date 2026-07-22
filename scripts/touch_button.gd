class_name TouchButton
extends Control
## On-screen button that presses/releases an input action. Tracks its own
## touch index so several buttons work at once (multitouch), and lets a
## finger slide off to release or slide on to press.

@export var action := ""
@export var label := ""
@export var font_size := 48

var touch_index := -1


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1 and get_global_rect().has_point(event.position):
			_press(event.index)
		elif not event.pressed and event.index == touch_index:
			_release()
	elif event is InputEventScreenDrag:
		var inside := get_global_rect().has_point(event.position)
		if event.index == touch_index and not inside:
			_release()
		elif touch_index == -1 and inside:
			_press(event.index)


func _press(index: int) -> void:
	touch_index = index
	Input.action_press(action)
	queue_redraw()


func _release() -> void:
	touch_index = -1
	Input.action_release(action)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_EXIT_TREE:
		if touch_index != -1:
			_release()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg_alpha := 0.3 if touch_index != -1 else 0.12
	draw_rect(r, Color(1, 1, 1, bg_alpha))
	draw_rect(r, Color(1, 1, 1, 0.4), false, 2.0)
	var font := ThemeDB.fallback_font
	var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := Vector2((size.x - ts.x) / 2.0, (size.y + ts.y * 0.55) / 2.0)
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.85))
