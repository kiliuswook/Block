extends Control
## NEXT 판 (피그마 "게임 플레이"): 흰 계기판 카드 위의 남색 둥근 판 안에 다음 블록.

const UiKit := preload("res://core/scripts/ui_kit.gd")
const MINI := 40.0
const POP_TIME := 0.28  # 새 블록이 들어왔을 때 튀는 시간

var next_type := ""
var _pop := 0.0  # 1 → 0 으로 잦아드는 팝


func _ready() -> void:
	set_process(false)
	EventBus.next_piece_changed.connect(func(t: String) -> void:
		next_type = t
		_pop = 1.0
		set_process(true)
		queue_redraw())


func _process(delta: float) -> void:
	_pop = maxf(_pop - delta / POP_TIME, 0.0)
	if _pop <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	UiKit.round_rect(self, Rect2(Vector2.ZERO, size), UiKit.NAVY, 16)
	if next_type == "":
		return
	var cells: Array = Board.SHAPES[next_type][0]
	var minc := Vector2i(9, 9)
	var maxc := Vector2i(-9, -9)
	for c in cells:
		minc = minc.min(c)
		maxc = maxc.max(c)
	var span := Vector2(maxc - minc + Vector2i.ONE)
	var mini := minf(MINI, minf((size.x - 30.0) / span.x, (size.y - 30.0) / span.y))
	var origin := size / 2.0 - span * mini / 2.0 - Vector2(minc) * mini
	var color: Color = Board.COLORS[next_type]
	var grow := 1.0 + 0.18 * ease(_pop, 0.4)
	draw_set_transform(size / 2.0, 0.0, Vector2(grow, grow))
	for c in cells:
		var p: Vector2 = origin + Vector2(c) * mini - size / 2.0
		UiKit.block(self, Rect2(p + Vector2(2.0, 2.0), Vector2.ONE * (mini - 4.0)),
				color, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _pop > 0.0:
		UiKit.round_rect(self, Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 0.95, 0.25 * _pop), 16)
