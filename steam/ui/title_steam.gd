extends "res://core/scripts/title.gd"
## 스팀(데스크톱) 타이틀 — core 타이틀을 상속하고 데스크톱 요소만 더한다:
## 키보드 중심 힌트, Esc·버튼으로 게임 종료.


func _ready() -> void:
	super()
	$UI/HintLabel.text = "버튼 클릭  또는  1 ~ 5 키로 선택   (4 · 5 = 화면 분할 2인,  Esc = 종료)"
	_add_quit_button()


func _unhandled_input(event: InputEvent) -> void:
	# 팝업이 닫혀 있을 때 Esc는 게임 종료 (팝업이 열려 있으면 base가 닫기로 처리).
	if (_popup == null or not _popup.visible) and event is InputEventKey \
			and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_tree().quit()
		return
	super(event)


func _add_quit_button() -> void:
	var b := Button.new()
	b.text = "종료"
	b.position = Vector2(1756.0, 986.0)
	b.size = Vector2(124.0, 54.0)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func() -> void: get_tree().quit())
	$UI.add_child(b)
