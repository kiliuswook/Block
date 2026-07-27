extends "res://core/scripts/title.gd"
## 모바일 타이틀 — core 타이틀을 상속, 세로 화면(1080×1920) 레이아웃.
## 한 키보드가 필요한 2P 모드(대전·화면 분할)는 모바일에 없다.


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
	for n in ["VersusBtn", "VersusDesc", "Escape2Btn", "Endless2Btn"]:
		get_node("UI/" + n).visible = false
	_place($UI/TitleLabel, 40.0, 200.0, 1000.0, 160.0)
	_place($UI/SubtitleLabel, 40.0, 370.0, 1000.0, 50.0)
	_big_button(escape_btn, $UI/EscapeDesc, 470.0)
	_big_button(picnic_btn, $UI/PicnicDesc, 650.0)  # 라이트 유저 최우선 노출
	_big_button(endless_btn, $UI/EndlessDesc, 830.0)
	_big_button(classic_btn, $UI/ClassicDesc, 1010.0)
	# 터치 전용 화면에는 키보드 번호가 의미 없다 — "1. " 접두사 제거.
	for b: Button in [escape_btn, picnic_btn, endless_btn, classic_btn]:
		var dot := b.text.find(".")
		if dot > 0:
			b.text = b.text.substr(dot + 1).strip_edges()
	var hint: Label = $UI/HintLabel
	_place(hint, 40.0, vh - 90.0, 1000.0, 40.0)
	hint.text = "모드를 터치해서 시작!"


func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)


## 모드 버튼을 터치 타깃 크기(600×110)로 키워 중앙 배치, 설명은 바로 아래.
func _big_button(btn: Button, desc: Label, y: float) -> void:
	_place(btn, (vw - 600.0) / 2.0, y, 600.0, 110.0)
	btn.add_theme_font_size_override("font_size", 40)
	_place(desc, (vw - 600.0) / 2.0, y + 114.0, 600.0, 30.0)
