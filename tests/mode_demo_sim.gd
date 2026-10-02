extends Node
## 모드 선택 데모 시뮬레이션 점검 — 헤드리스로 돌려 판이 멈추거나 너무 자주 새로 시작하지 않는지 본다.

const MODE_DEMO := preload("res://core/scripts/mode_demo.gd")


func _ready() -> void:
	var ok := true
	for mode in [GameState.MODE_CLASSIC, GameState.MODE_ENDLESS]:
		for sz in [Vector2(540, 690), Vector2(600, 560)]:
			var d: Control = MODE_DEMO.new()
			d.mode = mode
			d.size = sz
			add_child(d)
			var resets := 0
			var peak := 0.0
			var pieces := 0
			var last_pt := ""
			for i in 3600:  # 60초
				var before: int = d._grid.size()
				d._process(1.0 / 60.0)
				if d._pt != "" and last_pt == "":
					pieces += 1
				last_pt = d._pt
				if d._grid.is_empty() and before > 4:
					resets += 1
				peak = maxf(peak, d._rows - d._cy)
			print("mode %d %s: pieces %d resets %d peak %.1f cat (%.1f, %.1f)" % [mode, sz, pieces, resets, peak, d._cx, d._cy])
			if pieces < 15:
				ok = false
			d.queue_free()
	print("ALL TESTS PASSED" if ok else "FAILED")
	get_tree().quit()
