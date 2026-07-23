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
const POPUP_SIZE := Vector2(620.0, 560.0)
const STAT_ROWS := [["이동", "speed"], ["점프", "jump"], ["대시", "dash"], ["무게", "weight"]]

@onready var escape_btn: Button = $UI/EscapeBtn
@onready var endless_btn: Button = $UI/EndlessBtn
@onready var versus_btn: Button = $UI/VersusBtn
@onready var escape2_btn: Button = $UI/Escape2Btn
@onready var endless2_btn: Button = $UI/Endless2Btn

var _tiles := {}  # cat id -> Button
var _currency_label: Label
var _toast: Label
var _toast_tween: Tween
var _popup: Control
var _popup_face: Control
var _popup_action: Button
var _popup_close: Button
var _popup_cat: Dictionary = {}


func _ready() -> void:
	escape_btn.pressed.connect(func() -> void: _start(GameState.MODE_ESCAPE))
	endless_btn.pressed.connect(func() -> void: _start(GameState.MODE_ENDLESS))
	versus_btn.pressed.connect(func() -> void: _start(GameState.MODE_VERSUS))
	escape2_btn.pressed.connect(func() -> void: _start(GameState.MODE_ESCAPE, true))
	endless2_btn.pressed.connect(func() -> void: _start(GameState.MODE_ENDLESS, true))
	_build_currency_display()
	_build_character_row()
	_build_popup()
	_build_toast()


func _start(mode: int, split := false) -> void:
	GameState.mode = mode
	GameState.split = split
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if _popup and _popup.visible:
		# The popup swallows mode hotkeys; Esc closes it.
		if event is InputEventKey and event.pressed \
				and event.physical_keycode == KEY_ESCAPE:
			_close_popup()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_KP_1:
				_start(GameState.MODE_ESCAPE)
			KEY_2, KEY_KP_2:
				_start(GameState.MODE_ENDLESS)
			KEY_3, KEY_KP_3:
				_start(GameState.MODE_VERSUS)
			KEY_4, KEY_KP_4:
				_start(GameState.MODE_ESCAPE, true)
			KEY_5, KEY_KP_5:
				_start(GameState.MODE_ENDLESS, true)


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
	else:
		# Unlocked cats wear their trait tag; the selected one glows cream.
		var tag_col := CREAM if GameState.selected_cat == cat.id else Color(1, 1, 1, 0.5)
		_draw_center_text(ci, font, str(cat.get("trait", "")), 144.0, 16, tag_col)


func _draw_center_text(ci: Control, font: Font, text: String, y: float,
		size: int, col: Color, width: float = TILE_SIZE.x) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, Vector2((width - w) / 2.0, y), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Maps a stat multiplier (≈0.7–1.3) onto 1–5 display pips; 1.0 = 3 pips.
func _stat_pips(v: float) -> int:
	return clampi(3 + roundi((v - 1.0) * 15.0), 1, 5)


func _draw_lock(ci: Control, at: Vector2) -> void:
	var col := Color(1.0, 0.9, 0.6, 0.9)
	ci.draw_rect(Rect2(at + Vector2(-8.0, -2.0), Vector2(16.0, 13.0)), col)
	ci.draw_arc(at + Vector2(0.0, -3.0), 5.5, PI, TAU, 10, col, 3.0)


func _on_tile_pressed(cat: Dictionary) -> void:
	_open_popup(cat)


# --- Character info popup -----------------------------------------------------


func _build_popup() -> void:
	_popup = Control.new()
	_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup.visible = false
	$UI.add_child(_popup)
	# Dimmed backdrop; clicking it closes the popup.
	var dim := Button.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim_sb := StyleBoxFlat.new()
	dim_sb.bg_color = Color(0, 0, 0, 0.6)
	for st in ["normal", "hover", "pressed", "focus"]:
		dim.add_theme_stylebox_override(st, dim_sb)
	dim.pressed.connect(_close_popup)
	_popup.add_child(dim)
	var panel := Control.new()
	panel.position = (Vector2(1920.0, 1080.0) - POPUP_SIZE) / 2.0
	panel.size = POPUP_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.add_child(panel)
	_popup_face = Control.new()
	_popup_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_face.draw.connect(func() -> void: _draw_popup(_popup_face))
	panel.add_child(_popup_face)
	_popup_action = _make_popup_button(panel, true)
	_popup_action.pressed.connect(_on_popup_action)
	_popup_close = _make_popup_button(panel, false)
	_popup_close.text = "닫기"
	_popup_close.pressed.connect(_close_popup)


func _make_popup_button(panel: Control, accent: bool) -> Button:
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.bg_color = Color(CREAM, 0.16) if accent else Color(1, 1, 1, 0.07)
	sb.set_border_width_all(2)
	sb.border_color = CREAM if accent else Color(1, 1, 1, 0.25)
	b.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color(CREAM, 0.28) if accent else Color(1, 1, 1, 0.14)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	panel.add_child(b)
	return b


func _open_popup(cat: Dictionary) -> void:
	_popup_cat = cat
	var unlocked: bool = GameState.is_unlocked(cat.id)
	var u: Dictionary = cat.unlock
	if unlocked:
		_popup_action.visible = GameState.selected_cat != cat.id
		_popup_action.text = "선택하기"
	elif u.type == "gold":
		_popup_action.visible = true
		_popup_action.text = "구매  %d G" % u.amount
	elif u.type == "gems":
		_popup_action.visible = true
		_popup_action.text = "구매  ◆ %d" % u.amount
	else:
		_popup_action.visible = false
	# Bottom row: action + close side by side, or close alone centered.
	var y := POPUP_SIZE.y - 70.0
	if _popup_action.visible:
		_popup_action.size = Vector2(240.0, 52.0)
		_popup_close.size = Vector2(160.0, 52.0)
		var total := 240.0 + 24.0 + 160.0
		_popup_action.position = Vector2((POPUP_SIZE.x - total) / 2.0, y)
		_popup_close.position = _popup_action.position + Vector2(240.0 + 24.0, 0.0)
	else:
		_popup_close.size = Vector2(200.0, 52.0)
		_popup_close.position = Vector2((POPUP_SIZE.x - 200.0) / 2.0, y)
	_popup.visible = true
	_popup_face.queue_redraw()


func _close_popup() -> void:
	_popup.visible = false


func _on_popup_action() -> void:
	var cat := _popup_cat
	if GameState.is_unlocked(cat.id):
		GameState.select_cat(cat.id)
		_refresh_tiles()
		_close_popup()
		return
	var u: Dictionary = cat.unlock
	var wallet: int = GameState.gold if u.type == "gold" else GameState.gems
	if wallet < int(u.amount):
		_show_toast("골드가 부족해요!" if u.type == "gold" else "보석이 부족해요!",
				Color(1.0, 0.55, 0.5))
		return
	if GameState.try_buy(cat.id):
		GameState.select_cat(cat.id)
		_show_toast("%s 냥이 영입 완료!" % cat.name, CREAM)
		_refresh_currency()
		_refresh_tiles()
		_close_popup()


func _draw_popup(ci: Control) -> void:
	var cat := _popup_cat
	if cat.is_empty():
		return
	var unlocked: bool = GameState.is_unlocked(cat.id)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1c1a26")
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = Color(CREAM, 0.65)
	ci.draw_style_box(sb, Rect2(Vector2.ZERO, POPUP_SIZE))
	var font := ThemeDB.fallback_font
	var center := Vector2(POPUP_SIZE.x / 2.0, 118.0)
	if unlocked:
		Player.paint_cat(ci, center, 110.0, 0.0, true, false, GameState.cat_skin(cat.id))
	else:
		var shadow := {"body": Color(0.16, 0.15, 0.2), "ear": Color(0.11, 0.1, 0.14),
				"ink": Color(0.3, 0.29, 0.35)}
		Player.paint_cat(ci, center, 110.0, 0.0, true, false, shadow)
		_draw_lock(ci, center + Vector2(52.0, 38.0))
	var name_col := Color.WHITE if unlocked else Color(1, 1, 1, 0.6)
	_draw_center_text(ci, font, str(cat.name), 226.0, 34, name_col, POPUP_SIZE.x)
	_draw_center_text(ci, font, "「%s」" % cat.get("trait", ""), 262.0, 21,
			Color(CREAM, 0.95), POPUP_SIZE.x)
	# Stat bars.
	var stats: Dictionary = GameState.cat_stats(cat.id)
	for i in STAT_ROWS.size():
		var row_y := 302.0 + i * 42.0
		ci.draw_string(font, Vector2(150.0, row_y + 14.0), STAT_ROWS[i][0],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.8))
		var pips := _stat_pips(stats.get(STAT_ROWS[i][1], 1.0))
		for p in 5:
			var r := Rect2(238.0 + p * 50.0, row_y, 42.0, 16.0)
			var col := Color(CREAM, 0.95) if p < pips else Color(1, 1, 1, 0.12)
			ci.draw_rect(r, col)
	# Status / unlock condition line.
	var status := ""
	var status_col := Color(1, 1, 1, 0.7)
	var u: Dictionary = cat.unlock
	if unlocked:
		if GameState.selected_cat == cat.id:
			status = "장착 중"
			status_col = Color(CREAM, 0.95)
	else:
		match u.type:
			"gold":
				status = "보유 골드  %d G" % GameState.gold
				status_col = GOLD_COL
			"gems":
				status = "보유 보석  ◆ %d" % GameState.gems
				status_col = GEM_COL
			"height":
				status = "무한의 계단 %d층 도달 시 해금  (최고 %d층)" \
						% [u.floors, GameState.best_height]
			"escape":
				status = "탈출 모드 LV%d 도달 시 해금  (최고 LV%d)" \
						% [u.level, GameState.best_escape_level]
			"plays":
				status = "총 %d판 플레이 시 해금  (현재 %d판)" \
						% [u.count, GameState.games_played]
	if status != "":
		_draw_center_text(ci, font, status, POPUP_SIZE.y - 92.0, 19, status_col,
				POPUP_SIZE.x)


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
	_draw_stat_line()


## One-line stat readout for the selected cat, above the character row.
func _draw_stat_line() -> void:
	var cat := GameState.get_cat(GameState.selected_cat)
	var stats: Dictionary = GameState.cat_stats(cat.id)
	var font := ThemeDB.fallback_font
	var parts: Array[String] = ["%s · %s" % [cat.name, cat.get("trait", "")]]
	for entry in STAT_ROWS:
		var pips := _stat_pips(stats.get(entry[1], 1.0))
		parts.append("%s %s%s" % [entry[0], "●".repeat(pips), "○".repeat(5 - pips)])
	var text := "    ".join(parts)
	var size := 20
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2((1920.0 - w) / 2.0, TILE_Y - 26.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.85))
