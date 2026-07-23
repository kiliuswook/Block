extends Node
## Global game state: score, progress, save/load.

const SAVE_PATH := "user://save.json"

const MODE_ESCAPE := 0
const MODE_ENDLESS := 1

var mode: int = MODE_ESCAPE
var best_height: int = 0

var score: int = 0:
	set(value):
		score = value
		EventBus.score_changed.emit(score)


func _ready() -> void:
	load_game()


func reset() -> void:
	score = 0


## Records a finished endless run. Returns true if it set a new all-time best.
func record_height(h: int) -> bool:
	if h <= best_height:
		return false
	best_height = h
	save_game()
	return true


func save_game() -> void:
	var data := {"score": score, "best_height": best_height}
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
		best_height = int(data.get("best_height", 0))
