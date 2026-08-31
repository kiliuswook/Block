extends "res://core/scripts/title.gd"
## 모바일 타이틀 — core 타이틀을 상속, 세로 화면(1080×1920) 레이아웃.
## 로고·메뉴·오버레이 배치는 core가 화면 비율로 알아서 계산한다.


const BootScript := preload("res://core/scripts/boot.gd")


func _ready() -> void:
	# F6로 이 씬을 직접 실행해도 세로 창이 되도록 (boot을 거치면 이미 세로 상태)
	if not OS.has_feature("mobile") \
			and get_window().content_scale_size.x > get_window().content_scale_size.y:
		BootScript.apply_mobile_dev_window(get_window())
	max_tiles_per_row = 5  # 캐릭터 타일을 5+4 두 줄로
	main_scene = "res://mobile/ui/main_mobile.tscn"
	super()
	BootScript.dev_platform = "mobile"  # 타이틀 복귀 시에도 모바일 유지
	# 터치 전용 화면에는 키보드 번호가 의미 없다 — "1. " 접두사 제거.
	for b: Button in [classic_btn, endless_btn]:
		var dot := b.text.find(".")
		if dot > 0:
			b.text = b.text.substr(dot + 1).strip_edges()
