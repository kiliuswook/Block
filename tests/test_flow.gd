extends Node
## 타이틀 흐름 회귀 테스트 — 인원·캐릭터는 타이틀에서 미리 세팅, PLAY는 모드 고르면 바로 시작.

func _ready() -> void:
	var tree := get_tree()
	var t: Node2D = load("res://core/scenes/title.tscn").instantiate()
	add_child(t)
	await tree.process_frame
	assert(t._players_chips.size() == 2, "타이틀 인원 토글이 없음")
	# --- 인원 세팅 ---
	t._set_players(2)
	assert(GameState.players == 2, "인원 세팅이 GameState에 안 남음")
	# --- 캐릭터 세팅: 인원만큼 좌석 탭이 뜨고, 고르는 즉시 저장된다 ---
	t._open_chars()
	assert(t._chars.visible, "캐릭터 페이지가 안 열림")
	assert(t._pick_count == 2 and t._char_seat_tabs[1].visible, "2P 좌석 탭이 없음")
	print("chars head: ", (t._chars.get_meta("head") as Label).text)
	var first: String = t._first_unlocked(GameState.selected_cat)
	t._pick_slot = 0
	t._assign_pick(first)
	assert(GameState.selected_cat == first, "1P 선택이 즉시 저장 안 됨")
	assert(t._pick_slot == 1, "2인일 때 다음 자리로 안 넘어감")
	t._assign_pick(first)
	assert(GameState.selected_cat2 == first, "2P 선택이 즉시 저장 안 됨")
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
	# 열려 있는 채로 인원을 1인으로 바꾸면 자리 카드도 바로 접힌다.
	t._set_players(1)
	assert(t._pick_count == 1 and not t._char_seat_tabs[1].visible, "자리 수 즉시 반영 안 됨")
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
