extends Control
## NEXT 카드에서 우물 위로 넘어오는 블록 조각. main.gd가 화면 좌표 두 점을 주면
## 그 사이를 짧게 날아가며 작아진다 — "예고하던 그 블록이 지금 들어왔다"를
## 눈에 붙이는 연출이라, 게임 상태는 하나도 건드리지 않는다.
## class_name 없음 — preload로 참조한다.

const UiKit := preload("res://core/scripts/ui_kit.gd")

const FLY_TIME := 0.34
const MINI := 26.0  # 출발할 때 한 칸 크기 (NEXT 카드의 미리보기와 맞춘 값)
const ARC := 70.0  # 포물선으로 떠오르는 높이

var _flights: Array = []  # [type, from, to, age]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)


## 화면 좌표 from → to 로 블록 하나를 날린다.
func launch(type: String, from: Vector2, to: Vector2) -> void:
	if type == "" or not Board.SHAPES.has(type):
		return
	_flights.append([type, from, to, 0.0])
	set_process(true)


func _process(delta: float) -> void:
	for f in _flights:
		f[3] += delta
	_flights = _flights.filter(func(f: Array) -> bool: return f[3] < FLY_TIME)
	if _flights.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for f in _flights:
		var t: float = clampf(float(f[3]) / FLY_TIME, 0.0, 1.0)
		var e := ease(t, 0.45)
		var at: Vector2 = (f[1] as Vector2).lerp(f[2] as Vector2, e)
		at.y -= ARC * sin(PI * t)  # 살짝 떠올랐다 우물 위로 내려앉는다
		_draw_mini(f[0], at, MINI * lerpf(1.0, 0.6, e), 1.0 - ease(t, 2.4))


## 도형 하나를 at 중심으로 작게 그린다 (타이틀 로고와 같은 통통한 블록).
func _draw_mini(type: String, at: Vector2, cell: float, alpha: float) -> void:
	var cells: Array = Board.SHAPES[type][0]
	var minc := Vector2i(9, 9)
	var maxc := Vector2i(-9, -9)
	for c: Vector2i in cells:
		minc = minc.min(c)
		maxc = maxc.max(c)
	var span := Vector2(maxc - minc + Vector2i.ONE)
	var origin := at - span * cell / 2.0 - Vector2(minc) * cell
	var col: Color = Board.COLORS[type]
	col.a = alpha
	# 날아가는 조각을 감싸는 잔광.
	draw_circle(at, cell * 1.6, Color(1.0, 0.98, 0.88, 0.16 * alpha))
	# UiKit.block은 외곽선 알파를 받지 않아 페이드가 걸리지 않는다 — 같은 모양을
	# 알파까지 실어 직접 그린다(둥근 모서리 + 잉크 외곽선 + 윗면 하이라이트).
	for c: Vector2i in cells:
		var r := Rect2(origin + Vector2(c) * cell + Vector2.ONE,
				Vector2.ONE * (cell - 2.0))
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(int(cell * 0.22))
		sb.set_border_width_all(maxi(2, int(cell * 0.11)))
		sb.border_color = Color(UiKit.INK, alpha)
		draw_style_box(sb, r)
		draw_rect(Rect2(r.position + Vector2(cell * 0.22, cell * 0.16),
				Vector2(cell * 0.56, cell * 0.13)), Color(1, 1, 1, 0.45 * alpha))
