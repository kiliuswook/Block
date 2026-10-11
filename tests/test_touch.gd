extends Node
## 터치 컨트롤 회귀 테스트: 화면 터치 → 액션 상태 → 게임 반응.
## 이동 패드 슬라이드(왼→오른), 멀티터치(이동 + 점프), 일시정지 버튼(⏸ → 설정 패널).

var _fails := 0


func _ready() -> void:
	await get_tree().process_frame
	GameState.mode = GameState.MODE_ENDLESS
	var saved_ctl: int = GameState.control_mode
	GameState.control_mode = GameState.CONTROL_CLASSIC  # 아래는 기본 조작의 버튼 배치
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
	_check("pause panel shows quit", inst.settings_panel._pause_quit.visible)
	inst.queue_free()
	await _frames(2)
	# 두 버튼 조작: 좌우 패드만 남고 덱 폭만큼 넓어진다. 숨은 버튼은 터치를 안 받는다.
	GameState.control_mode = GameState.CONTROL_SIMPLE
	var s_inst: Node = (load("res://mobile/ui/main_mobile.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(s_inst)
	var stc: CanvasLayer = s_inst.get_node("TouchControls")
	stc.visible = true
	await _frames(3)
	var spad: Control = stc.get_node("MovePad")
	var sjump: Control = stc.get_node("JumpButton")
	var vw: float = s_inst.get_viewport_rect().size.x
	_check("simple: action buttons hidden", not sjump.visible
			and not stc.get_node("RotateButton").visible and not stc.get_node("DropButton").visible)
	_check("simple: pad spans the deck", spad.size.x >= vw - 100.0)
	_touch(4, true, sjump.get_global_rect().get_center())
	await _frames(2)
	_check("simple: hidden jump ignores touches", not Input.is_action_pressed("jump"))
	_touch(4, false, sjump.get_global_rect().get_center())
	var spr := spad.get_global_rect()
	_touch(5, true, spr.position + Vector2(spr.size.x * 0.9, spr.size.y * 0.5))
	await _frames(2)
	_check("simple: right half moves right", Input.is_action_pressed("move_right"))
	_touch(5, false, spr.position)
	await _frames(2)
	GameState.control_mode = saved_ctl
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
