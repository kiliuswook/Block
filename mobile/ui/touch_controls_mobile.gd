extends "res://core/scripts/touch_controls.gd"
## 모바일 터치: 방향 4키(◀ ▶ ▲ ▼)만 쓰고, 버튼 밖 빈 공간을 탭하면 블록 회전.
## 화면 왼쪽 절반 탭 = 반시계(↺), 오른쪽 절반 = 시계(↻).
## 버튼과 같은 방식(누르는 동안 액션 유지)으로 멀티터치와 공존한다.

const BootScript := preload("res://core/scripts/boot.gd")

var _rot_touches := {}  # touch index -> action name


func _ready() -> void:
	if OS.has_feature("mobile"):
		super()  # 실제 모바일 빌드: 항상 표시
		return
	# 데스크톱 에뮬레이션: F6 직접 실행이면 세로 창 보정, 터치 UI는 강제 표시
	if get_window().content_scale_size.x > get_window().content_scale_size.y:
		BootScript.apply_mobile_dev_window(get_window())
	BootScript.dev_platform = "mobile"  # 타이틀 복귀 시에도 모바일 유지
	visible = true


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _over_button(event.position):
				return
			var action := "rotate_ccw" if event.position.x < _half_x() else "rotate_cw"
			_rot_touches[event.index] = action
			Input.action_press(action)
		elif _rot_touches.has(event.index):
			Input.action_release(_rot_touches[event.index])
			_rot_touches.erase(event.index)


func _half_x() -> float:
	return get_viewport().get_visible_rect().size.x / 2.0


func _over_button(pos: Vector2) -> bool:
	for c in get_children():
		if c is Control and c.visible and (c as Control).get_global_rect().has_point(pos):
			return true
	return false
