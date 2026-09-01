extends Control
## HUD panel showing the next tetromino, in the title screen's UI tone:
## a sky-tinted groove with a thick ink outline, blocks drawn by the UI kit.

const UiKit := preload("res://core/scripts/ui_kit.gd")
const MINI := 30.0
const POP_TIME := 0.28  # 새 블록이 들어왔을 때 튀는 시간

var next_type := ""
var _pop := 0.0  # 1 → 0 으로 잦아드는 팝


func _ready() -> void:
	set_process(false)
	EventBus.next_piece_changed.connect(func(t: String) -> void:
		next_type = t
		# 예고가 바뀐 순간을 눈에 붙인다 — 카드가 한 번 부풀었다 가라앉는다.
		_pop = 1.0
		set_process(true)
		queue_redraw())


func _process(delta: float) -> void:
	_pop = maxf(_pop - delta / POP_TIME, 0.0)
	if _pop <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	# 홈(groove): 흰 계기판 카드 위에 얹히는 하늘색 우묵한 자리.
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(UiKit.SKY, 0.55)
	groove.set_corner_radius_all(14)
	groove.set_border_width_all(3)
	groove.border_color = UiKit.INK
	draw_style_box(groove, Rect2(Vector2.ZERO, size))
	if next_type == "":
		return
	var cells: Array = Board.SHAPES[next_type][0]
	var minc := Vector2i(9, 9)
	var maxc := Vector2i(-9, -9)
	for c in cells:
		minc = minc.min(c)
		maxc = maxc.max(c)
	var span := Vector2(maxc - minc + Vector2i.ONE)
	var origin := size / 2.0 - span * MINI / 2.0 - Vector2(minc) * MINI
	var color: Color = Board.COLORS[next_type]
	# 팝: 가운데를 축으로 잠깐 부풀고, 홈 전체에 흰 섬광이 얹힌다.
	var grow := 1.0 + 0.22 * ease(_pop, 0.4)
	draw_set_transform(size / 2.0, 0.0, Vector2(grow, grow))
	for c in cells:
		var p: Vector2 = origin + Vector2(c) * MINI - size / 2.0
		# 타이틀 로고와 같은 블록: 둥근 모서리 + 잉크 외곽선 + 윗면 하이라이트.
		UiKit.block(self, Rect2(p + Vector2.ONE, Vector2.ONE * (MINI - 2.0)),
				color, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _pop > 0.0:
		var flash := StyleBoxFlat.new()
		flash.bg_color = Color(1.0, 1.0, 0.95, 0.35 * _pop)
		flash.set_corner_radius_all(14)
		draw_style_box(flash, Rect2(Vector2.ZERO, size))
