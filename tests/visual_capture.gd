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
	await _capture("res://core/scenes/title.tscn", OUT + "/title_modes.png",
			func(inst: Node) -> void: inst._open_modes())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_chars.png",
			func(inst: Node) -> void: inst._open_chars())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_modes_2p.png",
			func(inst: Node) -> void:
				inst._set_players(2)
				inst._open_modes())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_pick_1p.png",
			func(inst: Node) -> void:
				inst._set_players(1)
				inst._open_chars())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_pick_2p.png",
			func(inst: Node) -> void:
				inst._set_players(2)
				inst._open_chars())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_settings.png",
			func(inst: Node) -> void: inst._settings.open())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_set_pad.png",
			func(inst: Node) -> void:
				inst._settings.open()
				inst._settings._show_page(inst._settings.PAGE_PAD))
	await _capture("res://core/scenes/title.tscn", OUT + "/title_set_keys.png",
			func(inst: Node) -> void:
				inst._settings.open()
				inst._settings._show_page(inst._settings.PAGE_KEYS))
	await _capture("res://core/scenes/title.tscn", OUT + "/title_set_keys_2p.png",
			func(inst: Node) -> void:
				inst._settings.open()
				inst._settings._show_page(inst._settings.PAGE_KEYS)
				inst._settings._set_keys_tab(1))
	await _capture("res://core/scenes/title.tscn", OUT + "/title_gacha.png",
			func(inst: Node) -> void: inst._open_gacha())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_gacha_pick.png",
			func(inst: Node) -> void:
				inst._gacha_pick_mode = true
				inst._open_gacha())
	# 10연차 캡슐이 굴러 나오는 중간 프레임. 뽑기는 진짜 저장을 건드리므로
	# 지갑·키캡을 스냅샷 떠 두고 캡처가 끝나면 그대로 되돌린다.
	var gold_before := GameState.gold
	var caps_before: Dictionary = GameState.keycaps.duplicate(true)
	GameState.gold = 9999
	await _capture("res://core/scenes/title.tscn", OUT + "/title_gacha_pull.png",
			func(inst: Node) -> void:
				inst._open_gacha()
				inst._on_gacha(10)
				inst._pull_t = 1.15
				inst._gacha_tray.queue_redraw())
	GameState.gold = gold_before
	GameState.keycaps = caps_before
	GameState.save_game()
	await _capture("res://core/scenes/title.tscn", OUT + "/title_ranks.png",
			func(inst: Node) -> void: inst._open_ranks())
	var saved_caps: Dictionary = GameState.keycaps.duplicate()
	GameState.keycaps = _demo_keycaps()
	await _capture("res://core/scenes/title.tscn", OUT + "/title_keycaps.png",
			func(inst: Node) -> void: inst._open_keycap_dex("cheese"))
	GameState.keycaps = saved_caps
	await _capture("res://core/scenes/title.tscn", OUT + "/title_popup_custom.png",
			func(inst: Node) -> void: inst._open_popup(GameState.get_cat("cream")))
	# 나만의 캐릭터 (꾸미기는 이 슬롯 전용) — 슬롯 팝업 + 잠긴 파츠가 섞인 꾸미기 화면(눈 탭).
	await _capture("res://core/scenes/title.tscn", OUT + "/title_mycat_popup.png",
			func(inst: Node) -> void: inst._open_popup(GameState.get_cat("mycat")))
	await _capture("res://core/scenes/title.tscn", OUT + "/title_mycat_custom.png",
			func(inst: Node) -> void: inst._customizer.open("mycat"))
	await _capture("res://core/scenes/title.tscn", OUT + "/title_mycat_eyes.png",
			func(inst: Node) -> void:
				inst._customizer.open("mycat")
				inst._customizer._cur = 5  # 눈 칩 — 모양+색을 한 패널에서 확인
				inst._customizer._refresh()
				# 잠긴 파츠 미리보기 — 눈 3번(잠금)을 입혀 본 상태
				inst._customizer._pick("eyes", 3))
	await _capture("res://core/scenes/title.tscn", OUT + "/title_replay.png",
			func(inst: Node) -> void:
				var rep := {"v": 1, "mode": 1, "cat": "gray", "rows": 20, "door": 0,
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
	# 2P는 자기 자리(slot 2)의 냥이로 나온다 — 자리별 선택/커스터마이징 확인용.
	var saved_cat2: String = GameState.selected_cat2
	GameState.selected_cat2 = "black"
	GameState.mode = GameState.MODE_STORY
	await _capture("res://core/scenes/main.tscn", OUT + "/split_escape.png")
	GameState.mode = GameState.MODE_ENDLESS
	await _capture("res://core/scenes/main.tscn", OUT + "/split_endless.png")
	GameState.selected_cat2 = saved_cat2
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
						"획득   +87 G", "",
						"경험치   +56\n레벨 업!   Lv.7   +220 G"))
	GameState.mode = GameState.MODE_STORY
	await _capture("res://core/scenes/main.tscn", OUT + "/death_popup_skip.png",
			func(inst: Node) -> void:
				inst._hide_story_intro()
				inst.get_node("Board")._kill_player()
				inst.get_node("PopupLayer/DeathPopup").open(
						"STAGE 7      SCORE 4200", false, ""))
	GameState.mode = GameState.MODE_ENDLESS
	# --- 모바일(세로 1080×1920) 레이아웃 ---
	get_window().size = Vector2i(540, 960)
	get_window().content_scale_size = Vector2i(1080, 1920)
	GameState.split = false
	await _capture("res://mobile/ui/title_mobile.tscn", OUT + "/m_title.png")
	await _capture("res://mobile/ui/title_mobile.tscn", OUT + "/m_title_settings.png",
			func(inst: Node) -> void: inst._settings.open())
	await _capture("res://mobile/ui/title_mobile.tscn", OUT + "/m_title_gacha.png",
			func(inst: Node) -> void: inst._open_gacha())
	await _capture("res://mobile/ui/title_mobile.tscn", OUT + "/m_title_pick.png",
			func(inst: Node) -> void: inst._open_chars())
	GameState.keycaps = _demo_keycaps()
	await _capture("res://mobile/ui/title_mobile.tscn", OUT + "/m_title_keycaps.png",
			func(inst: Node) -> void: inst._open_keycap_dex("cheese"))
	GameState.keycaps = saved_caps
	await _capture("res://mobile/ui/title_mobile.tscn", OUT + "/m_title_customizer.png",
			func(inst: Node) -> void: inst._customizer.open("mycat"))
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


## 캡처용 더미 수집 상태: 냥이마다 다른 진행도 (일부는 해금, 일부는 잠김).
func _demo_keycaps() -> Dictionary:
	var out := {}
	for i in GameState.CATS.size():
		var d := {}
		# 0번은 전체 2바퀴, 뒤로 갈수록 적게 — 도감/등급 표시를 한눈에 본다.
		var letters := maxi(3, 26 - i * 5)
		for j in letters:
			d[char(65 + j)] = 2 if i == 0 else 1
		out[str(GameState.CATS[i].id)] = d
	return out
