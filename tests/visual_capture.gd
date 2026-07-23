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
	get_tree().quit()


func _capture(scene_path: String, out: String) -> void:
	var inst: Node = (load(scene_path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	for i in range(40):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	inst.queue_free()
	await get_tree().process_frame
