extends Node2D
## Title screen: pick a game mode with the buttons or the 1 / 2 keys,
## and pick / buy a cube-cat skin in the character row at the bottom.

const CREAM := Color("f4e3c8")
const GOLD_COL := Color(1.0, 0.85, 0.35)
const GEM_COL := Color(0.55, 0.85, 1.0)
const INK := Color("2a2230")

const TILE_SIZE := Vector2(128.0, 168.0)
const TILE_GAP := 14.0
const TILE_Y := 780.0

@onready var escape_btn: Button = $UI/EscapeBtn
@onready var endless_btn: Button = $UI/EndlessBtn

var _tiles := {}  # cat id -> Button
var _currency_label: Label
var _toast: Label
var _toast_tween: Tween
var _pending_buy := ""


func _ready() -> void:
	escape_btn.pressed.connect(func() -> void: _start(GameState.MODE_ESCAPE))
	endless_btn.pressed.connect(func() -> void: _start(GameState.MODE_ENDLESS))
	_build_currency_display()
	_build_character_row()
	_build_toast()


func _start(mode: int) -> void:
	GameState.mode = mode
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_KP_1:
				_start(GameState.MODE_ESCAPE)
			KEY_2, KEY_KP_2:
				_start(GameState.MODE_ENDLESS)


# --- Character select ---------------------------------------------------------


func _build_character_row() -> void:
	var ui: CanvasLayer = $UI
	var total := GameState.CATS.size() * TILE_SIZE.x \
			+ (GameState.CATS.size() - 1) * TILE_GAP
	var x := (1920.0 - total) / 2.0
	for cat in GameState.CATS:
		var tile := _make_tile(cat)
		tile.position = Vector2(x, TILE_Y)
		ui.add_child(tile)
		_tiles[cat.id] = tile
		x += TILE_SIZE.x + TILE_GAP


func _make_tile(cat: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = TILE_SIZE
	b.size = TILE_SIZE
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: _on_tile_pressed(cat))
	# All visuals are custom-drawn on a child control.
	var face := Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func() -> void: _draw_tile(face, cat))
	b.add_child(face)
	_style_tile(b, cat)
	return b


func _style_tile(b: Button, cat: Dictionary) -> void:
	var selected: bool = GameState.selected_cat == cat.id
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	if selected:
		sb.bg_color = Color(CREAM, 0.14)
		sb.set_border_width_all(3)
		sb.border_color = CREAM
	else:
		sb.bg_color = Color(1, 1, 1, 0.05)
		sb.set_border_width_all(2)
		sb.border_color = Color(1, 1, 1, 0.18)
	b.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.12) if not selected else Color(CREAM, 0.2)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", sb)


func _draw_tile(ci: Control, cat: Dictionary) -> void:
	var unlocked: bool = GameState.is_unlocked(cat.id)
	var center := Vector2(TILE_SIZE.x / 2.0, 62.0)
	if unlocked:
		Player.paint_cat(ci, center, 68.0, 0.0, true, false, GameState.cat_skin(cat.id))
	else:
		# Dark silhouette + lock badge for locked cats.
		var shadow := {"body": Color(0.16, 0.15, 0.2), "ear": Color(0.11, 0.1, 0.14),
				"ink": Color(0.3, 0.29, 0.35)}
		Player.paint_cat(ci, center, 68.0, 0.0, true, false, shadow)
		_draw_lock(ci, center + Vector2(34.0, 24.0))
	var font := ThemeDB.fallback_font
	var name_col := Color.WHITE if unlocked else Color(1, 1, 1, 0.45)
	_draw_center_text(ci, font, cat.name, 112.0, 22, name_col)
	if not unlocked:
		var u: Dictionary = cat.unlock
		match u.type:
			"gold":
				_draw_center_text(ci, font, "%d G" % u.amount, 144.0, 19, GOLD_COL)
			"gems":
				_draw_center_text(ci, font, "◆ %d" % u.amount, 144.0, 19, GEM_COL)
			"height":
				_draw_center_text(ci, font, "무한 %d층" % u.floors, 144.0, 16,
						Color(1, 1, 1, 0.55))
			"escape":
				_draw_center_text(ci, font, "탈출 LV%d" % u.level, 144.0, 16,
						Color(1, 1, 1, 0.55))
			"plays":
				_draw_center_text(ci, font, "%d판 플레이" % u.count, 144.0, 16,
						Color(1, 1, 1, 0.55))
	elif GameState.selected_cat == cat.id:
		_draw_center_text(ci, font, "선택됨", 144.0, 17, CREAM)


func _draw_center_text(ci: Control, font: Font, text: String, y: float,
		size: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, Vector2((TILE_SIZE.x - w) / 2.0, y), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_lock(ci: Control, at: Vector2) -> void:
	var col := Color(1.0, 0.9, 0.6, 0.9)
	ci.draw_rect(Rect2(at + Vector2(-8.0, -2.0), Vector2(16.0, 13.0)), col)
	ci.draw_arc(at + Vector2(0.0, -3.0), 5.5, PI, TAU, 10, col, 3.0)


func _on_tile_pressed(cat: Dictionary) -> void:
	var id: String = cat.id
	if GameState.is_unlocked(id):
		_pending_buy = ""
		GameState.select_cat(id)
		_refresh_tiles()
		return
	var u: Dictionary = cat.unlock
	if u.type == "gold" or u.type == "gems":
		var wallet: int = GameState.gold if u.type == "gold" else GameState.gems
		if wallet < int(u.amount):
			_show_toast("골드가 부족해요!" if u.type == "gold" else "보석이 부족해요!",
					Color(1.0, 0.55, 0.5))
		elif _pending_buy != id:
			_pending_buy = id
			_show_toast("한 번 더 누르면  [%s]  구매!" % cat.name, GOLD_COL)
		elif GameState.try_buy(id):
			_pending_buy = ""
			GameState.select_cat(id)
			_show_toast("%s 냥이 영입 완료!" % cat.name, CREAM)
			_refresh_currency()
			_refresh_tiles()
	else:
		match u.type:
			"height":
				_show_toast("무한의 계단에서 %d층에 도달하면 해금!" % u.floors, Color(1, 1, 1, 0.85))
			"escape":
				_show_toast("탈출 모드 레벨 %d에 도달하면 해금!" % u.level, Color(1, 1, 1, 0.85))
			"plays":
				_show_toast("총 %d판 플레이하면 해금! (현재 %d판)" % [u.count, GameState.games_played],
						Color(1, 1, 1, 0.85))


func _refresh_tiles() -> void:
	for id: String in _tiles:
		_style_tile(_tiles[id], GameState.get_cat(id))
		(_tiles[id].get_child(0) as Control).queue_redraw()
	queue_redraw()


# --- Currency + toast ---------------------------------------------------------


func _build_currency_display() -> void:
	_currency_label = Label.new()
	_currency_label.position = Vector2(1420.0, 40.0)
	_currency_label.size = Vector2(440.0, 40.0)
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_currency_label.add_theme_font_size_override("font_size", 30)
	_currency_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_currency_label.add_theme_constant_override("outline_size", 8)
	$UI.add_child(_currency_label)
	_refresh_currency()


func _refresh_currency() -> void:
	_currency_label.text = "%d G      ◆ %d" % [GameState.gold, GameState.gems]
	_currency_label.add_theme_color_override("font_color", GOLD_COL)


func _build_toast() -> void:
	_toast = Label.new()
	_toast.position = Vector2(460.0, 955.0)
	_toast.size = Vector2(1000.0, 40.0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 24)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.visible = false
	$UI.add_child(_toast)


func _show_toast(text: String, col: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", col)
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


# --- Backdrop -----------------------------------------------------------------


func _draw() -> void:
	var vp := get_viewport_rect().size
	# Pit backdrop: light seeping down from above.
	draw_polygon(PackedVector2Array([
		Vector2.ZERO, Vector2(vp.x, 0), vp, Vector2(0, vp.y),
	]), PackedColorArray([
		Color("2a3040"), Color("2a3040"), Color("0b0c12"), Color("0b0c12"),
	]))
	var warm := Color(1.0, 0.95, 0.82, 0.08)
	var faded := Color(1.0, 0.95, 0.82, 0.0)
	draw_polygon(PackedVector2Array([
		Vector2(vp.x * 0.32, 0), Vector2(vp.x * 0.68, 0),
		Vector2(vp.x * 0.78, vp.y), Vector2(vp.x * 0.22, vp.y),
	]), PackedColorArray([warm, warm, faded, faded]))
	# Decorative tetromino scatter.
	var decos := [
		["T", Vector2(280, 260)], ["L", Vector2(1460, 220)], ["S", Vector2(200, 560)],
		["I", Vector2(1520, 560)], ["Z", Vector2(120, 380)], ["J", Vector2(1700, 400)],
	]
	for d in decos:
		var color: Color = Board.COLORS[d[0]]
		color.a = 0.5
		for c in Board.SHAPES[d[0]][0]:
			var p: Vector2 = d[1] + Vector2(c) * 44.0
			draw_rect(Rect2(p, Vector2(42.0, 42.0)), color)
			draw_rect(Rect2(p, Vector2(42.0, 42.0)),
					Color(1.0, 0.96, 0.84, 0.18), false, 2.0)
	# The cube cat perched above the title, wearing the selected skin.
	Player.paint_cat(self, Vector2(960, 100), 96.0, 0.0, true, false,
			GameState.cat_skin(GameState.selected_cat))
