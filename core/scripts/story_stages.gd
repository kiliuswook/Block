class_name StoryStages
## Story mode stage table: TOTAL stages = a hand-authored tutorial curriculum
## (STAGES) followed by generated stages that cycle the goal types at rising
## speed, capped by a fixed grand-finale stage. A stage is a Dictionary:
##  name          — display name
##  hint          — intro/tutorial text (keyboard wording)
##  hint_touch    — optional touch-control wording (falls back to hint)
##  goal          — {"type": "escape"} (doors open from the start) or
##                  {"type": "lines"|"shoves"|"breaks", "count": N} /
##                  {"type": "survive", "time": sec} — doors stay locked
##                  until the goal is met
##  door          — "both" (default) / "left" / "right": which exits open
##  door_row      — top row of the 2-row exit tunnel (0 = pit top, 12 =
##                  ground level). Low doors make escaping easy: skill stages
##                  use ground doors, climb stages raise the exit gradually
##  no_pieces     — no tetromino falls at all (pure movement tutorial)
##  pieces        — restrict the 7-bag to these piece types
##  track_time / fall_interval — speed overrides for this stage
##  prefill       — named starting-grid pattern (see [_build_prefill])
##  spawn_col     — player spawn column (default: pit center)

const TOTAL := 120

## Generated-stage goal cycle: one of each skill per 6 stages, escape twice.
const GEN_KINDS: Array[String] = [
	"escape", "lines", "shoves", "survive", "escape", "breaks",
]
const KIND_NAMES := {"escape": "탈출", "lines": "줄 클리어", "shoves": "밀치기",
		"survive": "생존", "breaks": "부수기"}

const STAGES: Array[Dictionary] = [
	# --- 기초 조작 (1-3): 이동/점프 → 블록 밟기 → 낙하 조작. 출구는 낮게. ---
	{"name": "첫 걸음", "goal": {"type": "escape"}, "no_pieces": true,
		"prefill": "stairs", "spawn_col": 8.5,
		"hint": "← → 로 이동, ↑ 로 점프!\n계단을 밟고 올라가 왼쪽 출구로 탈출하자",
		"hint_touch": "◀ ▶ 버튼으로 이동, ▲ 버튼으로 점프!\n계단을 밟고 올라가 왼쪽 출구로 탈출하자"},
	{"name": "블록 받기", "goal": {"type": "escape"}, "door_row": 10,
		"pieces": ["O"], "track_time": 5.0, "fall_interval": 0.5,
		"hint": "블록이 고양이를 따라와 떨어진다 — 깔리지만 말자!\n블록 하나만 밟고 올라서면 낮은 출구에 닿는다"},
	{"name": "빨리 떨어뜨리기", "goal": {"type": "escape"}, "door_row": 8,
		"pieces": ["O", "I"], "track_time": 8.0, "fall_interval": 0.5,
		"hint": "기다리기 지루하면 ↓ 로 블록을 당장 떨어뜨리자 (한 번 더 = 즉시 낙하)\n블록 두 개를 쌓아 밟으면 출구까지 닿는다",
		"hint_touch": "기다리기 지루하면 ▼ 버튼으로 블록을 당장 떨어뜨리자\n블록 두 개를 쌓아 밟으면 출구까지 닿는다"},
	# --- 스킬 학습 (4-7): 부수기/밀치기/줄/생존. 목표만 채우면 바닥 출구로. ---
	{"name": "블록 부수기", "goal": {"type": "breaks", "count": 2}, "no_pieces": true,
		"door_row": 12, "prefill": "break_wall",
		"hint": "블록 옆에서 대시 (같은 방향 더블탭), 아래에선 점프 박치기!\n같은 블록을 두 번 치면 부서진다\n2개를 부수면 바닥 출구가 열린다",
		"hint_touch": "이동 버튼을 빠르게 두 번 = 대시로 블록 치기!\n같은 블록을 두 번 치면 부서진다\n2개를 부수면 바닥 출구가 열린다"},
	{"name": "밀치기", "goal": {"type": "shoves", "count": 1}, "door_row": 12,
		"pieces": ["O"], "track_time": 9.0, "fall_interval": 0.5,
		"hint": "낙하 중인 블록을 대시로 들이받으면 옆으로 밀려난다!\n한 번만 밀쳐도 바닥 출구가 열린다",
		"hint_touch": "이동 버튼 빠르게 두 번 = 대시!\n낙하 중인 블록을 대시로 밀치면 바닥 출구가 열린다"},
	{"name": "줄 클리어", "goal": {"type": "lines", "count": 1}, "door_row": 12,
		"pieces": ["O", "I", "L", "J"], "track_time": 6.0, "fall_interval": 0.45,
		"prefill": "line_gap3",
		"hint": "가로 한 줄을 가득 채우면 줄이 통째로 사라진다!\n바닥의 빈칸 위에 서서 블록을 유도해 넣자\n1줄을 지우면 바닥 출구가 열린다"},
	{"name": "버티기", "goal": {"type": "survive", "time": 20}, "door_row": 12,
		"track_time": 5.0, "fall_interval": 0.4,
		"hint": "20초 동안 깔리지 않고 살아남으면 바닥 출구가 열린다!\n블록 밑에 서 있지 말고 계속 움직이자"},
	# --- 복습 + 심화 (8-14): 같은 스킬을 조금 더 어렵게. ---
	{"name": "조금 더 높이", "goal": {"type": "escape"}, "door_row": 6,
		"pieces": ["O", "I", "L", "J"], "track_time": 5.0, "fall_interval": 0.4,
		"hint": "출구가 조금 높아졌다!\n블록을 원하는 자리에 떨어뜨려 계단을 만들자"},
	{"name": "밀치기 II", "goal": {"type": "shoves", "count": 3}, "door_row": 12,
		"pieces": ["O", "I", "L", "J"], "track_time": 6.0, "fall_interval": 0.4,
		"hint": "이번엔 3번!\n낙하 중인 블록을 대시로 밀쳐 방향을 바꾸자"},
	{"name": "줄 클리어 II", "goal": {"type": "lines", "count": 2}, "door_row": 12,
		"track_time": 5.5, "fall_interval": 0.4, "prefill": "line_gaps",
		"hint": "2줄! 이제 모든 모양의 블록이 떨어진다\nZ/X로 블록을 회전시킬 수도 있다",
		"hint_touch": "2줄! 이제 모든 모양의 블록이 떨어진다\n빈 곳을 탭하면 블록이 회전한다"},
	{"name": "오르막", "goal": {"type": "escape"}, "door_row": 4,
		"track_time": 5.0, "fall_interval": 0.35,
		"hint": "출구가 더 높아졌다!\n벽에 붙어 미끄러지며 다시 점프 = 벽점프도 기억해두자"},
	{"name": "버티기 II", "goal": {"type": "survive", "time": 30}, "door_row": 12,
		"track_time": 4.5, "fall_interval": 0.3,
		"hint": "30초 생존!\n벽이 높아지면 줄을 지우거나 블록을 부숴 공간을 확보하자"},
	{"name": "부수고 나가기", "goal": {"type": "breaks", "count": 4}, "no_pieces": true,
		"door_row": 12, "prefill": "break_wall2",
		"hint": "블록 4개를 부숴라!\n대시와 점프 박치기를 섞어 쓰면 빠르다"},
	{"name": "줄 클리어 III", "goal": {"type": "lines", "count": 3}, "door_row": 12,
		"track_time": 5.0, "fall_interval": 0.35, "prefill": "line_gap2",
		"hint": "3줄! 빈칸이 좁아졌다\n대시로 블록을 밀어 꽂아 넣는 게 요령이다"},
	# --- 종합 (15-20): 배운 것 전부, 출구는 점점 꼭대기로. ---
	{"name": "꼭대기까지", "goal": {"type": "escape"}, "door_row": 2,
		"track_time": 4.5, "fall_interval": 0.3,
		"hint": "출구가 거의 꼭대기다!\n차근차근 블록을 쌓으며 올라가자"},
	{"name": "왼쪽 통로", "goal": {"type": "escape"}, "door": "left", "door_row": 4,
		"track_time": 4.2, "fall_interval": 0.28,
		"hint": "왼쪽 출구만 열려 있다!\n왼쪽 벽을 따라 올라가자"},
	{"name": "밀치기 III", "goal": {"type": "shoves", "count": 5}, "door_row": 12,
		"track_time": 5.0, "fall_interval": 0.35,
		"hint": "밀치기 5회!\n대시 쿨타임에 주의하며 연속으로 밀쳐보자"},
	{"name": "버티기 III", "goal": {"type": "survive", "time": 40}, "door_row": 12,
		"track_time": 4.0, "fall_interval": 0.26,
		"hint": "40초 생존!\n빨라진 블록 아래에서 침착하게 버텨내자"},
	{"name": "오른쪽 통로", "goal": {"type": "escape"}, "door": "right", "door_row": 2,
		"track_time": 4.0, "fall_interval": 0.26,
		"hint": "오른쪽 출구만 열려 있다 — 거의 꼭대기 높이!\n오른쪽 벽을 따라 쌓아 올라가자"},
	{"name": "첫 정상", "goal": {"type": "escape"}, "door_row": 0,
		"track_time": 4.0, "fall_interval": 0.3,
		"hint": "드디어 맨 꼭대기 출구!\n여기부터가 진짜 시작이다 — 기본기를 총동원하자"},
]


## 1-based stage lookup with the prefill pattern resolved into cells.
static func get_stage(n: int) -> Dictionary:
	var s := _stage_def(n)
	if s.has("prefill"):
		s["prefill_cells"] = _build_prefill(str(s.prefill))
	return s


static func _stage_def(n: int) -> Dictionary:
	n = clampi(n, 1, TOTAL)
	if n <= STAGES.size():
		return STAGES[n - 1].duplicate()
	if n >= TOTAL:
		return {"name": "그랜드 피날레", "goal": {"type": "escape"}, "door_row": 0,
			"track_time": 2.2, "fall_interval": 0.14,
			"hint": "마지막 스테이지!\n모든 것을 쏟아부어 정상으로 탈출하라"}
	return _generated(n)


## Stages past the curriculum: goal types cycle (GEN_KINDS) while the tier —
## one step per full cycle — raises speed, goal counts and exit height.
static func _generated(n: int) -> Dictionary:
	var idx := n - STAGES.size() - 1  # 0-based index into the generated run
	var kind := GEN_KINDS[idx % GEN_KINDS.size()]
	var tier := idx / GEN_KINDS.size()
	var s := {
		"name": "%s Lv.%d" % [KIND_NAMES[kind], tier + 1],
		"track_time": maxf(5.0 - tier * 0.2, 2.4),
		"fall_interval": maxf(0.4 - tier * 0.018, 0.15),
	}
	match kind:
		"escape":
			# Two escape slots per cycle: the first climbs a mid-height exit,
			# the second is higher and alternates single-side doors.
			var second := idx % GEN_KINDS.size() == 4
			var base_row := (4 if second else 8) - tier
			s["door_row"] = maxi(base_row, 0)
			if second:
				s["door"] = "left" if tier % 2 == 0 else "right"
			s["goal"] = {"type": "escape"}
			s["hint"] = "출구로 탈출하라!\n출구가 점점 높아지고 블록은 빨라진다"
		"lines":
			var count := mini(2 + tier / 2, 8)
			s["goal"] = {"type": "lines", "count": count}
			s["prefill"] = ["line_gap3", "line_gaps", "line_gap2"][tier % 3]
			s["door_row"] = maxi(12 - tier, 6)
			s["hint"] = "줄 %d개를 지워 출구를 열어라!" % count
		"shoves":
			var count := mini(2 + tier, 10)
			s["goal"] = {"type": "shoves", "count": count}
			s["door_row"] = maxi(12 - tier, 6)
			s["hint"] = "낙하 중인 블록을 대시로 %d번 밀쳐 출구를 열어라!" % count
		"survive":
			var time := mini(25 + tier * 5, 90)
			s["goal"] = {"type": "survive", "time": time}
			s["door_row"] = maxi(12 - tier, 6)
			s["hint"] = "%d초 동안 살아남아 출구를 열어라!" % time
		"breaks":
			var count := mini(3 + tier, 12)
			s["goal"] = {"type": "breaks", "count": count}
			s["prefill"] = "break_wall2"
			s["door_row"] = maxi(12 - tier, 6)
			s["hint"] = "블록 %d개를 부숴 출구를 열어라!\n(떨어져 쌓인 블록도 부술 수 있다)" % count
	return s


## Goal/progress line for the HUD. count = goal progress or seconds alive.
static func progress_text(stage: Dictionary, count: int, done: bool) -> String:
	var goal: Dictionary = stage.get("goal", {})
	var type := str(goal.get("type", "escape"))
	if type == "escape":
		return "목표: 출구로 탈출하라!"
	if done:
		return "출구가 열렸다 — 탈출하라!"
	match type:
		"lines":
			return "목표: 줄 클리어  %d / %d" % [count, int(goal.count)]
		"shoves":
			return "목표: 블록 밀치기  %d / %d" % [count, int(goal.count)]
		"breaks":
			return "목표: 블록 부수기  %d / %d" % [count, int(goal.count)]
		"survive":
			return "목표: 생존  %d / %d초" % [count, int(goal.time)]
	return ""


## Starting-grid patterns, keyed by name. Grid is 10 cols × 14 rows; a
## walkable top at row R+2 lines up with a door whose door_row is R.
static func _build_prefill(pattern: String) -> Dictionary:
	var cells := {}
	match pattern:
		"stairs":
			# Staircase rising right→left, 2 rows per step (within jump reach),
			# ending level with the top-left door. Columns 8-9 stay open.
			var tops := {0: 2, 1: 2, 2: 2, 3: 4, 4: 6, 5: 8, 6: 10, 7: 12}
			for x: int in tops:
				for y in range(tops[x], 14):
					cells[Vector2i(x, y)] = "J" if (x + y) % 2 == 0 else "L"
		"break_wall":
			# A 2-wide tower beside the spawn — smash through it.
			for x in [6, 7]:
				for y in range(10, 14):
					cells[Vector2i(x, y)] = "Z"
		"break_wall2":
			# Two towers hemming the spawn in from both sides.
			for x in [3, 4, 6, 7]:
				for y in range(10, 14):
					cells[Vector2i(x, y)] = "Z"
		"line_gap3":
			# One bottom row with a 3-wide slot in the middle.
			for x in [0, 1, 2, 3, 7, 8, 9]:
				cells[Vector2i(x, 13)] = "S"
		"line_gaps":
			# Bottom rows nearly full: a 4-wide gap below, 6-wide above.
			for x in [0, 1, 2, 7, 8, 9]:
				cells[Vector2i(x, 13)] = "S"
			for x in [0, 1, 8, 9]:
				cells[Vector2i(x, 12)] = "T"
		"line_gap2":
			# One bottom row with a 2-wide slot in the middle.
			for x in [0, 1, 2, 3, 6, 7, 8, 9]:
				cells[Vector2i(x, 13)] = "L"
	return cells
