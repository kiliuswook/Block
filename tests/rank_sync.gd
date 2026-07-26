extends Node
## Dev utility: boots the game long enough for Ranks.submit_all() to finish,
## then prints the shared board. Run:
## godot --headless --path . res://tests/rank_sync.tscn


func _ready() -> void:
	print("[rank_sync] online=%s url=%s" % [Ranks.online(), Ranks.BOARD_URL])
	await get_tree().create_timer(8.0).timeout
	await Ranks.refresh()
	for m: String in Ranks.MODES:
		var list := Ranks.entries(m)
		var tops: Array = []
		for e: Dictionary in list.slice(0, 3):
			tops.append("%s:%s%s" % [e.get("name"), e.get("v"),
					"+rep" if e.has("replay") else ""])
		print("[rank_sync] %s: %d entries  %s" % [m, list.size(), ", ".join(tops)])
	get_tree().quit()
