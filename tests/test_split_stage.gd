extends Node
## 스테이지 모드 2인(화면 분할) 회귀 테스트 — 1인 플레이와 같은 기록을 남기는 모드다.
## ① 좌석마다 점수를 따로 센다 ② 먼저 끝난 좌석은 멈춰 있고 남은 좌석은 계속 논다
## ③ 둘 다 끝나면 승자의 성적만 기록·랭킹에 올라간다.

func _ready() -> void:
	var tree := get_tree()
	GameState.mode = GameState.MODE_CLASSIC
	GameState.split = true
	var m: Node2D = load("res://core/scenes/main.tscn").instantiate()
	add_child(m)
	await tree.process_frame
	assert(m.boards.size() == 2, "분할 보드가 둘이 아님")
	assert(m.goal_meter == null, "분할 화면에 1인용 아케이드 HUD가 만들어짐")
	assert(m.seat_hud.size() == 2, "좌석별 계기판이 없음")
	var b1: EscapeBoard = m.boards[0]
	var b2: EscapeBoard = m.boards[1]
	assert(b1.playing and b2.playing, "양쪽 보드가 시작 안 됨")
	GameState.classic_best = 0
	GameState.classic_level_best = 0
	b1.run_score = 500
	b2.run_score = 1800
	b2.level = 4
	b2.total_lines = 12
	# --- 한쪽이 죽어도 판은 계속된다 ---
	b1._kill_player()
	await tree.process_frame
	assert(not b1.playing and b2.playing, "죽은 좌석이 남은 좌석까지 멈춤")
	assert(m.round_active, "한쪽 사망으로 판이 끝나 버림")
	assert(GameState.score == 0, "분할인데 공용 점수가 쌓임")
	assert(m.versus_tally == null, "스테이지 분할에 라운드 집계가 남아 있음")
	print("labels: ", (m.split_labels[0] as Label).text, " | ",
			(m.split_labels[1] as Label).text)
	print("seat HUD: ", (m.seat_hud[0]["score"] as Label).text, " / ",
			(m.seat_hud[1]["score"] as Label).text, "   LV ",
			(m.seat_hud[1]["level"] as Label).text, "   ",
			(m.seat_hud[1]["lines"] as Label).text)
	# --- 둘 다 끝나면 승자의 기록이 남는다 ---
	b2._kill_player()
	await tree.process_frame
	assert(not m.round_active, "양쪽 종료인데 판이 안 끝남")
	assert(GameState.classic_best == 1800, "승자 점수가 최고 기록에 안 올라감")
	assert(GameState.classic_level_best == 4, "승자 도달 LEVEL이 안 남음")
	print("banner: ", (m.milestone_label as Label).text)
	# --- 다시하기는 양쪽을 새 판으로 되돌린다 ---
	m._restart()
	await tree.process_frame
	assert(b1.playing and b2.playing, "재시작이 양쪽을 살리지 않음")
	assert(m.stage_split_over == [false, false] and b1.run_score == 0,
			"재시작이 좌석 상태를 안 지움")
	print("PASS")
	tree.quit()
