extends "res://core/scripts/touch_controls.gd"
## 모바일 터치 오버레이. 회전은 전용 버튼(◀회전 · 회전▶)으로만 —
## 빈 곳 탭 회전은 오조작이 잦아 제거했다.

const BootScript := preload("res://core/scripts/boot.gd")


func _ready() -> void:
	if OS.has_feature("mobile"):
		super()  # 실제 모바일 빌드: 항상 표시
		return
	# 데스크톱 에뮬레이션: F6 직접 실행이면 세로 창 보정, 터치 UI는 강제 표시
	if get_window().content_scale_size.x > get_window().content_scale_size.y:
		BootScript.apply_mobile_dev_window(get_window())
	BootScript.dev_platform = "mobile"  # 타이틀 복귀 시에도 모바일 유지
	visible = true
