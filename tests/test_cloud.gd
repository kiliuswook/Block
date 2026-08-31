extends Node
## 모바일 백엔드(Supabase) 회귀 테스트 — 네트워크를 타지 않는 부분만 본다:
## 백엔드 선택, 보드 행/엔트리 변환, 세이브 rev 판정, 주차 기준이 서버 SQL과
## 맞는지. 실제 통신은 `docs/cloud_setup.md` ④ 이후 DEV 패널로 확인한다.

func _ready() -> void:
	# ⚠ 실기 세이브를 덮어쓰지 않도록 저장부터 끈다 (user:// 를 실기와 공유한다).
	GameState.save_enabled = false
	var fails := 0

	# --- 설정이 비어 있으면 서버 기능은 통째로 꺼진다 -------------------------
	fails += _chk(not Cloud.enabled(), "cloud/url 이 비었는데 Cloud가 켜져 있음")
	fails += _chk(Ranks.backend() != Ranks.Backend.SERVER,
			"Cloud가 꺼졌는데 백엔드가 SERVER 임")
	fails += _chk(Ranks.backend() == Ranks.Backend.HTTP,
			"기본 백엔드가 HTTP(jsonblob) 가 아님: %d" % Ranks.backend())
	# 꺼진 상태에서 부르는 것들이 조용히 넘어가야 한다 (요청이 나가면 안 된다).
	Cloud.mark_dirty()
	fails += _chk(not await Cloud.ensure_auth(), "꺼진 Cloud가 로그인을 시도함")

	# --- 주차 기준이 서버 week_id() SQL 과 같은가 -----------------------------
	# WEEK_ANCHOR 는 "월요일 00:00 KST" 여야 한다 — schema.sql 의 313200 과 같은 값.
	var kst := Time.get_datetime_dict_from_unix_time(Ranks.WEEK_ANCHOR + 32400)
	fails += _chk(int(kst.weekday) == 1, "WEEK_ANCHOR 가 월요일이 아님: %s" % [kst])
	fails += _chk(int(kst.hour) == 0 and int(kst.minute) == 0,
			"WEEK_ANCHOR 가 00:00 KST 가 아님: %s" % [kst])
	fails += _chk(Ranks.WEEK_LEN == 604800, "WEEK_LEN 이 한 주가 아님")
	fails += _chk(Ranks.week_id() > 2900, "지금 주차가 말이 안 됨: %d" % Ranks.week_id())
	# 누적 보드는 주간과 절대 겹치지 않는 표식이어야 한다.
	fails += _chk(Cloud.ALL_TIME < 0, "누적 보드 표식이 음수가 아님")

	# --- 보드 행 만들기 -------------------------------------------------------
	GameState.selected_cat = "cream"
	GameState.nickname = "테스트냥"
	var row := Cloud.score_row("endless", Cloud.ALL_TIME, 42)
	fails += _chk(int(row.week_id) == Cloud.ALL_TIME, "누적 행의 week_id 가 다름")
	fails += _chk(int(row.value) == 42 and str(row.mode) == "endless",
			"행의 값/모드가 다름: %s" % [row])
	fails += _chk(str(row.name) == "테스트냥" and str(row.cat) == "cream",
			"행에 이름/캐릭터가 안 실림: %s" % [row])
	fails += _chk(not row.has("replay"), "리플레이를 안 붙였는데 키가 들어감")
	var wrow := Cloud.score_row("classic", Ranks.week_id(), 1200)
	fails += _chk(int(wrow.week_id) == Ranks.week_id(), "주간 행의 주차가 다름")

	# --- 서버 응답 → 엔트리 변환 ----------------------------------------------
	var rows: Array = [
		{"user_id": "u1", "name": "일등냥", "value": 90, "cat": "black", "replay": null},
		{"user_id": "u2", "name": "이등냥", "value": 80, "cat": "cream", "replay": "AAA"},
		"쓰레기값",
	]
	var ents := Cloud.to_entries(rows)
	fails += _chk(ents.size() == 2, "엔트리 수가 2가 아님: %d" % ents.size())
	fails += _chk(str(ents[0].id) == "u1" and int(ents[0].v) == 90,
			"엔트리 id/값 변환이 틀림: %s" % [ents[0]])
	fails += _chk(str(ents[0].replay) == "", "null 리플레이가 빈 문자열이 아님")
	fails += _chk(str(ents[1].replay) == "AAA", "리플레이가 안 실림")
	fails += _chk(Cloud.to_entries(null).is_empty(), "배열이 아닌 응답이 안 걸러짐")

	# --- 세이브 rev: 서버가 앞설 때만 받아 온다 -------------------------------
	fails += _chk(Cloud.should_adopt(3, 4), "서버 rev 가 큰데 안 받아옴")
	fails += _chk(not Cloud.should_adopt(4, 4), "같은 rev 를 다시 받아옴")
	fails += _chk(not Cloud.should_adopt(5, 4), "오래된 서버 세이브를 받아옴")
	GameState.cloud_rev = 7
	fails += _chk(int(GameState.save_dict().get("cloud_rev", -1)) == 7,
			"save_dict 에 cloud_rev 가 안 들어감")

	print("ALL TESTS PASSED" if fails == 0 else "FAILED: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _chk(ok: bool, msg: String) -> int:
	if not ok:
		printerr("  ✗ ", msg)
	return 0 if ok else 1
