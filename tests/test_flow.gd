extends Node
## 타이틀 흐름 회귀 테스트 — 인원·캐릭터는 타이틀 무대의 좌석에서 세팅하고,
## PLAY는 모드만 고르면 바로 시작한다. 캐릭터 메뉴는 자리를 건드리지 않는다.

func _ready() -> void:
	var tree := get_tree()
	var t: Node2D = load("res://core/scenes/title.tscn").instantiate()
	add_child(t)
	await tree.process_frame
	assert(t._seat_btns.size() == 2, "타이틀 무대에 좌석 둘이 안 섰음")
	# --- 인원 세팅: 빈 2P 자리를 채우면 2인, 비우면 1인 ---
	assert(GameState.players == 1 or GameState.players == 2)
	t._set_players(1)
	assert(not t._seat_leave.visible, "1인인데 자리 비우기 버튼이 떠 있음")
	t._on_seat_btn(1)  # 빈 자리 = "2인 플레이 참가"
	assert(GameState.players == 2, "빈 자리로 2인 참가가 안 됨")
	assert(t._seat_leave.visible, "2인인데 자리 비우기 버튼이 없음")
	# --- 좌석의 "캐릭터 변경"이 그 자리 몫으로 캐릭터 페이지를 연다 ---
	var first: String = t._first_unlocked(GameState.selected_cat)
	t._on_seat_btn(1)
	assert(t._chars.visible and t._pick_seat == 2, "2P 자리로 캐릭터 페이지가 안 열림")
	print("chars head: ", (t._chars.get_meta("head") as Label).text)
	t._assign_pick(first)
	assert(GameState.selected_cat2 == first, "2P 선택이 즉시 저장 안 됨")
	assert(t._pick_seat == 2, "자리가 멋대로 넘어감")
	t._close_chars()
	t._on_seat_btn(0)
	assert(t._pick_seat == 1, "1P 자리로 캐릭터 페이지가 안 열림")
	t._assign_pick(first)
	assert(GameState.selected_cat == first, "1P 선택이 즉시 저장 안 됨")
	# --- 메뉴에서 연 캐릭터 페이지는 둘러보기 — 자리를 건드리지 않는다 ---
	t._close_chars()
	t._open_chars()
	assert(t._pick_seat == 0, "메뉴에서 연 페이지가 자리 배정 모드임")
	var other := ""
	for cat in GameState.all_cats():
		if cat.id != first and GameState.is_unlocked(cat.id):
			other = str(cat.id)
			break
	if other != "":
		t._on_tile_pressed(GameState.get_cat(other))
		assert(t._char_view == other, "둘러보기에서 냥이가 안 펼쳐짐")
		assert(GameState.selected_cat == first, "둘러보기가 자리 냥이를 바꿈")
	# --- "+" 타일: 커스텀 슬롯이 하나 더 열리고, 그 슬롯이 본문에 펼쳐진다 ---
	var slots0: int = GameState.custom_slots
	if GameState.can_add_custom_slot():
		var tiles0: int = t._char_strip.get_child_count()
		var add: Button = t._char_strip.get_child(tiles0 - 1)
		add.pressed.emit()
		await tree.process_frame
		assert(GameState.custom_slots == slots0 + 1, "커스텀 슬롯이 안 열림")
		assert(t._char_view == GameState.custom_slot_id(GameState.custom_slots),
				"새 슬롯이 본문에 안 펼쳐짐")
		assert(GameState.is_custom_cat(t._char_view), "새 슬롯이 커스텀이 아님")
		assert(not t._char_right.visible, "커스텀 슬롯에 보상 열이 떠 있음")
		GameState.custom_slots = slots0  # 테스트가 세이브를 늘리지 않게 되돌린다
		GameState.save_game()
		t._build_char_tiles()
		t._char_view = first
		t._refresh_char_page()
	t._close_chars()
	assert(not t._chars.visible)
	# --- PLAY: 모드를 고르면 캐릭터를 다시 묻지 않고 바로 시작 ---
	t._set_players(2)
	t._open_modes()
	assert(t._pick_count == 2)
	for row in t._mode_rows:
		var ok: bool = t._max_players(int(row["mode"])) >= 2
		assert((row["btn"] as Button).disabled == not ok, "잠금 상태 불일치")
	GameState.mode = -1
	t._on_mode_picked(GameState.MODE_STORY)  # 1인 전용 → 거절
	assert(GameState.mode == -1 and t._modes.visible, "1인 전용 모드가 2인에서 통과됨")
	# 씬 전환은 deferred라 이 프레임에는 아직 일어나지 않는다 — 세팅만 확인한다.
	assert(t._max_players(GameState.MODE_CLASSIC) == 2, "스테이지 모드가 2인을 못 받음")
	t._on_mode_picked(GameState.MODE_ENDLESS)
	assert(not t._chars.visible, "플레이 입장에서 캐릭터를 또 물어봄")
	assert(GameState.mode == GameState.MODE_ENDLESS and GameState.split,
			"모드 선택 → 바로 시작 실패")
	print("PASS")
	tree.quit()
