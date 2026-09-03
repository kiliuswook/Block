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
	# 캔 뽑기 — 유니크 냥이 1종을 거는 오버레이.
	await _capture("res://core/scenes/title.tscn", OUT + "/title_gacha_can.png",
			func(inst: Node) -> void:
				inst._open_gacha()
				inst._open_gacha_can())
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
	# 키캡 한 바퀴를 채웠을 때 뜨는 해금 안내 — 캐릭터 합류판과 파츠 단계판.
	await _capture("res://core/scenes/title.tscn", OUT + "/title_unlock_char.png",
			func(inst: Node) -> void:
				inst._open_gacha()
				inst._unlock_queue.assign([{"cat": "wizard", "grade": 1},
						{"cat": "gray", "grade": 1}])
				inst._unlock_at = 0
				inst._open_unlock())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_unlock_parts.png",
			func(inst: Node) -> void:
				inst._open_gacha()
				inst._unlock_queue.assign([{"cat": "cheese", "grade": 3}])
				inst._unlock_at = 0
				inst._open_unlock())
	# 실제 뽑기 → 캡슐 연출 → 해금 안내까지 이어지는지 (전 냥이가 Z 한 장만 남은 상태).
	gold_before = GameState.gold
	caps_before = GameState.keycaps.duplicate(true)
	GameState.gold = 9999
	GameState.keycaps = _almost_full_keycaps()
	await _capture("res://core/scenes/title.tscn", OUT + "/title_unlock_flow.png",
			func(inst: Node) -> void:
				inst._open_gacha()
				inst._gacha_n[0] = 1
				inst._on_gacha(0)
				inst._pull_t = 99.0  # 캡슐 연출을 끝까지 돌린 셈 치고
				inst._process(0.0))
	GameState.gold = gold_before
	GameState.keycaps = caps_before
	GameState.save_game()
	# 세로 화면에서도 팝업이 자리를 지키는지 (모바일은 상점도 세로다).
	await _capture("res://mobile/ui/title_mobile.tscn", OUT + "/m_unlock_parts.png",
			func(inst: Node) -> void:
				inst._open_gacha()
				inst._unlock_queue.assign([{"cat": "cheese", "grade": 3}])
				inst._unlock_at = 0
				inst._open_unlock())
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
	# 업적 화면은 모바일에만 있다 (스팀은 오버레이가 대신한다).
	await _capture("res://mobile/ui/title_mobile.tscn", OUT + "/m_title_achv.png",
			func(inst: Node) -> void: inst._open_achv())
	GameState.keycaps = _demo_keycaps()
	await _capture("res://core/scenes/title.tscn", OUT + "/title_keycaps.png",
			func(inst: Node) -> void: inst._open_keycap_dex("cheese"))
	# 보상 열: 등급별로 그 단계 파츠를 입은 모습이 칩마다 달라야 한다.
	await _capture("res://core/scenes/title.tscn", OUT + "/title_char_rewards.png",
			func(inst: Node) -> void: _view_cat(inst, "cream"))
	GameState.keycaps = saved_caps
	# 유니크 냥이 — 키캡 게이지가 은빛이고 "캔 뽑기 전용" 안내가 붙는다.
	await _capture("res://core/scenes/title.tscn", OUT + "/title_char_unique.png",
			func(inst: Node) -> void: _view_cat(inst, "wizard"))
	await _capture("res://core/scenes/title.tscn", OUT + "/title_char_cream.png",
			func(inst: Node) -> void: _view_cat(inst, "cream"))
	await _capture("res://core/scenes/title.tscn", OUT + "/title_char_feature.png",
			func(inst: Node) -> void:
				_view_cat(inst, "cream")
				inst._open_feature_ask())
	# 나만의 캐릭터 (꾸미기는 이 슬롯 전용) — 카드 안 꾸미기 패널 + 잠긴 파츠(눈 줄).
	await _capture("res://core/scenes/title.tscn", OUT + "/title_char_mycat.png",
			func(inst: Node) -> void: _view_cat(inst, "mycat"))
	# 잠긴 색 스와치도 제 색으로 보인다 — 자물쇠·값은 흰 반투명 판 위에.
	await _capture("res://core/scenes/title.tscn", OUT + "/title_mycat_swatches.png",
			func(inst: Node) -> void:
				_view_cat(inst, "mycat")
				inst._customizer._cur = 5
				# 패널을 짓는 동안만 눈 색을 안 산 상태로 — 세이브에는 안 남는다.
				_keep_owned = GameState.parts_owned.duplicate(true)
				GameState.parts_owned.erase("eye_col")
				inst._customizer._refresh())
	await _capture("res://core/scenes/title.tscn", OUT + "/title_mycat_eyes.png",
			func(inst: Node) -> void:
				GameState.parts_owned = _keep_owned  # 위 캡처가 뺀 눈 색 되돌리기
				_view_cat(inst, "mycat")
				inst._customizer._cur = 5  # 눈 줄 — 모양+색을 한 패널에서 확인
				inst._customizer._refresh()
				# 잠긴 파츠를 누른 상태 — 입혀 보여 주면서 값을 묻는 구매 확인창
				inst._customizer._pick("eyes", 3))
	# 유니크 파츠 — 골드가 아니라 통조림 캔으로 사는 확인창 (눈 줄의 "별눈").
	await _capture("res://core/scenes/title.tscn", OUT + "/title_mycat_unique.png",
			func(inst: Node) -> void:
				_view_cat(inst, "mycat")
				inst._customizer._cur = 5
				inst._customizer._refresh()
				inst._customizer._pick("eyes", 4))
	await _capture("res://core/scenes/title.tscn", OUT + "/title_replay.png",
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
	await _capture("res://steam/ui/title_steam.tscn", OUT + "/title_steam.png")
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
	# 골드 블록: 스택에 박힌 금 · 떨어지는 블록에 실린 금 · 터지는 순간의 연출.
	await _capture("res://core/scenes/main.tscn", OUT + "/classic_ore.png",
			func(inst: Node) -> void: _seed_ore(inst.get_node("Board")))
	# 타격감 연출: 착지 예상 자리(고스트) · 낙하 잔상 · 착지 먼지/충격 링 ·
	# 지워지는 줄의 섬광과 파편 · 멀티 라인 배너.
	await _capture("res://core/scenes/main.tscn", OUT + "/classic_impact.png",
			func(inst: Node) -> void: _seed_impact(inst.get_node("Board")))
	# 셔터가 스택에 내려앉는 마지막 한 방: 남은 블록이 통째로 파편이 된다.
	await _capture("res://core/scenes/main.tscn", OUT + "/classic_shutter_blast.png",
			func(inst: Node) -> void:
				var b: Node = inst.get_node("Board")
				b._classic_setup_level(4)
				b.level_lines = Board.classic_quota(4)
				for y in range(14, 20):
					for x in range(EscapeBoard.COLS):
						if (x + y) % 4 != 0:
							b.grid[Vector2i(x, y)] = Board.PIECES[(x + y) % 7]
				inst._on_classic_level_started(4, Board.classic_quota(4), b.level_garbage)
				b._classic_start_shutter()
				for i in range(60):
					b._update_shutter(1.0)
					if b.shutter_phase != EscapeBoard.Shutter.CLOSING:
						break
				b._age_fx(0.12)
				b.set_process(false)
				b.queue_redraw())
	# 머리 위에서 블록이 내려오는 중 — 고양이가 움츠리고 땀을 흘린다 + NEXT 핸드오프.
	await _capture("res://core/scenes/main.tscn", OUT + "/classic_scare.png",
			func(inst: Node) -> void: _seed_scare(inst))
	GameState.mode = GameState.MODE_ENDLESS
	await _capture("res://core/scenes/main.tscn", OUT + "/endless.png")
	await _capture("res://core/scenes/main.tscn", OUT + "/endless_lava.png",
			func(inst: Node) -> void: inst.get_node("Board").lava_y = 940.0)
	await _capture("res://core/scenes/main.tscn", OUT + "/endless_hud.png",
			func(_inst: Node) -> void: EventBus.height_changed.emit(23))
	# 골드러시: 게이지가 반쯤 찬 평상시 · 발동 중(금빛 우물 + 금이 박힌 스택) ·
	# 기록선(자기 최고 높이에 걸린 금색 점선).
	await _capture("res://core/scenes/main.tscn", OUT + "/endless_fever_gauge.png",
			func(inst: Node) -> void: _seed_fever(inst, false))
	await _capture("res://core/scenes/main.tscn", OUT + "/endless_fever.png",
			func(inst: Node) -> void: _seed_fever(inst, true))
	# 피버가 끝난 직후 — 발밑에 우물 폭을 막은 암반(지워지지도 부서지지도 않는다).
	await _capture("res://core/scenes/main.tscn", OUT + "/endless_fever_floor.png",
			func(inst: Node) -> void:
				_seed_fever(inst, true)
				var b: Node = inst.get_node("Board")
				b._fever_step(EscapeBoard.FEVER_TIME, b.lava_y - 400.0)
				b._age_fx(0.4)
				b.queue_redraw())
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
						"경험치   +56\n레벨 업!   Lv.7   +220 G",
						{"gold": 87, "gold_from": GameState.gold - 87,
						"xp": 56, "xp_from": maxi(GameState.xp - 56, 0)}))
	# --- 모바일(세로 1080×1920) 레이아웃 --- (창 크기는 _fit_window가 씬 경로로 맞춘다)
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
	GameState.mode = GameState.MODE_ENDLESS
	await _capture("res://mobile/ui/main_mobile.tscn", OUT + "/m_endless.png",
			func(inst: Node) -> void: inst.get_node("TouchControls").visible = true)
	# 터치 컨트롤 눌린 모습 — 이동 패드 왼쪽 + 낙하 + 점프(링 퍼지는 중).
	await _capture("res://mobile/ui/main_mobile.tscn", OUT + "/m_touch_pressed.png",
			func(inst: Node) -> void:
				var tc: CanvasLayer = inst.get_node("TouchControls")
				tc.visible = true
				tc.get_node("JumpButton").touch_index = 3
				tc.get_node("JumpButton")._ring = 0.6
				tc.get_node("DropButton").touch_index = 4
				tc.get_node("MovePad")._touches[5] = -1)
	await _capture("res://mobile/ui/main_mobile.tscn", OUT + "/m_endless_fever.png",
			func(inst: Node) -> void:
				inst.get_node("TouchControls").visible = true
				_seed_fever(inst, true))
	GameState.mode = GameState.MODE_CLASSIC
	await _capture("res://mobile/ui/main_mobile.tscn", OUT + "/m_classic.png",
			func(inst: Node) -> void: inst.get_node("TouchControls").visible = true)
	await _capture("res://mobile/ui/main_mobile.tscn", OUT + "/m_classic_ore.png",
			func(inst: Node) -> void:
				inst.get_node("TouchControls").visible = true
				_seed_ore(inst.get_node("Board")))
	# 결과 화면 — 세로에서는 유저 HUD가 여기서 처음 뜬다 (코인이 날아갈 과녁).
	GameState.mode = GameState.MODE_ENDLESS
	await _capture("res://mobile/ui/main_mobile.tscn", OUT + "/m_death_popup.png",
			func(inst: Node) -> void:
				inst.get_node("Board")._kill_player()
				if inst.user_hud:
					inst._reveal_user_hud()
				inst.get_node("PopupLayer/DeathPopup").open(
						"도달 높이 23층      최고 기록 41층", true,
						"획득   +87 G", "",
						"경험치   +56
레벨 업!   Lv.7   +220 G",
						{"gold": 87, "gold_from": GameState.gold - 87,
						"xp": 56, "xp_from": maxi(GameState.xp - 56, 0)}))
	get_tree().quit()


## 골드 블록 캡처용 상태: 쌓인 금 몇 칸 + 지금 떨어지는 블록에 실린 금 +
## 방금 터진 금의 튐 연출.
## 무한의 계단 피버타임 한 컷. `on`이면 발동 중(무지개 우물 · 코인 비 · 속도선),
## 아니면 게이지가 반쯤 찬 평상시 + 기록선이 걸린 모습이다.
func _seed_fever(inst: Node, on: bool) -> void:
	var b: Node = inst.get_node("Board")
	GameState.best_height = 26
	EventBus.height_changed.emit(11)
	for y in range(15, 20):
		for x in range(EscapeBoard.COLS):
			if (x + y) % 3 != 0:
				b.grid[Vector2i(x, y)] = Board.PIECES[(x + y) % 7]
	if on:
		b._fever_gain(EscapeBoard.FEVER_MAX)
		# 잘게 나눠 흘려야 코인 비가 하늘부터 발밑까지 고르게 깔린다.
		for _i in 24:
			b._fever_step(EscapeBoard.FEVER_TIME * 0.4 / 24.0, b.lava_y - 400.0)
		b.fever_flash = 0.0  # 발동 섬광은 지나갔다 — 물든 우물만 남는다
	else:
		b._fever_gain(EscapeBoard.FEVER_MAX * 0.55)
		b.fever_near = 0.8
	b.queue_redraw()


func _seed_ore(b: Node) -> void:
	b._classic_setup_level(3)
	for y in range(15, 20):
		for x in range(EscapeBoard.COLS):
			if (x + y) % 3 != 0:
				b.grid[Vector2i(x, y)] = Board.PIECES[(x + y) % 7]
	b.ore[Vector2i(2, 17)] = true
	b.ore[Vector2i(7, 19)] = true
	b.ore[Vector2i(4, 15)] = true
	b._spawn_piece()
	b.piece_pos = Vector2i(3, 6)
	b.piece_ore = 1
	b.ore_fx.append([b._cell_rect(Vector2i(6, 13)).get_center(),
			EscapeBoard.ORE_FX_TIME * 0.25, EscapeBoard.ORE_VALUE])
	b.set_process(false)  # 튐 연출이 캡처 전에 늙어 사라지지 않게 정지시켜 둔다
	b.queue_redraw()


## 타격감 캡처용 상태: 방금 내리꽂힌 블록 하나(잔상·먼지·링·눌림)와, 그 아래에서
## 지워지는 중인 두 줄(섬광·파편·배너). 연출이 캡처 전에 늙지 않게 판을 세워 둔다.
func _seed_impact(b: Node) -> void:
	b._classic_setup_level(3)
	for y in range(14, 20):
		for x in range(EscapeBoard.COLS):
			if (x + y) % 5 != 0:
				b.grid[Vector2i(x, y)] = Board.PIECES[(x + y) % 7]
	b._spawn_piece()
	b.piece_type = "T"
	b.piece_rot = 0
	b.piece_pos = Vector2i(3, 11)
	b.piece_state = EscapeBoard.PieceState.FALLING
	b.fall_from = 2
	b.hard_drop_rows = 9
	b._push_trail(9, 0.6)
	b._land()
	# 지워지는 중인 두 줄 + 배너.
	for y in [17, 18]:
		b.row_flash.append([y, 0.05])
		for x in range(EscapeBoard.COLS):
			b._spawn_shards(b._cell_rect(Vector2i(x, y)).get_center(),
					Board.COLORS[Board.PIECES[(x + y) % 7]], 3)
	b.combo = 3
	b.banner_y = 17.5 * EscapeBoard.CELL
	b.banner_key = "FX_LINE_2"
	b.banner_age = 0.12
	b.hitstop = 0.0
	b.set_process(false)  # 연출이 캡처 전에 늙어 사라지지 않게 정지시켜 둔다
	b.queue_redraw()


## 고양이 머리 바로 위로 블록이 내려오는 순간 + NEXT 카드에서 날아오는 조각.
func _seed_scare(inst: Node) -> void:
	var b: Node = inst.get_node("Board")
	b._classic_setup_level(2)
	b._spawn_piece()
	b.piece_type = "O"
	b.piece_rot = 0
	b.piece_state = EscapeBoard.PieceState.FALLING
	var col := int(b.player.position.x / EscapeBoard.CELL)
	b.piece_pos = Vector2i(clampi(col - 1, 0, EscapeBoard.COLS - 2), 15)
	b.player.scare = b.overhead_threat(b.player.rect())
	b.player.queue_redraw()
	inst._flyer_armed = true
	inst._launch_handoff("O")
	# 연출이 캡처 전에 늙어 사라지지 않게 판·조각·고양이를 그 자리에 세워 둔다.
	inst.piece_flyer._flights[0][3] = 0.14
	inst.piece_flyer.set_process(false)
	inst.piece_flyer.queue_redraw()
	b.set_process(false)
	b.playing = false
	b.queue_redraw()


## 캐릭터 페이지를 열고 그 냥이를 본문에 펼친다.
var _keep_owned := {}


func _view_cat(inst: Node, id: String) -> void:
	inst._open_chars()
	inst._char_view = id
	inst._refresh_char_page()


## 씬 경로로 창 크기를 정한다 — mobile/ 씬은 세로 1080×1920, 나머지는 가로 1920×1080.
## (모바일 타이틀은 _ready에서 창을 세로로 돌려놓고 되돌리지 않으므로, 캡처마다 다시 맞춘다.)
func _fit_window(scene_path: String) -> void:
	var want := Vector2i(1080, 1920) if scene_path.begins_with("res://mobile/") 			else Vector2i(1920, 1080)
	var w := get_window()
	if w.size == want and w.content_scale_size == want:
		return
	w.borderless = true
	w.position = Vector2i.ZERO
	w.size = want
	w.content_scale_size = want
	await get_tree().process_frame
	await get_tree().process_frame


func _capture(scene_path: String, out: String, setup: Callable = Callable()) -> void:
	await _fit_window(scene_path)
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
## 모든 냥이가 Z 한 글자만 남은 상태 — 아무 키캡이나 뽑으면 등급이 오른다.
func _almost_full_keycaps() -> Dictionary:
	var out := {}
	for cat in GameState.CATS:
		var d := {}
		for j in 25:
			d[char(65 + j)] = 1
		out[str(cat.id)] = d
	return out


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
