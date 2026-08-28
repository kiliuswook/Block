extends Node
## 스팀 백엔드 점검 — 초기화 → 보드 생성 → 제출 → 조회를 순서대로 돌리고
## 결과를 콘솔에 찍는다. 실제 스팀 클라이언트가 켜져 있어야 의미가 있다.
##
##   & "<godot>" --path E:\Game\Block res://tests/steam_check.tscn -- --steam
##
## 기본 앱 id는 480(Spacewar)이라 스팀 계정만 있으면 바로 돌아간다. 480은
## 공용 테스트 앱이라 보드에 남이 만든 이상한 값이 섞여 있는 게 정상이다.

const PROBE_MODE := "endless"


func _ready() -> void:
	await get_tree().process_frame  # Platform autoload가 setup()을 마칠 때까지
	_line("플랫폼", Platform.platform_name())
	_line("확장 로드", str(Engine.has_singleton("Steam")))
	_line("리더보드 사용 가능", str(Platform.has_leaderboards()))
	if not Platform.has_leaderboards():
		_fail("스팀이 준비되지 않았다. 스팀 클라이언트가 켜져 있는지, "
				+ "--steam 인자로 실행했는지 확인할 것.")
		return
	_line("SteamID", Platform.user_id())
	_line("이름", Platform.user_name())
	_line("백엔드", ["OFFLINE", "HTTP", "STEAM"][Ranks.backend()])

	var board := Ranks.board_name(PROBE_MODE)
	var score := 40 + randi() % 20
	_line("제출", "%s ← %d" % [board, score])
	await Platform.submit_score(board, score,
			PackedInt32Array([Ranks.cat_index(GameState.selected_cat)]))

	var list: Array = await Platform.fetch_board(board, 10)
	_line("조회", "%d 엔트리" % list.size())
	for i in mini(5, list.size()):
		var e: Dictionary = list[i]
		print("    %2d. %-24s %8d  cat=%s ugc=%d" % [i + 1, e.get("name", "?"),
				int(e.get("v", 0)), e.get("cat", "-"), int(e.get("ugc", 0))])
	var mine := Platform.user_id()
	var found := list.any(func(e: Dictionary) -> bool: return str(e.get("id")) == mine)
	_line("내 기록이 보드에 있나", "예" if found else "아니오 (상위 10 밖일 수 있음)")

	var weekly := Ranks.board_name(PROBE_MODE, true)
	_line("이번 주 보드 이름", weekly)
	await Platform.submit_score(weekly, score)
	_line("주간 조회", "%d 엔트리" % (await Platform.fetch_board(weekly, 5)).size())
	print("\n[steam_check] 끝 — 위에 실패가 없으면 스팀 백엔드는 살아 있다.")
	get_tree().quit()


func _line(label: String, value: String) -> void:
	print("[steam_check] %-20s %s" % [label, value])


func _fail(msg: String) -> void:
	printerr("[steam_check] ", msg)
	get_tree().quit(1)
