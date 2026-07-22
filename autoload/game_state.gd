extends Node
## Global game state: score, progress, save/load.

const SAVE_PATH := "user://save.json"

const MODE_ESCAPE := 0
const MODE_ENDLESS := 1

var mode: int = MODE_ESCAPE

var score: int = 0:
	set(value):
		score = value
		EventBus.score_changed.emit(score)


func reset() -> void:
	score = 0


func save_game() -> void:
	var data := {"score": score}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		score = int(data.get("score", 0))
