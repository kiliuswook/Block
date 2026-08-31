extends Node
## Dev utility: boots each scene, waits a few frames, saves a screenshot.

const OUT := "E:/Game/Block/.tmp_shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await get_tree().process_frame
	await _capture("res://core/scenes/title.tscn", OUT + "/title.png")
	await _capture("res://core/scenes/title.tscn", OUT + "/title_char_locked.png",
			func(inst: Node) -> void: _view_cat(inst, "black"))
	await _capture("res://core/scenes/title.tscn", OUT + "/title_modes.png",
			func(inst: Node) -> void: inst._open_modes())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_chars.png",
			func(inst: Node) -> void: inst._open_chars())
	# 타이틀 무대 = 좌석. 이번 판에 나갈 냥이가 여기 선다.
	await _capture("res://core/scenes/title.tscn", OUT + "/title_seat.png",
			func(inst: Node) -> void: inst._refresh_seats())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_pick.png",
			func(inst: Node) -> void: inst._open_chars(true))
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
	await _capture("res://core/scenes/title.tscn", OUT + "/title_gacha.png",
			func(inst: Node) -> void: inst._open_gacha())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_gacha_pick.png",
			func(inst: Node) -> void:
				inst._open_gacha()
				inst._open_gacha_pick())
	# 10연차 캡슐이 굴러 나오는 중간 프레임. 뽑기는 진짜 저장을 건드리므로
	# 지갑·키캡을 스냅샷 떠 두고 캡처가 끝나면 그대로 되돌린다.
	var gold_before := GameState.gold
	var caps_before: Dictionary = GameState.keycaps.duplicate(true)
	GameState.gold = 9999
	await _capture("res://core/scenes/title.tscn", OUT + "/title_gacha_pull.png",
			func(inst: Node) -> void:
				inst._open_gacha()
				inst._gacha_n[0] = GameState.KEYCAP_GACHA_MAX
				inst._on_gacha(0)
				inst._pull_t = 1.15
				inst._gacha_tray.queue_redraw())
	GameState.gold = gold_before
	GameState.keycaps = caps_before
	GameState.save_game()
	await _capture("res://core/scenes/title.tscn", OUT + "/title_ranks.png",
			func(inst: Node) -> void: inst._open_ranks())
	# [개발용 · 출시 빌드에서 제거] 업적/리더보드 확인 패널.
	await _capture("res://core/scenes/title.tscn", OUT + "/title_dev_achv.png",
			func(inst: Node) -> void:
				if inst._dev:
					inst._dev.open())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_dev_boards.png",
			func(inst: Node) -> void:
				if inst._dev:
					inst._dev.open()
					inst._dev._tab = 1
					inst._dev._rebuild())
	var saved_caps: Dictionary = GameState.keycaps.duplicate()
	GameState.keycaps = _demo_keycaps()
	await _capture("res://core/scenes/title.tscn", OUT + "/title_keycaps.png",
			func(inst: Node) -> void: inst._open_keycap_dex("cheese"))
	# 보상 열: 등급별로 그 단계 파츠를 입은 모습이 칩마다 달라야 한다.
	await _capture("res://core/scenes/title.tscn", OUT + "/title_char_rewards.png",
			func(inst: Node) -> void: _view_cat(inst, "cream"))
	GameState.keycaps = saved_caps
	await _capture("res://core/scenes/title.tscn", OUT + "/title_char_cream.png",
			func(inst: Node) -> void: _view_cat(inst, "cream"))
	await _capture("res://core/scenes/title.tscn", OUT + "/title_char_feature.png",
			func(inst: Node) -> void:
				_view_cat(inst, "cream")
				inst._open_feature_ask())
	# 나만의 캐릭터 (꾸미기는 이 슬롯 전용) — 카드 안 꾸미기 패널 + 잠긴 파츠(눈 줄).
	await _capture("res://core/scenes/title.tscn", OUT + "/title_char_mycat.png",
			func(inst: Node) -> void: _view_cat(inst, "mycat"))
	await _capture("res://core/scenes/title.tscn", OUT + "/title_mycat_eyes.png",
			func(inst: Node) -> void:
				_view_cat(inst, "mycat")
				inst._customizer._cur = 5  # 눈 줄 — 모양+색을 한 패널에서 확인
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
			func(inst: Node) -> void: _view_cat(inst, "mycat"))
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


## 캐릭터 페이지를 열고 그 냥이를 본문에 펼친다.
func _view_cat(inst: Node, id: String) -> void:
	inst._open_chars()
	inst._char_view = id
	inst._refresh_char_page()


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
