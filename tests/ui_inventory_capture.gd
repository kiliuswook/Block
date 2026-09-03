extends "res://tests/visual_capture.gd"
## UI 리뉴얼 인벤토리용 추가 캡처 — visual_capture.gd 가 안 찍는 화면들.
## (오버레이의 세로판 · 마일스톤 배너 · 스테이지 결과창 · 뽑기 결과 · DEV 치트 탭)
## 실행: godot --path E:\Game\Block res://tests/ui_inventory_capture.tscn


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await get_tree().process_frame
	var gold_before := GameState.gold
	var caps_before: Dictionary = GameState.keycaps.duplicate(true)
	# --- PC(가로 1920×1080) ---
	await _capture("res://core/scenes/title.tscn", OUT + "/title_ranks_alltime.png",
			func(inst: Node) -> void:
				inst._open_ranks()
				inst._rank_weekly = false
				inst._refresh_rank_list())
	GameState.gold = 9999
	await _capture("res://core/scenes/title.tscn", OUT + "/title_gacha_result.png",
			func(inst: Node) -> void:
				inst._open_gacha()
				inst._gacha_n[0] = GameState.KEYCAP_GACHA_MAX
				inst._on_gacha(0)
				inst._pull_t = 99.0
				inst._process(0.0)
				inst._gacha_tray.queue_redraw())
	GameState.gold = gold_before
	GameState.keycaps = caps_before
	GameState.save_game()
	await _capture("res://core/scenes/title.tscn", OUT + "/title_dev_cheats.png",
			func(inst: Node) -> void:
				if inst._dev:
					inst._dev.open()
					inst._dev._tab = 2
					inst._dev._rebuild())
	GameState.mode = GameState.MODE_ENDLESS
	await _capture("res://core/scenes/main.tscn", OUT + "/endless_milestone.png",
			func(inst: Node) -> void:
				EventBus.height_changed.emit(30)
				inst._show_milestone(30)
				inst._show_new_record())
	GameState.mode = GameState.MODE_CLASSIC
	await _capture("res://core/scenes/main.tscn", OUT + "/classic_pause.png",
			func(inst: Node) -> void: inst.settings_panel.open(false))
	await _capture("res://core/scenes/main.tscn", OUT + "/classic_death_popup.png",
			func(inst: Node) -> void:
				inst.get_node("Board")._kill_player()
				inst.get_node("PopupLayer/DeathPopup").open(
						"LEVEL 4      점수 12,300      최고 기록 18,900", false,
						"획득   +64 G", "",
						"경험치   +41",
						{"gold": 64, "gold_from": GameState.gold - 64,
						"xp": 41, "xp_from": maxi(GameState.xp - 41, 0)}))
	# --- 모바일(세로 1080×1920) --- (창 크기는 _fit_window가 맞춘다)
	const T := "res://mobile/ui/title_mobile.tscn"
	const M := "res://mobile/ui/main_mobile.tscn"
	await _capture(T, OUT + "/m_title_modes.png",
			func(inst: Node) -> void: inst._open_modes())
	await _capture(T, OUT + "/m_title_seat_pick.png",
			func(inst: Node) -> void: inst._open_chars(true))
	await _capture(T, OUT + "/m_title_char_cream.png",
			func(inst: Node) -> void: _view_cat(inst, "cream"))
	await _capture(T, OUT + "/m_title_char_locked.png",
			func(inst: Node) -> void: _view_cat(inst, "black"))
	await _capture(T, OUT + "/m_title_char_unique.png",
			func(inst: Node) -> void: _view_cat(inst, "wizard"))
	await _capture(T, OUT + "/m_title_char_feature.png",
			func(inst: Node) -> void:
				_view_cat(inst, "cream")
				inst._open_feature_ask())
	await _capture(T, OUT + "/m_title_mycat_buy.png",
			func(inst: Node) -> void:
				_view_cat(inst, "mycat")
				inst._customizer._cur = 5
				inst._customizer._refresh()
				inst._customizer._pick("eyes", 3))
	await _capture(T, OUT + "/m_title_gacha_pick.png",
			func(inst: Node) -> void:
				inst._open_gacha()
				inst._open_gacha_pick())
	await _capture(T, OUT + "/m_title_gacha_can.png",
			func(inst: Node) -> void:
				inst._open_gacha()
				inst._open_gacha_can())
	GameState.gold = 9999
	await _capture(T, OUT + "/m_title_gacha_pull.png",
			func(inst: Node) -> void:
				inst._open_gacha()
				inst._gacha_n[0] = GameState.KEYCAP_GACHA_MAX
				inst._on_gacha(0)
				inst._pull_t = 1.15
				inst._gacha_tray.queue_redraw())
	await _capture(T, OUT + "/m_title_gacha_result.png",
			func(inst: Node) -> void:
				inst._open_gacha()
				inst._gacha_n[0] = GameState.KEYCAP_GACHA_MAX
				inst._on_gacha(0)
				inst._pull_t = 99.0
				inst._process(0.0)
				inst._gacha_tray.queue_redraw())
	GameState.gold = gold_before
	GameState.keycaps = caps_before
	GameState.save_game()
	await _capture(T, OUT + "/m_unlock_char.png",
			func(inst: Node) -> void:
				inst._open_gacha()
				inst._unlock_queue.assign([{"cat": "wizard", "grade": 1}])
				inst._unlock_at = 0
				inst._open_unlock())
	await _capture(T, OUT + "/m_title_ranks.png",
			func(inst: Node) -> void: inst._open_ranks())
	await _capture(T, OUT + "/m_title_replay.png",
			func(inst: Node) -> void:
				var rep := {"v": 1, "mode": 1, "cat": "gray", "rows": 20, "level": 1,
					"frames": PackedInt32Array([
						320, 1216, 2, 0, 3, 14, 1, 1500,
						330, 1180, 2, 0, 3, 15, 1, 1498]),
					"events": [{"f": 0,
						"a": PackedInt32Array([0, 19, 0, 1, 19, 1, 2, 19, 2, 3, 19, 4]),
						"d": PackedInt32Array()}]}
				inst._replay_viewer.open(rep, "테스트냥  ·  42층")
				inst._replay_viewer.playing_back = false)
	await _capture(T, OUT + "/m_title_set_pad.png",
			func(inst: Node) -> void:
				inst._settings.open()
				inst._settings._show_page(inst._settings.PAGE_PAD))
	await _capture(T, OUT + "/m_title_set_keys.png",
			func(inst: Node) -> void:
				inst._settings.open()
				inst._settings._show_page(inst._settings.PAGE_KEYS))
	GameState.mode = GameState.MODE_ENDLESS
	await _capture(M, OUT + "/m_pause.png",
			func(inst: Node) -> void:
				inst.get_node("TouchControls").visible = true
				inst.settings_panel.open(false))
	await _capture(M, OUT + "/m_endless_milestone.png",
			func(inst: Node) -> void:
				inst.get_node("TouchControls").visible = true
				EventBus.height_changed.emit(30)
				inst._show_milestone(30)
				inst._show_new_record())
	await _capture(M, OUT + "/m_endless_lava.png",
			func(inst: Node) -> void:
				inst.get_node("TouchControls").visible = true
				inst.get_node("Board").lava_y = 940.0)
	GameState.mode = GameState.MODE_CLASSIC
	await _capture(M, OUT + "/m_classic_level5.png",
			func(inst: Node) -> void:
				inst.get_node("TouchControls").visible = true
				var b: Node = inst.get_node("Board")
				b._classic_setup_level(5)
				b.level_lines = 4
				b._spawn_piece()
				inst._on_classic_level_started(5, Board.classic_quota(5), b.level_garbage)
				inst._on_classic_level_progress(4, Board.classic_quota(5)))
	await _capture(M, OUT + "/m_classic_shutter.png",
			func(inst: Node) -> void:
				inst.get_node("TouchControls").visible = true
				var b: Node = inst.get_node("Board")
				b._classic_setup_level(4)
				b.level_lines = Board.classic_quota(4)
				for y in range(15, 20):
					for x in range(EscapeBoard.COLS):
						if (x + y) % 4 != 0:
							b.grid[Vector2i(x, y)] = Board.PIECES[(x + y) % 7]
				inst._on_classic_level_started(4, Board.classic_quota(4), b.level_garbage)
				b._classic_start_shutter()
				for i in range(12):
					b._update_shutter(1.0))
	await _capture(M, OUT + "/m_classic_death_popup.png",
			func(inst: Node) -> void:
				inst.get_node("Board")._kill_player()
				if inst.user_hud:
					inst.user_hud.visible = true
				inst.get_node("PopupLayer/DeathPopup").open(
						"LEVEL 4      점수 12,300      최고 기록 18,900", false,
						"획득   +64 G", "",
						"경험치   +41",
						{"gold": 64, "gold_from": GameState.gold - 64,
						"xp": 41, "xp_from": maxi(GameState.xp - 41, 0)}))
	get_tree().quit()
