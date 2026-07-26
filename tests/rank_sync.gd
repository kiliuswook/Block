extends Node
## Dev utility: boots the game long enough for Ranks.submit_all() to finish,
## then prints the shared board. Run:
## godot --headless --path . res://tests/rank_sync.tscn


func _ready() -> void:
	print("[rank_sync] online=%s url=%s" % [Ranks.online(), Ranks.BOARD_URL])
	await get_tree().create_timer(8.0).timeout
	await Ranks.refresh()
	print("[rank_sync] week=%d remaining=%s" % [Ranks.week_id(), Ranks.week_remaining_text()])
	for weekly: bool in [false, true]:
		for m: String in Ranks.MODES:
			var list := Ranks.entries(m, weekly)
			var tops: Array = []
			for e: Dictionary in list.slice(0, 3):
				tops.append("%s:%s%s" % [e.get("name"), e.get("v"),
						"+rep" if e.has("replay") else ""])
			print("[rank_sync] %s%s: %d entries  %s" \
					% ["wk_" if weekly else "", m, list.size(), ", ".join(tops)])
	get_tree().quit()
