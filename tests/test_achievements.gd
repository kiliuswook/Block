extends Node
## 업적 판정 회귀 테스트 — 상태형 조건이 세이브 값으로 정확히 걸리는지,
## 이미 딴 업적이 두 번 쌓이지 않는지 본다. (스팀 없이도 돈다 — Platform이 no-op)

func _ready() -> void:
	# ⚠ 실기 세이브를 덮어쓰지 않도록 저장부터 끈다 (user:// 를 실기와 공유한다).
	GameState.save_enabled = false
	var fails := 0
	# 세이브를 건드리지 않도록 값만 갈아 끼우고 판정한다.
	GameState.achv = []
	GameState.best_height = 0
	GameState.classic_level_best = 0
	GameState.classic_best = 0
	GameState.gacha_drawn = 0
	GameState.gold_earned = 0
	GameState.keycaps = {}
	Achv.check()
	var base: Array = GameState.achv.duplicate()
	fails += _chk(Achv.HEIGHT_25 not in base, "빈 세이브에 높이 업적이 붙음")

	GameState.best_height = 60
	GameState.classic_level_best = 10
	GameState.classic_best = 120000
	GameState.gacha_drawn = Achv.GACHA_GOAL
	GameState.gold_earned = Achv.GOLD_GOAL
	Achv.check()
	for id in [Achv.HEIGHT_25, Achv.HEIGHT_50, Achv.CLASSIC_LV5, Achv.CLASSIC_LV10,
			Achv.CLASSIC_100K, Achv.GACHA_100, Achv.GOLD_10K]:
		fails += _chk(Achv.has(id), "조건을 채웠는데 %s 가 안 열림" % id)
	fails += _chk(not Achv.has(Achv.HEIGHT_100), "100층 전에 HEIGHT_100 이 열림")

	# 키캡: 한 냥이의 A~Z 한 바퀴 = 해금 + KEYCAP_RING
	var cat: String = str(GameState.keycap_cats()[1].id)  # 첫 냥이는 공짜 바퀴라 제외
	GameState.add_keycap(cat, "A", false)
	Achv.check()
	fails += _chk(Achv.has(Achv.KEYCAP_FIRST), "키캡 1장에 KEYCAP_FIRST 가 안 열림")
	fails += _chk(not Achv.has(Achv.KEYCAP_RING), "한 바퀴 전에 KEYCAP_RING 이 열림")
	for i in 26:
		GameState.add_keycap(cat, char(65 + i), false)
	Achv.check()
	fails += _chk(Achv.has(Achv.KEYCAP_RING), "한 바퀴를 채웠는데 KEYCAP_RING 이 안 열림")
	fails += _chk(not Achv.has(Achv.CAT_UNLOCK_ALL), "한 마리만 열렸는데 전원 해금이 뜸")

	# 중복 해금 방지
	Achv.unlock(Achv.REPLAY_WATCH)
	Achv.unlock(Achv.REPLAY_WATCH)
	fails += _chk(GameState.achv.count(Achv.REPLAY_WATCH) == 1, "업적이 두 번 쌓임")

	# 정의표는 파트너 사이트 등록 목록과 1:1 — id 중복이 없어야 한다
	var ids := {}
	for d in Achv.DEFS:
		ids[d.id] = true
	fails += _chk(ids.size() == Achv.DEFS.size(), "DEFS 에 중복 id 가 있음")

	print("ALL TESTS PASSED" if fails == 0 else "FAILED: %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _chk(ok: bool, msg: String) -> int:
	if ok:
		return 0
	print("  FAIL: ", msg)
	return 1
