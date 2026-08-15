extends "res://core/scripts/title.gd"
## 스팀(데스크톱) 타이틀 — core 타이틀을 상속하고 데스크톱 요소만 더한다:
## 키보드 힌트, Esc·버튼으로 게임 종료.


func _ready() -> void:
	super()
	preload("res://core/scripts/boot.gd").dev_platform = "steam"  # 타이틀 복귀 시에도 유지
	_add_quit_button()


## 열려 있는 오버레이가 하나라도 있으면 Esc는 "닫기"로 쓰인다.
func _any_overlay_open() -> bool:
	for c: Control in [_popup, _modes, _chars, _shop, _ranks, _keycap_dex,
			_customizer, _replay_viewer]:
		if c != null and c.visible:
			return true
	return _settings_open()


func _unhandled_input(event: InputEvent) -> void:
	# 오버레이가 모두 닫혀 있을 때만 Esc가 게임 종료 (열려 있으면 base가 닫는다).
	if not _any_overlay_open() and event is InputEventKey \
			and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_tree().quit()
		return
	super(event)


func _add_quit_button() -> void:
	var b := Button.new()
	b.text = "종료"
	b.size = Vector2(140.0, 60.0)
	b.position = Vector2(vw - 170.0, vh - 90.0)
	UiKit.btn_card(b, UiKit.RED_DEEP, 24)
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		get_tree().quit())
	$UI.add_child(b)
