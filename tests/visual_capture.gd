extends Node
## Dev utility: boots each scene, waits a few frames, saves a screenshot.

const OUT := "E:/Game/Block/.tmp_shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await get_tree().process_frame
	await _capture("res://core/scenes/title.tscn", OUT + "/title.png")
	await _capture("res://core/scenes/title.tscn", OUT + "/title_popup.png",
			func(inst: Node) -> void: inst._open_popup(GameState.get_cat("black")))
	await _capture("res://core/scenes/title.tscn", OUT + "/title_popup_buy.png",
			func(inst: Node) -> void: inst._open_popup(GameState.get_cat("cheese")))
	# Max-affection looks (stage 3): aura, eye sparkles, floating heart.
	var saved_aff: Dictionary = GameState.affection.duplicate()
	GameState.affection = {"black": 25}
	await _capture("res://core/scenes/title.tscn", OUT + "/title_popup_aff.png",
			func(inst: Node) -> void: inst._open_popup(GameState.get_cat("black")))
	GameState.affection = saved_aff
	await _capture("res://core/scenes/title.tscn", OUT + "/title_modes.png",
			func(inst: Node) -> void: inst._open_modes())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_chars.png",
			func(inst: Node) -> void: inst._open_chars())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_settings.png",
			func(inst: Node) -> void: inst._settings.open())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_shop.png",
			func(inst: Node) -> void: inst._open_shop())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_ranks.png",
			func(inst: Node) -> void: inst._open_ranks())
	var saved_caps: Dictionary = GameState.keycaps.duplicate()
	GameState.keycaps = {"C": 3, "A": 1, "T": 12, "S": 2, "Q": 1, "E": 5, "N": 1, "G": 120}
	await _capture("res://core/scenes/title.tscn", OUT + "/title_keycaps.png",
			func(inst: Node) -> void: inst._open_keycap_dex())
	GameState.keycaps = saved_caps
	await _capture("res://core/scenes/title.tscn", OUT + "/title_popup_custom.png",
			func(inst: Node) -> void: inst._open_popup(GameState.get_cat("custom")))
	var saved_custom: Dictionary = GameState.custom_cat.duplicate()
	GameState.custom_cat = {"body": 8, "ear": 8, "eyes": 5, "eye_col": 4, "nose": 1,
			"mouth": 7, "whisker": 8, "pattern": 8, "pattern_col": 3, "tail": 9,
			"paws": 3, "blush": 4, "mark": 6, "extra": 3}
	await _capture("res://core/scenes/title.tscn", OUT + "/title_customizer.png",
			func(inst: Node) -> void: inst._customizer.open())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_customizer_eyes.png",
			func(inst: Node) -> void:
				inst._customizer._cur = 2  # 눈 탭 — 스타일 타일(미니 냥이) 확인용
				inst._customizer.open())
	GameState.custom_cat = saved_custom
	await _capture("res://core/scenes/title.tscn", OUT + "/title_replay.png",
			func(inst: Node) -> void:
				var rep := {"v": 1, "mode": 1, "cat": "mint", "rows": 20, "door": 0,
					"dl": false, "dr": false, "level": 1,
					"frames": PackedInt32Array([
						320, 1216, 2, 0, 3, 14, 1, 1500,
						330, 1180, 2, 0, 3, 15, 1, 1498]),
					"events": [{"f": 0,
						"a": PackedInt32Array([0, 19, 0, 1, 19, 1, 2, 19, 2, 3, 19, 4]),
						"d": PackedInt32Array()}]}
				inst._replay_viewer.open(rep, "테스트냥  ·  42층")
				inst._replay_viewer.playing_back = false)
	await _capture("res://steam/ui/title_steam.tscn", OUT + "/title_steam.png")
	var saved_story: int = GameState.story_stage
	GameState.mode = GameState.MODE_STORY
	GameState.story_stage = 0
	await _capture("res://core/scenes/main.tscn", OUT + "/story_intro.png")
	await _capture("res://core/scenes/main.tscn", OUT + "/story_stage1.png",
			func(inst: Node) -> void: inst._hide_story_intro())
	GameState.story_stage = 1
	await _capture("res://core/scenes/main.tscn", OUT + "/story_stage2.png",
			func(inst: Node) -> void: inst._hide_story_intro())
	GameState.story_stage = 5
	await _capture("res://core/scenes/main.tscn", OUT + "/story_stage6.png",
			func(inst: Node) -> void: inst._hide_story_intro())
	GameState.story_stage = saved_story
	GameState.mode = GameState.MODE_CLASSIC
	await _capture("res://core/scenes/main.tscn", OUT + "/classic.png")
	# In-game keycap block + collect popup (forced onto a prefilled floor row).
	await _capture("res://core/scenes/main.tscn", OUT + "/classic_keycap.png",
			func(inst: Node) -> void:
				var b: Node = inst.get_node("Board")
				for x in range(4):
					b.grid[Vector2i(x, 19)] = "J"
				b.keycaps[Vector2i(2, 19)] = "K"
				b.keycap_fx.append([Vector2(6.5 * 64.0, 16.0 * 64.0), 0.0, "M"])
				b.queue_redraw())
	# Level structure: a deep board with its garbage floor and a half-filled
	# LINES rack, then the clear shutter mid-descent with its bonus tally.
	await _capture("res://core/scenes/main.tscn", OUT + "/classic_level5.png",
			func(inst: Node) -> void:
				var b: Node = inst.get_node("Board")
				b._classic_setup_level(5)
				b.level_lines = 4
				b._spawn_piece()
				inst._on_classic_level_started(5, Board.classic_quota(5), b.level_garbage)
				inst._on_classic_level_progress(4, Board.classic_quota(5)))
	await _capture("res://core/scenes/main.tscn", OUT + "/classic_shutter.png",
			func(inst: Node) -> void:
				var b: Node = inst.get_node("Board")
				b._classic_setup_level(4)
				b.level_lines = Board.classic_quota(4)
				# A stack five rows deep: the curtain should stop right on it.
				for y in range(15, 20):
					for x in range(EscapeBoard.COLS):
						if (x + y) % 4 != 0:
							b.grid[Vector2i(x, y)] = Board.PIECES[(x + y) % 7]
				inst._on_classic_level_started(4, Board.classic_quota(4), b.level_garbage)
				b._classic_start_shutter()
				for i in range(12):
					b._update_shutter(1.0))
	# Gold: seams inside locked blocks, a nugget riding the live piece, and
	# loose nuggets lying on the stack waiting to be walked into.
	await _capture("res://core/scenes/main.tscn", OUT + "/classic_gold.png",
			func(inst: Node) -> void:
				var b: Node = inst.get_node("Board")
				for x in range(EscapeBoard.COLS):
					if x != 6:
						b.grid[Vector2i(x, 19)] = Board.PIECES[x % 7]
						if x % 3 == 0:
							b.grid[Vector2i(x, 18)] = Board.PIECES[(x + 2) % 7]
				b.ore[Vector2i(2, 19)] = EscapeBoard.ORE_VALUE
				b.ore[Vector2i(3, 18)] = EscapeBoard.ORE_VALUE
				b.piece_type = "T"
				b.piece_rot = 0
				b.piece_pos = Vector2i(4, 3)
				b.piece_state = b.PieceState.TRACKING
				b.piece_ore = 0
				b.rider = {"col": 2, "amount": EscapeBoard.RIDER_VALUE}
				b._spawn_nugget(Vector2(1.5 * 64.0, 17.0 * 64.0),
						EscapeBoard.RIDER_VALUE)
				b.gold_fx.append([Vector2(8.0 * 64.0, 17.0 * 64.0), 0.2, 8])
				b.queue_redraw())
	GameState.mode = GameState.MODE_PICNIC
	await _capture("res://core/scenes/main.tscn", OUT + "/picnic.png")
	GameState.mode = GameState.MODE_ENDLESS
	await _capture("res://core/scenes/main.tscn", OUT + "/endless.png")
	await _capture("res://core/scenes/main.tscn", OUT + "/endless_lava.png",
			func(inst: Node) -> void: inst.get_node("Board").lava_y = 940.0)
	await _capture("res://core/scenes/main.tscn", OUT + "/endless_hud.png",
			func(_inst: Node) -> void: EventBus.height_changed.emit(23))
	await _capture("res://core/scenes/main.tscn", OUT + "/pause_settings.png",
			func(inst: Node) -> void:
				inst.settings_panel.open(false))
	GameState.split = true
	GameState.mode = GameState.MODE_STORY
	await _capture("res://core/scenes/main.tscn", OUT + "/split_escape.png")
	GameState.mode = GameState.MODE_ENDLESS
	await _capture("res://core/scenes/main.tscn", OUT + "/split_endless.png")
	GameState.split = false
	GameState.mode = GameState.MODE_VERSUS
	await _capture("res://core/scenes/main.tscn", OUT + "/versus.png")
	await _capture("res://core/scenes/main.tscn", OUT + "/versus_round.png",
			func(inst: Node) -> void: inst.get_node("Board")._versus_over(1))
	GameState.mode = GameState.MODE_ENDLESS
	await _capture("res://core/scenes/main.tscn", OUT + "/death_popup.png",
			func(inst: Node) -> void:
				inst.get_node("Board")._kill_player()
				inst.get_node("PopupLayer/DeathPopup").open(
						"도달 높이 23층      최고 기록 41층", true,
						"획득   +87 G   +1 ◆", 2, true, false))
	GameState.mode = GameState.MODE_STORY
	await _capture("res://core/scenes/main.tscn", OUT + "/death_popup_skip.png",
			func(inst: Node) -> void:
				inst._hide_story_intro()
				inst.get_node("Board")._kill_player()
				inst.get_node("PopupLayer/DeathPopup").open(
						"STAGE 7      SCORE 4200", false, "", 1, false, true))
	GameState.mode = GameState.MODE_ENDLESS
	# --- 모바일(세로 1080×1920) 레이아웃 ---
	get_window().size = Vector2i(540, 960)
	get_window().content_scale_size = Vector2i(1080, 1920)
	GameState.split = false
	await _capture("res://mobile/ui/title_mobile.tscn", OUT + "/m_title.png")
	await _capture("res://mobile/ui/title_mobile.tscn", OUT + "/m_title_settings.png",
			func(inst: Node) -> void: inst._settings.open())
	await _capture("res://mobile/ui/title_mobile.tscn", OUT + "/m_title_shop.png",
			func(inst: Node) -> void: inst._open_shop())
	GameState.keycaps = {"C": 3, "A": 1, "T": 12, "S": 2, "Q": 1, "E": 5, "N": 1, "G": 120}
	await _capture("res://mobile/ui/title_mobile.tscn", OUT + "/m_title_keycaps.png",
			func(inst: Node) -> void: inst._open_keycap_dex())
	GameState.keycaps = saved_caps
	await _capture("res://mobile/ui/title_mobile.tscn", OUT + "/m_title_customizer.png",
			func(inst: Node) -> void: inst._customizer.open())
	GameState.mode = GameState.MODE_STORY
	GameState.story_stage = 0
	await _capture("res://mobile/ui/main_mobile.tscn", OUT + "/m_story_intro.png",
			func(inst: Node) -> void: inst.get_node("TouchControls").visible = true)
	await _capture("res://mobile/ui/main_mobile.tscn", OUT + "/m_story_stage1.png",
			func(inst: Node) -> void:
				inst.get_node("TouchControls").visible = true
				inst._hide_story_intro())
	GameState.story_stage = saved_story
	GameState.mode = GameState.MODE_ENDLESS
	await _capture("res://mobile/ui/main_mobile.tscn", OUT + "/m_endless.png",
			func(inst: Node) -> void: inst.get_node("TouchControls").visible = true)
	GameState.mode = GameState.MODE_CLASSIC
	await _capture("res://mobile/ui/main_mobile.tscn", OUT + "/m_classic.png",
			func(inst: Node) -> void: inst.get_node("TouchControls").visible = true)
	GameState.mode = GameState.MODE_PICNIC
	await _capture("res://mobile/ui/main_mobile.tscn", OUT + "/m_picnic.png",
			func(inst: Node) -> void: inst.get_node("TouchControls").visible = true)
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
