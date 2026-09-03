class_name TouchButton
extends Control
## 화면 위 액션 버튼(점프·회전·낙하·일시정지). 컨셉 키트와 같은 통통한 베벨
## 버튼으로 그리고, 손가락마다 터치 index를 따로 기억해 여러 버튼이 동시에
## 먹는다(멀티터치). 액션은 InputEventAction으로 흘려보내서 `Input.is_action_*`
## 뿐 아니라 `_unhandled_input`의 `is_action_pressed()`(일시정지)도 받는다.

const UiKit := preload("res://core/scripts/ui_kit.gd")

const BEVEL := 10.0  # 아래 두께감 — 눌리면 그만큼 내려앉는다
const HIT_MARGIN := 12.0  # 손가락이 조금 빗나가도 잡아 주는 여유
const RING_TIME := 0.28  # 누를 때 퍼지는 링

@export var action := ""
@export var label := ""  # 아이콘 아래 작은 글자의 번역 키 (비우면 아이콘만)
@export var font_size := 26
@export_enum("none", "jump", "rotate", "drop", "pause", "title") var icon := "none"
@export var accent: Color = Color("ffffff")  # 버튼 얼굴색
@export var deep: Color = Color("c9c6d0")  # 아래 베벨색
@export var round := true  # 원형 (false = 둥근 사각)
## 옆에서 미끄러져 들어온 손가락도 누르는가. 이동 패드는 그래야 자연스럽지만
## 액션 버튼은 엄지가 흘러 옆 버튼을 잘못 누르는 일이 잦아 기본은 끈다.
@export var slide_in := false

var touch_index := -1
var _ring := 0.0  # 1 → 0으로 줄며 링이 퍼진다


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1 and _hit(event.position):
			_press(event.index)
		elif not event.pressed and event.index == touch_index:
			_release()
	elif event is InputEventScreenDrag:
		var inside := _hit(event.position)
		if event.index == touch_index and not inside:
			_release()
		elif slide_in and touch_index == -1 and inside:
			_press(event.index)


func _hit(p: Vector2) -> bool:
	var r := get_global_rect()
	if round:
		var rad := minf(r.size.x, r.size.y) / 2.0 + HIT_MARGIN
		return p.distance_to(r.get_center()) <= rad
	return r.grow(HIT_MARGIN).has_point(p)


func _press(index: int) -> void:
	touch_index = index
	_send(true)
	_ring = 1.0
	set_process(true)
	queue_redraw()


func _release() -> void:
	touch_index = -1
	_send(false)
	queue_redraw()


func _send(pressed: bool) -> void:
	if action == "":
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _process(delta: float) -> void:
	_ring = maxf(_ring - delta / RING_TIME, 0.0)
	if _ring <= 0.0:
		set_process(false)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_EXIT_TREE:
		if touch_index != -1:
			_release()


# --- 그리기 --------------------------------------------------------------------


func _draw() -> void:
	var down := touch_index != -1
	var body := Rect2(Vector2.ZERO, Vector2(size.x, size.y - BEVEL))
	var face := accent.darkened(0.08) if down else accent
	var lift := BEVEL if down else 0.0
	# 아래 두께 → 얼굴 → 잉크 외곽선. 눌리면 두께가 접히며 얼굴이 내려앉는다.
	if not down:
		_shape(body.position + Vector2(0.0, BEVEL), body.size, deep, true)
	_shape(body.position + Vector2(0.0, lift), body.size, face, true)
	_shape(body.position + Vector2(0.0, lift), body.size, UiKit.INK, false)
	# 누를 때 퍼지는 링 — 손가락이 먹었다는 확인.
	if _ring > 0.0:
		var c := body.get_center() + Vector2(0.0, lift)
		var rr := minf(body.size.x, body.size.y) / 2.0 * (1.0 + (1.0 - _ring) * 0.45)
		draw_arc(c, rr, 0.0, TAU, 48, Color(UiKit.WHITE, _ring * 0.7), 6.0, true)
	_draw_icon(body.get_center() + Vector2(0.0, lift), minf(body.size.x, body.size.y))


func _shape(at: Vector2, sz: Vector2, col: Color, filled: bool) -> void:
	if round:
		var c := at + sz / 2.0
		var r := minf(sz.x, sz.y) / 2.0
		if filled:
			draw_circle(c, r, col)
		else:
			draw_arc(c, r - UiKit.BORDER / 2.0, 0.0, TAU, 64, col, UiKit.BORDER, true)
		return
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(minf(sz.x, sz.y) * 0.28))
	if filled:
		sb.bg_color = col
	else:
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(UiKit.BORDER)
		sb.border_color = col
	draw_style_box(sb, Rect2(at, sz))


## 아이콘은 글리프 대신 도형으로 그린다 — 폰트마다 ⟳·▲ 모양이 달라 보이는
## 것을 피하고, 잉크 외곽선 컨셉과 같은 선 굵기로 맞춘다.
func _draw_icon(c: Vector2, d: float) -> void:
	var ink := UiKit.INK
	var has_label := label != ""
	var s := d * (0.26 if has_label else 0.36)  # 아이콘 반지름
	var ic := c + Vector2(0.0, -d * 0.13 if has_label else 0.0)  # 글자 자리를 비워 위로
	var w := maxf(d * 0.075, 6.0)
	match icon:
		"jump":
			# 위로 솟는 화살표 + 아래 작은 착지선 두 줄
			var head := PackedVector2Array([ic + Vector2(0.0, -s), ic + Vector2(-s * 0.85, -s * 0.15),
					ic + Vector2(s * 0.85, -s * 0.15)])
			draw_colored_polygon(head, ink)
			draw_line(ic + Vector2(0.0, -s * 0.2), ic + Vector2(0.0, s * 0.55), ink, w * 1.6)
			draw_line(ic + Vector2(-s * 0.5, s * 0.95), ic + Vector2(s * 0.5, s * 0.95), ink, w * 0.9)
		"rotate":
			# 270도 원호 + 화살촉
			var r := s * 0.75
			draw_arc(ic, r, deg_to_rad(-60.0), deg_to_rad(210.0), 32, ink, w * 1.3, true)
			var tip_ang := deg_to_rad(-60.0)
			var tip := ic + Vector2(cos(tip_ang), sin(tip_ang)) * r
			var tang := Vector2(-sin(tip_ang), cos(tip_ang))  # 원호 진행 방향(-)
			var head := PackedVector2Array([tip + tang * -s * 0.42,
					tip + tang.rotated(PI / 2.0) * s * 0.34, tip + tang.rotated(-PI / 2.0) * s * 0.34])
			draw_colored_polygon(head, ink)
		"drop":
			# 아래로 떨어지는 화살표 + 바닥선 (⤓)
			draw_line(ic + Vector2(0.0, -s * 0.9), ic + Vector2(0.0, s * 0.05), ink, w * 1.6)
			var head := PackedVector2Array([ic + Vector2(0.0, s * 0.55), ic + Vector2(-s * 0.8, -s * 0.2),
					ic + Vector2(s * 0.8, -s * 0.2)])
			draw_colored_polygon(head, ink)
			draw_line(ic + Vector2(-s * 0.85, s * 0.95), ic + Vector2(s * 0.85, s * 0.95), ink, w * 1.1)
		"pause":
			var bw := s * 0.34
			for k: float in [-1.0, 1.0]:
				var x: float = ic.x + k * s * 0.42 - bw / 2.0
				var sb := StyleBoxFlat.new()
				sb.bg_color = ink
				sb.set_corner_radius_all(int(bw * 0.35))
				draw_style_box(sb, Rect2(Vector2(x, ic.y - s * 0.8), Vector2(bw, s * 1.6)))
		"title":
			# 집 모양 — 타이틀로
			var roof := PackedVector2Array([ic + Vector2(0.0, -s * 0.95), ic + Vector2(-s, s * 0.05),
					ic + Vector2(s, s * 0.05)])
			draw_colored_polygon(roof, ink)
			draw_rect(Rect2(ic + Vector2(-s * 0.62, 0.0), Vector2(s * 1.24, s * 0.9)), ink)
	if has_label:
		var font := ThemeDB.fallback_font
		var text := tr(label)
		var fs := UiKit.fit_size(font, text, d * 0.8, font_size, 14)
		var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var pos := Vector2(c.x - ts.x / 2.0, c.y + d * 0.33 + ts.y * 0.35)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
