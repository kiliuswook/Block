extends Node
## Dev utility: boots each scene, waits a few frames, saves a screenshot.

const OUT := "E:/Game/Block/.tmp_shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await get_tree().process_frame
	await _capture("res://scenes/title.tscn", OUT + "/title.png")
	GameState.mode = GameState.MODE_ESCAPE
	await _capture("res://scenes/main.tscn", OUT + "/escape.png")
	GameState.mode = GameState.MODE_ENDLESS
	await _capture("res://scenes/main.tscn", OUT + "/endless.png")
	await _capture("res://scenes/main.tscn", OUT + "/endless_lava.png",
			func(inst: Node) -> void: inst.get_node("Board").lava_y = 940.0)
	await _capture("res://scenes/main.tscn", OUT + "/endless_hud.png",
			func(_inst: Node) -> void: EventBus.height_changed.emit(23))
	GameState.split = true
	GameState.mode = GameState.MODE_ESCAPE
	await _capture("res://scenes/main.tscn", OUT + "/split_escape.png")
	GameState.mode = GameState.MODE_ENDLESS
	await _capture("res://scenes/main.tscn", OUT + "/split_endless.png")
	GameState.split = false
	GameState.mode = GameState.MODE_VERSUS
	await _capture("res://scenes/main.tscn", OUT + "/versus.png")
	await _capture("res://scenes/main.tscn", OUT + "/versus_round.png",
			func(inst: Node) -> void: inst.get_node("Board")._versus_over(1))
	GameState.mode = GameState.MODE_ENDLESS
	await _capture("res://scenes/main.tscn", OUT + "/death_popup.png",
			func(inst: Node) -> void:
				inst.get_node("Board")._kill_player()
				inst.get_node("PopupLayer/DeathPopup").open(
						"도달 높이 23층      최고 기록 41층", true))
	get_tree().quit()


func _capture(scene_path: String, out: String, setup: Callable = Callable()) -> void:
	var inst: Node = (load(scene_path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	if setup.is_valid():
		setup.call(inst)
	for i in range(40):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	inst.queue_free()
	await get_tree().process_frame
