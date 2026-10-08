extends Node
## 풍선 점프 캡처: 실제 입력 경로(점프 → 공중에서 다시 점프 연타)로 고양이를 띄우고 찍는다.
## Run: godot --path . res://tests/float_capture.tscn  →  .tmp_shots/classic_float.png

const OUT := "res://.tmp_shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	GameState.mode = GameState.MODE_CLASSIC
	var inst: Node = (load("res://core/scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(inst)
	for i in range(30):
		await get_tree().physics_frame
	var player: Player = inst.get_node("Board/Player")
	var floor_y := player.position.y
	await _tap(8)  # 바닥 점프
	for i in range(4):
		await _tap(10)  # 공중에서 연타
	var ok := player.floating and player.position.y < floor_y - 100.0
	print("float via input: floating=%s rise=%.0fpx" % [player.floating, floor_y - player.position.y])
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OUT + "/classic_float.png")
	print("ALL TESTS PASSED" if ok else "FAILED")
	get_tree().quit(0 if ok else 1)


func _tap(frames: int) -> void:
	_jump(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_jump(false)
	for i in range(frames):
		await get_tree().physics_frame


func _jump(pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = "jump"
	ev.pressed = pressed
	Input.parse_input_event(ev)
