extends Control
## Full-screen replay player for recorded runs (see EscapeBoard.rec_export()).
## Renders the pit, grid, piece and cat from 10Hz state frames + grid-diff
## events. Endless replays scroll with the cat; fixed pits show whole wells.
## Built in code, viewport-relative — serves landscape and portrait alike.

const CREAM := Color("f4e3c8")
const STRIDE := 8
const STEP := 0.1  # seconds per recorded frame

var data := {}
var title_text := ""
var frame_pos := 0.0  # fractional frame cursor
var playing_back := false
var speed := 1.0
var grid := {}  # rebuilt from diff events during playback
var _ev_i := 0
var _canvas: Control
var _play_btn: Button
var _speed_btn: Button
var _info: Label
var _progress: HSlider
var _dragging := false


func _ready() -> void:
	visible = false
	# Plain position+size (no anchors): sized to the viewport on open() —
	# full-rect anchors under a CanvasLayer resolved to a zero rect here.
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_replay)
	add_child(_canvas)
	var vp := get_viewport_rect().size if get_viewport() else Vector2(1920, 1080)
	_info = Label.new()
	_info.position = Vector2(0.0, 24.0)
	_info.size = Vector2(vp.x, 40.0)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 26)
	_info.add_theme_color_override("font_color", CREAM)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info.add_theme_constant_override("outline_size", 8)
	add_child(_info)
	# Control bar along the bottom.
	var bar_y := vp.y - 96.0
	_play_btn = _bar_button("⏸", Vector2(vp.x / 2.0 - 260.0, bar_y), 90.0)
	_play_btn.pressed.connect(func() -> void:
		playing_back = not playing_back
		if frame_pos >= _frame_count() - 1:
			_seek(0.0)
			playing_back = true
		_sync_buttons())
	_speed_btn = _bar_button("x1", Vector2(vp.x / 2.0 - 150.0, bar_y), 90.0)
	_speed_btn.pressed.connect(func() -> void:
		speed = 2.0 if speed == 1.0 else (4.0 if speed == 2.0 else 1.0)
		_sync_buttons())
	var close := _bar_button("닫기", Vector2(vp.x / 2.0 + 170.0, bar_y), 120.0)
	close.pressed.connect(func() -> void:
		playing_back = false
		visible = false)
	_progress = HSlider.new()
	_progress.position = Vector2(vp.x / 2.0 - 40.0, bar_y + 14.0)
	_progress.size = Vector2(190.0, 32.0)
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.step = 0.001
	_progress.drag_started.connect(func() -> void: _dragging = true)
	_progress.drag_ended.connect(func(_ch: bool) -> void:
		_seek(_progress.value * maxf(_frame_count() - 1, 1.0))
		_dragging = false)
	add_child(_progress)


func _bar_button(text: String, pos: Vector2, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(w, 60.0)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_child(b)
	return b


func open(replay: Dictionary, header: String) -> void:
	if replay.is_empty() or not replay.has("frames"):
		return
	# Anchors under a CanvasLayer can resolve to a zero rect before the first
	# layout pass — pin the overlay to the viewport explicitly.
	position = Vector2.ZERO
	size = get_viewport_rect().size
	data = replay
	title_text = header
	speed = 1.0
	_seek(0.0)
	playing_back = true
	visible = true
	_sync_buttons()


func _sync_buttons() -> void:
	_play_btn.text = "⏸" if playing_back else "▶"
	_speed_btn.text = "x%d" % int(speed)


func _frame_count() -> int:
	return (data.get("frames", PackedInt32Array()) as PackedInt32Array).size() / STRIDE


## Rebuild the grid from scratch up to the target frame (events are sparse
## and cheap, so a backward seek just replays them all).
func _seek(to_frame: float) -> void:
	frame_pos = clampf(to_frame, 0.0, maxf(_frame_count() - 1, 0.0))
	grid = {}
	_ev_i = 0
	_apply_events()


func _apply_events() -> void:
	var events: Array = data.get("events", [])
	while _ev_i < events.size() and int(events[_ev_i].get("f", 0)) <= int(frame_pos):
		var e: Dictionary = events[_ev_i]
		var dels: PackedInt32Array = e.get("d", PackedInt32Array())
		for i in range(0, dels.size(), 2):
			grid.erase(Vector2i(dels[i], dels[i + 1]))
		var adds: PackedInt32Array = e.get("a", PackedInt32Array())
		for i in range(0, adds.size(), 3):
			grid[Vector2i(adds[i], adds[i + 1])] = adds[i + 2]
		_ev_i += 1


func _process(delta: float) -> void:
	if not visible or data.is_empty():
		return
	if playing_back and not _dragging:
		frame_pos += delta * speed / STEP
		if frame_pos >= _frame_count() - 1:
			frame_pos = _frame_count() - 1
			playing_back = false
			_sync_buttons()
		_apply_events()
		_progress.set_value_no_signal(frame_pos / maxf(_frame_count() - 1, 1.0))
	_canvas.queue_redraw()


func _fr(idx: int, off: int) -> int:
	var frames: PackedInt32Array = data.get("frames", PackedInt32Array())
	return frames[idx * STRIDE + off]


func _draw_replay() -> void:
	if data.is_empty() or _frame_count() == 0:
		return
	var f := int(frame_pos)
	var t := frame_pos - f
	var f2: int = mini(f + 1, _frame_count() - 1)
	var vp := _canvas.get_rect().size
	var rows := int(data.get("rows", 20))
	var mode := int(data.get("mode", 0))
	var endless := mode == 1
	var cat_pos := Vector2(lerpf(_fr(f, 0), _fr(f2, 0), t), lerpf(_fr(f, 1), _fr(f2, 1), t))
	# View transform: fixed pits fit whole; endless follows the cat vertically.
	var cell := 64.0
	var scale_f: float
	var origin: Vector2
	if endless:
		scale_f = minf((vp.y - 160.0) / (14.0 * cell), 0.9)
		origin = Vector2((vp.x - 10.0 * cell * scale_f) / 2.0,
				vp.y * 0.55 - cat_pos.y * scale_f)
	else:
		scale_f = minf((vp.y - 190.0) / (rows * cell), 1.0)
		origin = Vector2((vp.x - 10.0 * cell * scale_f) / 2.0,
				(vp.y - rows * cell * scale_f) / 2.0 + 12.0)
	var cs := cell * scale_f
	# Pit backdrop + walls.
	var w := 10.0 * cs
	var pit_top := origin.y if not endless else origin.y - 40.0 * cs
	var pit_h := rows * cs + (40.0 * cs if endless else 0.0)
	_canvas.draw_rect(Rect2(origin.x, pit_top, w, rows * cs - (pit_top - origin.y)),
			Color("14161f"))
	_canvas.draw_rect(Rect2(origin.x - 2, pit_top, 2, pit_h), Color(1, 1, 1, 0.25))
	_canvas.draw_rect(Rect2(origin.x + w, pit_top, 2, pit_h), Color(1, 1, 1, 0.25))
	_canvas.draw_rect(Rect2(origin.x - 2, origin.y + rows * cs, w + 4, 3), Color(1, 1, 1, 0.3))
	# Locked cells.
	for c: Vector2i in grid:
		var col: Color = Board.COLORS[Board.PIECES[clampi(int(grid[c]), 0, 6)]]
		var p := origin + Vector2(c) * cs
		_canvas.draw_rect(Rect2(p + Vector2.ONE, Vector2(cs - 2, cs - 2)), col)
		_canvas.draw_rect(Rect2(p + Vector2.ONE, Vector2(cs - 2, cs - 1) * Vector2(1, 0.16)),
				Color(1, 1, 1, 0.18))
	# Active piece (tracking pieces hover translucent, like in game).
	var ptype := _fr(f, 2)
	if ptype >= 0:
		var pcol: Color = Board.COLORS[Board.PIECES[ptype]]
		if _fr(f, 6) == 0:  # PieceState.TRACKING
			pcol.a = 0.45
		for c: Vector2i in Board.SHAPES[Board.PIECES[ptype]][clampi(_fr(f, 3), 0, 3)]:
			var p := origin + Vector2(Vector2i(_fr(f, 4), _fr(f, 5)) + c) * cs
			_canvas.draw_rect(Rect2(p + Vector2.ONE, Vector2(cs - 2, cs - 2)), pcol)
	# Lava (endless).
	if endless:
		var lava_y: float = lerpf(_fr(f, 7), _fr(f2, 7), t) * scale_f + origin.y
		if lava_y < vp.y:
			_canvas.draw_rect(Rect2(origin.x, lava_y, w, vp.y - lava_y), Color("c94f2a", 0.9))
			_canvas.draw_rect(Rect2(origin.x, lava_y - 3.0, w, 6.0), Color("f6b04c"))
	# The cat, wearing the recorded skin.
	var skin := GameState.cat_skin(str(data.get("cat", "cream")))
	Player.paint_cat(_canvas, origin + cat_pos * scale_f, Player.SIZE * scale_f,
			0.0, true, false, skin)
	# HUD line: time + mode-appropriate metric.
	var secs := frame_pos * STEP
	var metric := ""
	if endless:
		metric = "%d층" % maxi(int(round(rows - cat_pos.y / cell)), 0)
	else:
		metric = "SCORE %d" % _fr(f, 7)
	_info.text = "%s    %d:%04.1f    %s" % [title_text, int(secs) / 60, fmod(secs, 60.0), metric]
