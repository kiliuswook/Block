extends Node
## 터치 컨트롤 회귀 테스트: 화면 터치 → 액션 상태 → 게임 반응.
## 이동 패드 슬라이드(왼→오른), 멀티터치(이동 + 점프), 일시정지 버튼(⏸ → 설정 패널).

var _fails := 0


func _ready() -> void:
	await get_tree().process_frame
	GameState.mode = GameState.MODE_ENDLESS
	var inst: Node = (load("res://mobile/ui/main_mobile.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	var tc: CanvasLayer = inst.get_node("TouchControls")
	tc.visible = true
	await _frames(3)
	var pad: Control = tc.get_node("MovePad")
	var jump: Control = tc.get_node("JumpButton")
	var pause: Control = tc.get_node("MenuButton")
	var pr := pad.get_global_rect()
	# 왼쪽 반 누르기
	_touch(0, true, pr.position + Vector2(pr.size.x * 0.25, pr.size.y * 0.5))
	await _frames(2)
	_check("pad left pressed", Input.is_action_pressed("move_left"))
	_check("pad right not pressed", not Input.is_action_pressed("move_right"))
	# 떼지 않고 오른쪽 반으로 미끄러지기
	_drag(0, pr.position + Vector2(pr.size.x * 0.75, pr.size.y * 0.5))
	await _frames(2)
	_check("slide releases left", not Input.is_action_pressed("move_left"))
	_check("slide presses right", Input.is_action_pressed("move_right"))
	# 패드 밖으로 흘러도 붙잡는다
	_drag(0, pr.position + Vector2(pr.size.x * 0.75, pr.size.y + 120.0))
	await _frames(2)
	_check("drift outside keeps right", Input.is_action_pressed("move_right"))
	# 두 번째 손가락으로 점프 (멀티터치)
	_touch(1, true, jump.get_global_rect().get_center())
	await _frames(2)
	_check("jump pressed with pad held", Input.is_action_pressed("jump"))
	_check("pad still held", Input.is_action_pressed("move_right"))
	_check("jump button tracks finger", jump.touch_index == 1)
	_touch(1, false, jump.get_global_rect().get_center())
	_touch(0, false, pr.position)
	await _frames(2)
	_check("all released", not Input.is_action_pressed("jump") and not Input.is_action_pressed("move_right"))
	# 원형 버튼: 모서리 바깥은 안 눌린다
	_touch(2, true, jump.get_global_rect().position + Vector2(4.0, 4.0))
	await _frames(2)
	_check("circle corner misses", jump.touch_index == -1)
	_touch(2, false, jump.get_global_rect().position)
	await _frames(2)
	# ⏸ → 일시정지 패널
	_touch(3, true, pause.get_global_rect().get_center())
	await _frames(2)
	_touch(3, false, pause.get_global_rect().get_center())
	await _frames(2)
	_check("pause opens settings", inst.get_node("Board").is_paused and inst.settings_panel.visible)
	_check("pause panel shows quit", inst.settings_panel._quit_btn.visible)
	if _fails == 0:
		print("ALL TESTS PASSED")
	else:
		print("FAILED: %d" % _fails)
	get_tree().quit()


func _touch(idx: int, pressed: bool, at: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.pressed = pressed
	ev.position = at
	get_viewport().push_input(ev, true)


func _drag(idx: int, at: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = idx
	ev.position = at
	get_viewport().push_input(ev, true)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(name: String, ok: bool) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + name)
	if not ok:
		_fails += 1
