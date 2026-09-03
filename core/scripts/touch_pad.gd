extends Control
## 좌우 이동 패드 — ◀ ▶ 두 칸이 붙은 알약 하나. 엄지를 떼지 않고 왼쪽 반에서
## 오른쪽 반으로 미끄러지면 방향이 바로 바뀌고(격투 게임의 슬라이드 패드),
## 한 번 잡힌 손가락은 패드 밖으로 흘러도 **놓기 전까지 붙잡는다** — 화면을
## 안 보고 누르는 자리라 조금 빗나가도 이동이 끊기면 안 된다. 같은 쪽을 두 번
## 두드리면 그대로 대시(`player.gd`의 더블탭)가 된다.

const UiKit := preload("res://core/scripts/ui_kit.gd")

const BEVEL := 10.0
const HIT_MARGIN := 16.0
const ACTIONS := {-1: "move_left", 1: "move_right"}

## 터치 index → 방향(-1/1). 손가락 둘이 양쪽을 따로 누를 수도 있다.
var _touches: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not _touches.has(event.index) and _hit(event.position):
			_set_dir(event.index, _dir_at(event.position))
		elif not event.pressed and _touches.has(event.index):
			_set_dir(event.index, 0)
	elif event is InputEventScreenDrag:
		if _touches.has(event.index):
			_set_dir(event.index, _dir_at(event.position))
		elif _hit(event.position):
			_set_dir(event.index, _dir_at(event.position))


func _hit(p: Vector2) -> bool:
	return get_global_rect().grow(HIT_MARGIN).has_point(p)


func _dir_at(p: Vector2) -> int:
	return -1 if p.x < get_global_rect().get_center().x else 1


## 손가락 하나의 방향을 갱신한다. 방향이 바뀌면 이전 액션을 놓고 새 액션을 누른다
## (다른 손가락이 아직 그쪽을 누르고 있으면 놓지 않는다).
func _set_dir(index: int, dir: int) -> void:
	var prev: int = _touches.get(index, 0)
	if prev == dir:
		return
	if dir == 0:
		_touches.erase(index)
	else:
		_touches[index] = dir
	if prev != 0 and not _held(prev):
		_send(ACTIONS[prev], false)
	if dir != 0 and _count(dir) == 1:
		_send(ACTIONS[dir], true)
	queue_redraw()


func _held(dir: int) -> bool:
	return _count(dir) > 0


func _count(dir: int) -> int:
	var n := 0
	for d: int in _touches.values():
		if d == dir:
			n += 1
	return n


func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_EXIT_TREE:
		for i: int in _touches.keys():
			_set_dir(i, 0)


# --- 그리기 --------------------------------------------------------------------


func _draw() -> void:
	var h := size.y - BEVEL
	var r := h / 2.0
	var w := size.x
	# 아래 두께 → 흰 알약 → 눌린 반쪽 → 잉크 외곽선.
	_pill(Vector2(0.0, BEVEL), w, h, UiKit.INK.lerp(UiKit.WHITE, 0.72))
	_pill(Vector2.ZERO, w, h, UiKit.WHITE)
	for dir: int in [-1, 1]:
		if _held(dir):
			_half(dir, w, h, UiKit.ORANGE)
	_pill_outline(Vector2.ZERO, w, h, UiKit.INK)
	# 가운데 구분선
	draw_line(Vector2(w / 2.0, h * 0.22), Vector2(w / 2.0, h * 0.78),
			Color(UiKit.INK, 0.25), 3.0)
	# ◀ ▶ 화살표
	var s := h * 0.24
	for dir: int in [-1, 1]:
		var c := Vector2(w / 2.0 + dir * w * 0.25, h / 2.0)
		var col := UiKit.INK
		var tri := PackedVector2Array([c + Vector2(dir * s, 0.0), c + Vector2(-dir * s * 0.7, -s * 0.9),
				c + Vector2(-dir * s * 0.7, s * 0.9)])
		draw_colored_polygon(tri, col)


## 알약(양 끝이 반원인 가로 막대)을 채운다.
func _pill(at: Vector2, w: float, h: float, col: Color) -> void:
	var r := h / 2.0
	draw_circle(at + Vector2(r, r), r, col)
	draw_circle(at + Vector2(w - r, r), r, col)
	draw_rect(Rect2(at + Vector2(r, 0.0), Vector2(w - h, h)), col)


func _pill_outline(at: Vector2, w: float, h: float, col: Color) -> void:
	var r := h / 2.0
	var bw := float(UiKit.BORDER)
	var ri := r - bw / 2.0
	draw_arc(at + Vector2(r, r), ri, PI / 2.0, PI * 1.5, 24, col, bw, true)
	draw_arc(at + Vector2(w - r, r), ri, -PI / 2.0, PI / 2.0, 24, col, bw, true)
	draw_line(at + Vector2(r, bw / 2.0), at + Vector2(w - r, bw / 2.0), col, bw)
	draw_line(at + Vector2(r, h - bw / 2.0), at + Vector2(w - r, h - bw / 2.0), col, bw)


## 알약의 왼쪽/오른쪽 반만 색을 채운다 (눌린 쪽).
func _half(dir: int, w: float, h: float, col: Color) -> void:
	var r := h / 2.0
	if dir == -1:
		draw_circle(Vector2(r, r), r, col)
		draw_rect(Rect2(Vector2(r, 0.0), Vector2(w / 2.0 - r, h)), col)
	else:
		draw_circle(Vector2(w - r, r), r, col)
		draw_rect(Rect2(Vector2(w / 2.0, 0.0), Vector2(w / 2.0 - r, h)), col)
