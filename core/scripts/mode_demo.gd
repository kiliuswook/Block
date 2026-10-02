extends Control
## 모드 선택 카드의 미리보기 판 — 그 모드를 스스로 플레이하는 작은 데모.
##
## 실제 보드(`escape_board.gd`)를 띄우면 골드·기록·업적·효과음·진동이 전부 따라와서,
## 규칙만 옮긴 가벼운 시뮬레이션을 따로 돌린다: 조각이 위에서 냥이 열을 따라오다
## 떨어지고(스테이지 = 한 조각씩 떨어뜨리고 줄을 지운다, 무한 = 떨어진 조각을 밟고
## 올라가며 아래에서 용암이 차오른다), 냥이는 AABB 물리로 걷고 뛴다.
## 격자 좌표는 칸 단위(`CELL` 없이 폭 / 10), 카드 크기가 달라도 같은 코드로 돈다.
## 부모(`title.gd`의 마스크 노드)가 둥근 판을 그리고 `clip_children`으로 자른다.
## class_name 없음 — preload로 참조.

const UiKit := preload("res://core/scripts/ui_kit.gd")

const COLS := 10
const HALF := 0.39  # 냥이 판정 반폭 (player.gd SIZE 50 / CELL 64)
const GRAVITY := 46.0  # 칸/초²
const JUMP_V := 15.2  # 두 칸 남짓 오르는 점프
const WALK := 4.2  # 칸/초
const TRACK_STEP := 0.09  # 추적 중 한 칸 옮기는 간격
const ROT_STEP := 0.16
const FALL_CLASSIC := 24.0  # 소프트드롭 속도 (칸/초)
const FALL_ENDLESS := 15.0
const FLASH_TIME := 0.32
const LAVA_RISE := 0.3  # 칸/초 (발끝에 붙으면 더 느려진다 — 데모는 자주 죽으면 안 된다)
const LAVA_GAP := 4.5  # 용암이 냥이 발밑에서 이만큼 아래로는 처지지 않는다

var mode := GameState.MODE_CLASSIC
var on := true  # 선택된 카드인가 — 아니면 회색으로 눕힌다
var skin: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _cell := 32.0
var _rows := 12
var _grid := {}  # Vector2i -> 조각 종류
var _bag: Array = []

# 떨어지는 조각.
var _pt := ""
var _prot := 0
var _px := 3
var _py := 0.0
var _goal_x := 3
var _goal_rot := 0
var _state := 0  # 0 없음 · 1 추적 · 2 비키기 · 3 낙하 · 4 줄 섬광
var _t := 0.0
var _step_t := 0.0
var _rot_t := 0.0
var _flash_rows: Array = []

# 냥이.
var _cx := 2.5
var _cy := 0.0
var _vx := 0.0
var _vy := 0.0
var _ground := false
var _target := 2.5
var _look := 1.0
var _squash := 0.0

# 무한의 계단.
var _cam := 0.0  # 화면 맨 위 칸 (위로 오를수록 작아진다)
var _lava := 0.0  # 용암 윗면 칸
var _dir := 1

var _shake := 0.0
var _sb_cache := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_reset)
	_rng.seed = 7 + mode * 31
	_reset()


func _reset() -> void:
	_cell = maxf(size.x / COLS, 4.0)
	_rows = maxi(int(size.y / _cell), 6)
	_sb_cache.clear()
	_grid.clear()
	_bag.clear()
	_pt = ""
	_state = 0
	_t = 0.0
	_flash_rows.clear()
	_cam = 0.0
	_vx = 0.0
	_vy = 0.0
	if mode == GameState.MODE_CLASSIC:
		_fill_garbage(mini(3, _rows - 5))
		_cx = 1.5
	else:
		_cx = 1.5
		_lava = _rows + 5.0  # 첫 조각이 쌓일 틈은 준다
		_dir = 1
	_cy = _surface_row(int(_cx)) - HALF
	_target = _cx
	queue_redraw()


## 스테이지 모드 판 바닥의 방해 블록 — 줄마다 두세 칸 비워 둔다.
func _fill_garbage(n: int) -> void:
	var types: Array = Board.COLORS.keys()
	for i in n:
		var r := _rows - 1 - i
		var holes := [_rng.randi_range(0, COLS - 1), _rng.randi_range(0, COLS - 1)]
		for c in COLS:
			if c in holes:
				continue
			_grid[Vector2i(c, r)] = types[_rng.randi() % types.size()]


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	delta = minf(delta, 0.05)
	_t += delta
	_shake = maxf(_shake - delta * 30.0, 0.0)
	_squash = maxf(_squash - delta * 4.0, 0.0)
	if mode == GameState.MODE_CLASSIC:
		_tick_classic(delta)
	else:
		_tick_endless(delta)
	_tick_cat(delta)
	queue_redraw()


# --- 조각 ---------------------------------------------------------------------


func _next_type() -> String:
	if _bag.is_empty():
		_bag = Board.COLORS.keys()
		for i in range(_bag.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp: String = _bag[i]
			_bag[i] = _bag[j]
			_bag[j] = tmp
	return _bag.pop_back()


func _cells(t: String, rot: int, x: int, y: int) -> Array:
	var out: Array = []
	for c: Vector2i in Board.SHAPES[t][rot]:
		out.append(Vector2i(x + c.x, y + c.y))
	return out


func _fits(t: String, rot: int, x: int, y: int) -> bool:
	for c: Vector2i in _cells(t, rot, x, y):
		if c.x < 0 or c.x >= COLS or c.y >= _rows or _grid.has(c):
			return false
	return true


## (rot, x)에서 떨어뜨렸을 때 멈추는 y. 들어갈 자리가 없으면 -9999.
func _drop_y(t: String, rot: int, x: int, from_y: int) -> int:
	if not _fits(t, rot, x, from_y):
		return -9999
	var y := from_y
	while _fits(t, rot, x, y + 1):
		y += 1
	return y


func _foot_cols(t: String, rot: int, x: int) -> Array:
	var out: Array = []
	for c: Vector2i in Board.SHAPES[t][rot]:
		if not (x + c.x) in out:
			out.append(x + c.x)
	return out


func _lock() -> void:
	var cells := _cells(_pt, _prot, _px, int(_py))
	for c: Vector2i in cells:
		_grid[c] = _pt
	_shake = _cell * 0.12
	# 떨어진 조각이 냥이와 겹치면 냥이를 그 위로 올려 준다.
	var guard := 0
	while _cat_hits(_cx, _cy) and guard < 40:
		_cy -= 1.0
		guard += 1
	_pt = ""


func _full_rows() -> Array:
	var out: Array = []
	var seen := {}
	for c: Vector2i in _grid:
		seen[c.y] = int(seen.get(c.y, 0)) + 1
	for r: int in seen:
		if int(seen[r]) >= COLS:
			out.append(r)
	out.sort()
	return out


func _clear_rows(rows: Array) -> void:
	var ng := {}
	for c: Vector2i in _grid:
		if c.y in rows:
			continue
		var shift := 0
		for r: int in rows:
			if c.y < r:
				shift += 1
		ng[Vector2i(c.x, c.y + shift)] = _grid[c]
	_grid = ng


func _surface_row(col: int) -> int:
	col = clampi(col, 0, COLS - 1)
	var lo := _rows
	for c: Vector2i in _grid:
		if c.x == col and c.y < lo:
			lo = c.y
	return lo


func _holes() -> int:
	var n := 0
	for col in COLS:
		var top := _surface_row(col)
		for r in range(top + 1, _rows):
			if not _grid.has(Vector2i(col, r)):
				n += 1
	return n


# --- 스테이지 모드 ------------------------------------------------------------


func _tick_classic(delta: float) -> void:
	match _state:
		0:
			if _t > 0.2:
				_spawn_classic()
		1:
			_track(delta)
			var cols := _foot_cols(_pt, _prot, _px)
			_target = (float(cols.min()) + float(cols.max())) / 2.0 + 0.5
			if _px == _goal_x and _prot == _goal_rot and _t > 0.75:
				_state = 2
				_t = 0.0
				_target = _dodge_target()
		2:
			var cols := _foot_cols(_pt, _prot, _px)
			var in_lane := false
			for col: int in cols:
				if absf(_cx - (col + 0.5)) < 0.5 + HALF:
					in_lane = true
			if (not in_lane and _ground) or _t > 1.1:
				_state = 3
				_t = 0.0
		3:
			_py += FALL_CLASSIC * delta
			var land := _drop_y(_pt, _prot, _px, 0)
			if _py >= land:
				_py = land
				_lock()
				_flash_rows = _full_rows()
				_state = 4 if not _flash_rows.is_empty() else 0
				_t = 0.0
		4:
			if _t >= FLASH_TIME:
				_clear_rows(_flash_rows)
				_flash_rows.clear()
				_shake = _cell * 0.25
				_state = 0
				_t = 0.0


func _spawn_classic() -> void:
	# 판이 너무 높아지면 셔터가 쓸어 가듯 새 판으로.
	var top := _rows
	for c: Vector2i in _grid:
		top = mini(top, c.y)
	_pt = _next_type()
	_prot = 0
	_px = clampi(int(_cx) - 1, 0, COLS - 3)
	_py = 0.0
	if top < 3 or not _fits(_pt, 0, _px, 0):
		_reset()
		return
	var best := -INF
	for rot in 4:
		for x in range(-2, COLS):
			var y := _drop_y(_pt, rot, x, 0)
			if y == -9999:
				continue
			var score := _eval_classic(_cells(_pt, rot, x, y)) + _rng.randf() * 0.4
			if score > best:
				best = score
				_goal_x = x
				_goal_rot = rot
	_state = 1
	_t = 0.0
	_step_t = 0.0
	_rot_t = 0.0


## 흔한 테트리스 봇 가중치 — 높이·구멍·울퉁불퉁함을 낮추고 줄 지우기를 좋아한다.
func _eval_classic(cells: Array) -> float:
	for c: Vector2i in cells:
		_grid[c] = "X"
	var lines := _full_rows().size()
	var agg := 0
	var bump := 0
	var prev := -1
	for col in COLS:
		var h := _rows - _surface_row(col)
		agg += h
		if prev >= 0:
			bump += absi(h - prev)
		prev = h
	var holes := _holes()
	for c: Vector2i in cells:
		_grid.erase(c)
	return -0.51 * agg + 0.9 * lines - 0.46 * holes - 0.18 * bump


## 조각이 떨어질 줄 밖, 오르내릴 수 있는 가장 가까운 칸.
func _dodge_target() -> float:
	var cols := _foot_cols(_pt, _prot, _px)
	var here := _surface_row(int(_cx))
	var best := _cx
	var best_d := INF
	for col in COLS:
		if col in cols:
			continue
		var d := absf(col + 0.5 - _cx) + absi(_surface_row(col) - here) * 0.6
		if d < best_d:
			best_d = d
			best = col + 0.5
	return best


## 추적 — 한 박자마다 한 칸씩, 회전도 한 번씩 목표로 다가간다.
func _track(delta: float) -> void:
	_step_t += delta
	_rot_t += delta
	while _rot_t >= ROT_STEP:
		_rot_t -= ROT_STEP
		if _prot != _goal_rot:
			var nr := (_prot + 1) % 4
			if _fits(_pt, nr, _px, int(_py)):
				_prot = nr
	while _step_t >= TRACK_STEP:
		_step_t -= TRACK_STEP
		var d := signi(_goal_x - _px)
		if d != 0 and _fits(_pt, _prot, _px + d, int(_py)):
			_px += d


# --- 무한의 계단 --------------------------------------------------------------


func _tick_endless(delta: float) -> void:
	var feet := _cy + HALF
	# 용암은 늘 차오르되 냥이 발밑에서 너무 멀어지지는 않는다.
	var rise := LAVA_RISE * (0.25 if _lava - feet < 2.5 else 1.0)
	_lava = minf(_lava - rise * delta, feet + LAVA_GAP)
	if _lava < feet - 0.2:
		_reset()
		return
	# 카메라 — 냥이를 화면 절반 높이에 둔다(바닥 아래로는 안 내려간다).
	var want := minf(_cy - _rows * 0.5, 0.0)
	_cam = lerpf(_cam, want, 1.0 - exp(-delta * 3.0))
	# 용암에 잠긴 칸은 버린다.
	for c: Vector2i in _grid.keys():
		if c.y > _lava + 2.0:
			_grid.erase(c)
	match _state:
		0:
			# 냥이가 자리를 잡은 뒤에 다음 조각 — 걸어가는 길에 조각이 떨어지지 않게.
			var settled := _ground and absf(_target - _cx) < 0.1
			if _t > 0.12 and (settled or _t > 2.0):
				_spawn_endless()
		1:
			_py = floorf(_cam) - 1.0
			_track(delta)
			if _px == _goal_x and _prot == _goal_rot and _t > 0.4:
				_state = 3
				_t = 0.0
		3:
			_py += FALL_ENDLESS * delta
			var land := _drop_y(_pt, _prot, _px, int(floorf(_cam)) - 4)
			if land == -9999 or _py >= land:
				if land != -9999:
					_py = land
					_lock()
					_target = _step_target()
				else:
					_pt = ""
				_state = 0
				_t = 0.0


func _cat_row() -> int:
	return int(floorf(_cy + HALF + 0.01))


func _spawn_endless() -> void:
	_pt = _next_type()
	_prot = 0
	_px = clampi(int(_cx) - 1, 0, COLS - 3)
	_py = floorf(_cam) - 1.0
	var cc := clampi(int(_cx), 0, COLS - 1)
	if cc <= 1:
		_dir = 1
	elif cc >= COLS - 2:
		_dir = -1
	var feet := _cat_row()  # 냥이가 딛고 선 칸의 줄
	var top_y := int(floorf(_cam)) - 4
	var best := -INF
	var found := false
	var cat_lo := int(floorf(_cx - HALF))
	var cat_hi := int(floorf(_cx + HALF))
	for rot in 4:
		for x in range(-2, COLS):
			var y := _drop_y(_pt, rot, x, top_y)
			if y == -9999:
				continue
			var cells := _cells(_pt, rot, x, y)
			var ok := true
			var mid := 0.0
			for c: Vector2i in cells:
				if c.x >= cat_lo and c.x <= cat_hi and c.y < feet:
					ok = false
				mid += c.x + 0.5
			if not ok:
				continue
			mid /= cells.size()
			# 밑이 빈 칸(처마)은 냥이가 머리를 박는 자리라 피한다.
			var eaves := 0
			for c: Vector2i in cells:
				var below := Vector2i(c.x, c.y + 1)
				if below.y < _rows and not _grid.has(below) and not below in cells:
					eaves += 1
			# 이 조각을 놓으면 냥이가 걸어서(두 칸 턱까지) 오를 수 있는 가장 높은 곳.
			for c: Vector2i in cells:
				_grid[c] = _pt
			var gain: int = feet - int(_best_reach(feet)[0])
			for c: Vector2i in cells:
				_grid.erase(c)
			var score := mini(gain, 3) * 3.0 - eaves * 2.5 					- absf(mid - (_cx + _dir * 2.2)) * 0.3 + _rng.randf() * 0.5
			if score > best:
				best = score
				_goal_x = x
				_goal_rot = rot
				found = true
	if not found:
		_goal_x = _px
		_goal_rot = 0
	_state = 1
	_t = 0.0
	_step_t = 0.0
	_rot_t = 0.0


## 열마다 맨 위 블록 줄 — 냥이 열은 발밑 줄. 두 칸 턱까지 오르내리며 닿는 열 중
## 가장 높은 곳 [줄, 열]을 돌려준다(같으면 가까운 쪽).
func _best_reach(feet: int) -> Array:
	var cc := clampi(int(_cx), 0, COLS - 1)
	var h: Array = []
	for col in COLS:
		h.append(_rows)
	for c: Vector2i in _grid:
		if c.x >= 0 and c.x < COLS and c.y < h[c.x] and c.y > feet - 8:
			h[c.x] = c.y
	h[cc] = feet
	var seen := _reach_cols(h, cc)
	var best_row := feet
	var best_col := cc
	for j: int in seen:
		var row: int = h[j]
		if row < best_row or (row == best_row and absi(j - cc) < absi(best_col - cc)):
			best_row = row
			best_col = j
	return [best_row, best_col, seen]


func _reach_cols(h: Array, cc: int) -> Dictionary:
	var seen := {cc: true}
	var queue := [cc]
	while not queue.is_empty():
		var i: int = queue.pop_front()
		for j in [i - 1, i + 1]:
			if j < 0 or j >= COLS or seen.has(j):
				continue
			# 두 칸 턱까지 오르고, 용암 쪽으로는 내려가지 않는다.
			if int(h[i]) - int(h[j]) <= 2 and float(h[j]) < _lava - 1.5:
				seen[j] = true
				queue.append(j)
	return seen


## 방금 떨어진 조각까지 쳐서, 걸어 오를 수 있는 가장 높은 칸.
func _step_target() -> float:
	var feet := _cat_row()
	var r := _best_reach(feet)
	var cc := clampi(int(_cx), 0, COLS - 1)
	if int(r[0]) < feet:
		return int(r[1]) + 0.5
	# 오를 데가 없다 — 가던 쪽으로 두세 칸 옮겨 다음 조각이 놓일 자리를 튼다.
	var seen: Dictionary = r[2]
	for tries in 2:
		for step in [3, 2, 1]:
			var j: int = cc + _dir * step
			if seen.has(j):
				return j + 0.5
		_dir = -_dir
	return _cx


# --- 냥이 --------------------------------------------------------------------


func _solid(c: int, r: int) -> bool:
	return c < 0 or c >= COLS or r >= _rows or _grid.has(Vector2i(c, r))


func _cat_hits(x: float, y: float) -> bool:
	for c in range(int(floorf(x - HALF + 0.001)), int(floorf(x + HALF - 0.001)) + 1):
		for r in range(int(floorf(y - HALF + 0.001)), int(floorf(y + HALF - 0.001)) + 1):
			if _solid(c, r):
				return true
	return false


func _tick_cat(delta: float) -> void:
	var dx := _target - _cx
	_vx = clampf(dx * 8.0, -WALK, WALK) if absf(dx) > 0.04 else 0.0
	if absf(_vx) > 0.2:
		_look = signf(_vx)
	# 가로.
	var nx := _cx + _vx * delta
	if _cat_hits(nx, _cy):
		# 앞이 막혔다 — 두 칸 안쪽 턱이면 뛰어오른다.
		if _ground and _vx != 0.0:
			var ahead := int(floorf(_cx + signf(_vx) * (HALF + 0.3)))
			var row := _cat_row()
			if not _solid(ahead, row - 3) and not _cat_hits(_cx, _cy - 0.3):
				_vy = -JUMP_V
				_ground = false
			else:
				_target = _cx
	else:
		_cx = nx
	# 세로.
	_vy = minf(_vy + GRAVITY * delta, 30.0)
	var ny := _cy + _vy * delta
	if _cat_hits(_cx, ny):
		if _vy > 0.0:
			var snapped := floorf(ny + HALF) - HALF
			if not _cat_hits(_cx, snapped):
				ny = snapped
			else:
				ny = _cy
			if not _ground and _vy > 6.0:
				_squash = 1.0
			_ground = true
		else:
			ny = _cy
		_vy = 0.0
	else:
		_ground = false
	_cy = ny


# --- 그리기 -------------------------------------------------------------------


func _row_y(r: float) -> float:
	return size.y - (_rows - (r - _cam)) * _cell


func _col(c: Color) -> Color:
	if on:
		return c
	var g := c.get_luminance()
	return Color(g, g, g).lerp(c, 0.35).darkened(0.1)


func _draw() -> void:
	var off := Vector2(0.0, _shake * sin(_t * 70.0))
	if mode == GameState.MODE_ENDLESS:
		_draw_sky()
	# 격자.
	var line := Color(1, 1, 1, 0.05)
	for c in COLS + 1:
		draw_line(Vector2(c * _cell, 0.0), Vector2(c * _cell, size.y), line)
	var r0 := int(floorf(_cam)) - 1
	for r in range(r0, r0 + _rows + 3):
		var y := _row_y(r) + off.y
		draw_line(Vector2(0.0, y), Vector2(size.x, y), line)
	# 쌓인 블록.
	for c: Vector2i in _grid:
		var y := _row_y(c.y) + off.y
		if y > size.y or y < -_cell:
			continue
		_block(Vector2(c.x * _cell, y), Board.COLORS[_grid[c]])
	# 줄 섬광.
	for r: int in _flash_rows:
		var a := 1.0 - _t / FLASH_TIME
		draw_rect(Rect2(0.0, _row_y(r) + off.y, size.x, _cell), Color(1, 1, 1, 0.75 * a))
	# 떨어지는 조각 + 착지 예상 자리.
	if _pt != "":
		if mode == GameState.MODE_CLASSIC and _state != 3:
			var gy := _drop_y(_pt, _prot, _px, int(_py))
			if gy != -9999:
				for c: Vector2i in _cells(_pt, _prot, _px, gy):
					var gr := Rect2(c.x * _cell + 3.0, _row_y(c.y) + off.y + 3.0,
							_cell - 6.0, _cell - 6.0)
					draw_rect(gr, Color(_col(Board.COLORS[_pt]), 0.28), false, 2.0)
		for c: Vector2i in Board.SHAPES[_pt][_prot]:
			_block(Vector2((_px + c.x) * _cell, _row_y(_py + c.y) + off.y),
					Board.COLORS[_pt])
	# 냥이.
	var s := _cell * 0.95
	var feet := Vector2(_cx * _cell, _row_y(_cy + HALF) + off.y)
	var sq := _squash * 0.18
	draw_set_transform(feet, 0.0, Vector2(1.0 + sq, 1.0 - sq))
	Player.paint_cat(self, Vector2(0.0, -s * 0.5), s, _look * 0.6, true, not _ground, skin)
	draw_set_transform(Vector2.ZERO)
	if mode == GameState.MODE_ENDLESS:
		_draw_lava(off.y)
	if not on:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.35, 0.35, 0.35))


## 무한의 계단 — 오를수록 구덩이가 조금씩 밝아진다.
func _draw_sky() -> void:
	var lift := clampf(-_cam / 80.0, 0.0, 0.35)
	var base := UiKit.NAVY if on else Color("5a5a5a")
	draw_rect(Rect2(Vector2.ZERO, size), base.lerp(Color("6f8fd8"), lift))


func _draw_lava(oy: float) -> void:
	var y := _row_y(_lava) + oy
	if y >= size.y - _cell * 0.1:
		return
	var body := _col(Color("e0552f"))
	var pts := PackedVector2Array()
	var n := 20
	for i in n + 1:
		var x := size.x * i / n
		pts.append(Vector2(x, minf(y + sin(_t * 3.0 + i * 0.9) * _cell * 0.08, size.y)))
	var poly := pts.duplicate()
	poly.append(Vector2(size.x, size.y + 4.0))
	poly.append(Vector2(0.0, size.y + 4.0))
	draw_colored_polygon(poly, body)
	draw_polyline(pts, _col(Color("ffd166")), maxf(_cell * 0.12, 3.0))


## 블록 한 칸 — escape_board.gd `_draw_block`과 같은 모양(둥근 판 + 짙은 테두리 + 윗면 빛).
func _block(p: Vector2, color: Color) -> void:
	color = _col(color)
	var key := color.to_rgba32()
	if not _sb_cache.has(key):
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(int(_cell * 0.2))
		sb.set_border_width_all(maxi(int(_cell * 0.05), 2))
		sb.border_color = color.darkened(0.45)
		var hi := StyleBoxFlat.new()
		hi.bg_color = Color(1.0, 1.0, 1.0, 0.4)
		hi.set_corner_radius_all(int(_cell * 0.12))
		_sb_cache[key] = [sb, hi]
	var pair: Array = _sb_cache[key]
	var inset := maxf(_cell * 0.03, 1.0)
	draw_style_box(pair[0], Rect2(p + Vector2(inset, inset), Vector2(_cell - inset * 2.0,
			_cell - inset * 2.0)))
	draw_style_box(pair[1], Rect2(p + Vector2(_cell * 0.14, _cell * 0.11),
			Vector2(_cell * 0.72, _cell * 0.18)))
