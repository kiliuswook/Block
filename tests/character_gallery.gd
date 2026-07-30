extends Node2D
## Dev utility: renders the 20-character roster (docs/character_art_spec.md)
## entirely with _draw() primitives, captures 3 stage sheets + an animation
## frame sequence into .tmp_shots/chars/ then quits.
## Run: & "<godot>" --path E:\Game\Block res://tests/character_gallery.tscn

const Player := preload("res://core/scripts/player.gd")
const FONT := preload("res://shared/assets/fonts/NotoSansKR-Regular.otf")
const OUT := "E:/Game/Block/.tmp_shots/chars"

const COLS := 5
const CELL := Vector2(190.0, 205.0)
const HEADER := 64.0
const S := 88.0  # character size in px

# The 20-character roster. flags: hover / no_breathe / squishy tune animation.
const CHARS: Array[Dictionary] = [
	{"id": "cream", "name": "크림", "body": Color("f4e3c8"), "ear": Color("d9a05c")},
	{"id": "cheese", "name": "치즈", "body": Color("f5b352"), "ear": Color("e08a3c")},
	{"id": "calico", "name": "삼색", "body": Color("f2e6d4"), "ear": Color("8a5a33")},
	{"id": "black", "name": "까망", "body": Color("3a3540"), "ear": Color("26232c"),
		"ink": Color("f0d060")},
	{"id": "gray", "name": "회색", "body": Color("aeb6c2"), "ear": Color("7e8694")},
	{"id": "mint", "name": "민트", "body": Color("bfe8d5"), "ear": Color("6fbf9a")},
	{"id": "pink", "name": "벚꽃", "body": Color("f6cdd8"), "ear": Color("e08ea6")},
	{"id": "ghost", "name": "유령", "body": Color(0.93, 0.96, 1.0, 0.6),
		"ear": Color(0.75, 0.8, 0.95, 0.55), "ink": Color("5a6a8a"), "hover": true},
	{"id": "gold", "name": "황금", "body": Color("f7d354"), "ear": Color("c9982a")},
	{"id": "milk", "name": "우유", "body": Color("f8f6f0"), "ear": Color("9ec3e8")},
	{"id": "tiger", "name": "호랑", "body": Color("f0a03c"), "ear": Color("c87828")},
	{"id": "cow", "name": "얼룩", "body": Color("f5f2ea"), "ear": Color("48423e")},
	{"id": "siam", "name": "샴", "body": Color("ead9c0"), "ear": Color("6b4a34")},
	{"id": "robo", "name": "로봇", "body": Color("c8ccd4"), "ear": Color("8a909c"),
		"no_breathe": true},
	{"id": "slime", "name": "슬라임", "body": Color(0.62, 0.88, 0.55, 0.82),
		"ear": Color("58a848"), "squishy": true},
	{"id": "star", "name": "별", "body": Color("2c3560"), "ear": Color("1c2440"),
		"ink": Color("f0e8b0")},
	{"id": "lava", "name": "용암", "body": Color("5a2620"), "ear": Color("3a1814"),
		"ink": Color("ffd090")},
	{"id": "ice", "name": "얼음", "body": Color(0.78, 0.9, 0.98, 0.88),
		"ear": Color("a8cce0")},
	{"id": "shadow", "name": "그림자", "body": Color("1a1620"), "ear": Color("0e0c14"),
		"ink": Color("f0f0f8")},
	{"id": "rainbow", "name": "무지개", "body": Color("f6f3ee"), "ear": Color("d4b8d8")},
]

const RAINBOW: Array[Color] = [Color("e05f5f"), Color("f2a03c"), Color("f2d365"),
	Color("7ec850"), Color("5a8fd0"), Color("9a6ad0")]

var stage := 3
var t := 0.3
var animate := false
var _pose_xf := Transform2D.IDENTITY


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var size := Vector2i(int(COLS * CELL.x), int(HEADER + 4.0 * CELL.y))
	get_window().size = size
	get_window().content_scale_size = size
	await get_tree().process_frame
	await get_tree().process_frame
	for st in [1, 2, 3]:
		stage = st
		animate = false
		t = 0.3
		queue_redraw()
		for i in range(6):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(OUT + "/sheet_stage%d.png" % st)
	stage = 3
	animate = true
	for f in range(45):
		t = f * 0.08
		queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(OUT + "/anim_%02d.png" % f)
	get_tree().quit()


func _draw() -> void:
	var win := Vector2(COLS * CELL.x, HEADER + 4.0 * CELL.y)
	draw_rect(Rect2(Vector2.ZERO, win), Color("221c26"))
	var head := "Cat-Tris 캐릭터 20종 — %d단계 (%s)" % [stage,
			["기본", "성장", "전설"][stage - 1]]
	if animate:
		head = "Cat-Tris 캐릭터 20종 — 3단계 애니메이션 (Idle→Move→Jump→Land→Dash)"
	draw_string(FONT, Vector2(0.0, 42.0), head, HORIZONTAL_ALIGNMENT_CENTER,
			win.x, 26, Color("f4e3c8"))
	for i in range(CHARS.size()):
		var col := i % COLS
		var row := i / COLS
		var cell_pos := Vector2(col * CELL.x, HEADER + row * CELL.y)
		_draw_char(CHARS[i], cell_pos)


func _draw_char(c: Dictionary, cell_pos: Vector2) -> void:
	var center := cell_pos + Vector2(CELL.x / 2.0, CELL.y / 2.0 - 14.0)
	var ground_y := center.y + S / 2.0
	# --- animation state from the shared 3.6s cycle -------------------------
	var look := 0.0
	var rot := 0.0
	var sx := 1.0
	var sy := 1.0
	var jump_off := 0.0
	var dash := 0.0
	var blink := false
	var squish := 1.6 if c.get("squishy", false) else 1.0
	if animate:
		var u := fmod(t, 3.6)
		if not c.get("no_breathe", false):
			sy = 1.0 + 0.025 * squish * sin(t * 3.6)
		blink = u >= 0.55 and u < 0.75
		if u >= 1.2 and u < 1.8:  # move
			rot = deg_to_rad(6.0)
			look = 3.0
			jump_off = -absf(sin((u - 1.2) * TAU / 0.3)) * 4.0
		elif u >= 1.8 and u < 2.4:  # jump
			var ju := (u - 1.8) / 0.6
			jump_off = -46.0 * sin(PI * ju)
			sx = 1.0 - 0.16 * squish * sin(PI * ju)
			sy = 1.0 + 0.22 * squish * sin(PI * ju)
			look = 1.5
		elif u >= 2.4 and u < 2.7:  # land squash
			var lu := 1.0 - (u - 2.4) / 0.3
			sx = 1.0 + 0.24 * squish * lu
			sy = 1.0 - 0.24 * squish * lu
		elif u >= 2.7 and u < 3.3:  # dash
			dash = sin((u - 2.7) / 0.6 * PI)
			rot = deg_to_rad(12.0) * dash
			look = 4.0 * dash
	if c.get("hover", false):
		jump_off += -3.0 + 3.0 * sin(t * 2.2)
	center.y += jump_off
	# Ground shadow, shrinking with height.
	var sh := clampf(1.0 + jump_off / 90.0, 0.35, 1.0)
	_flat_circle(Vector2(center.x, ground_y + 8.0), S * 0.42 * sh, 0.3,
			Color(0.0, 0.0, 0.0, 0.28 * sh))
	# Dash afterimages.
	if dash > 0.1:
		for k in [2, 1]:
			var ac := center - Vector2(k * 16.0 * dash, 0.0)
			_cat_with_pose(c, ac, rot, sx, sy, look, blink, 0.13 * dash * (3 - k))
	_cat_with_pose(c, center, rot, sx, sy, look, blink, 1.0)
	if not animate:
		draw_string(FONT, cell_pos + Vector2(0.0, CELL.y - 16.0), c.name,
				HORIZONTAL_ALIGNMENT_CENTER, CELL.x, 20, Color("d8ccb8"))


func _cat_with_pose(c: Dictionary, center: Vector2, rot: float, sx: float,
		sy: float, look: float, blink: bool, alpha: float) -> void:
	var pivot := center + Vector2(0.0, S / 2.0)  # squash about the feet
	var xf := Transform2D.IDENTITY.translated(-pivot)
	xf = xf.scaled(Vector2(sx, sy)).rotated(rot).translated(pivot)
	_pose_xf = xf
	draw_set_transform_matrix(xf)
	if alpha >= 0.999:
		_paint_full(c, center, look, blink)
	else:
		# Afterimage: base cat only, colors faded to the given alpha.
		var skin := {"body": Color(c.body, c.body.a * alpha),
			"ear": Color(c.ear, c.ear.a * alpha), "aff": 1,
			"ink": Color(c.get("ink", Color("2c2430")), alpha)}
		Player.paint_cat(self, center, S, look, true, false, skin)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_pose_xf = Transform2D.IDENTITY


func _paint_full(c: Dictionary, center: Vector2, look: float, blink: bool) -> void:
	var skin := {"body": c.body, "ear": c.ear, "aff": stage}
	if c.has("ink"):
		skin["ink"] = c.ink
	if c.id == "siam" and stage >= 2:
		skin["ink"] = Color("3a6ea8")
	Player.paint_cat(self, center, S, look, true, false, skin)
	_overlay(c.id, center, look)
	if blink and not c.get("no_breathe", false):
		var ink: Color = skin.get("ink", Color("4a3830"))
		for sg in [-1.0, 1.0]:
			var ep := center + Vector2(sg * S * 0.19 + look, -S * 0.06)
			draw_circle(ep, S * 0.10, c.body)
			draw_line(ep + Vector2(-S * 0.06, 0.0), ep + Vector2(S * 0.06, 0.0),
					ink, S * 0.03)


## Character-specific pattern + stage props, layered over paint_cat.
## Keeps clear of the face zone (|x| < 0.35s, -0.2s < y < 0.25s).
func _overlay(id: String, ct: Vector2, look: float) -> void:
	var h := S / 2.0
	match id:
		"cheese":
			for i in [-1, 0, 1]:  # tabby forehead stripes
				draw_rect(Rect2(ct + Vector2(i * S * 0.13 - S * 0.03, -h + S * 0.04),
						Vector2(S * 0.06, S * 0.14)), Color("d97a2e"))
			if stage >= 2:
				var wp := ct + Vector2(S * 0.62, S * 0.28)
				draw_colored_polygon(PackedVector2Array([wp, wp + Vector2(S * 0.16, -S * 0.1),
						wp + Vector2(S * 0.16, S * 0.1)]), Color("f7d354"))
				draw_circle(wp + Vector2(S * 0.11, 0.0), S * 0.025, Color("e0a83c"))
			if stage >= 3:
				for i in range(4):  # melted drips along the bottom
					draw_circle(ct + Vector2((i - 1.5) * S * 0.22, h - S * 0.02),
							S * 0.07, Color("f5b352"))
		"calico":
			var pc := Color("c8834a") if stage < 3 else Color("e0a040")
			if stage >= 2:
				Player.paint_heart(self, ct + Vector2(-S * 0.30, -h + S * 0.16), S * 0.09, pc)
			else:
				draw_colored_polygon(PackedVector2Array([
					ct + Vector2(-S * 0.44, -h + 4.0), ct + Vector2(-S * 0.16, -h + 4.0),
					ct + Vector2(-S * 0.34, -h + S * 0.24)]), pc)
			draw_colored_polygon(PackedVector2Array([
				ct + Vector2(h - 4.0, S * 0.05), ct + Vector2(h - 4.0, S * 0.33),
				ct + Vector2(S * 0.26, S * 0.3)]), Color("8a5a33"))
			if stage >= 3:
				draw_arc(ct + Vector2(-S * 0.30, -h + S * 0.16), S * 0.13, 0.0, TAU,
						16, Color("f2c94c"), S * 0.02)
		"black":
			if stage >= 2:
				draw_circle(ct + Vector2(0.0, h - S * 0.1), S * 0.055, Color("f2c94c"))
				draw_circle(ct + Vector2(0.0, h - S * 0.115), S * 0.02, Color("8a6a1a"))
			if stage >= 3:
				for i in range(3):
					var a := t * 1.4 + i * TAU / 3.0
					draw_circle(ct + Vector2(cos(a) * S * 0.62, sin(a) * S * 0.5),
							S * 0.07, Color(0.6, 0.4, 0.9, 0.22))
		"gray":
			if stage >= 2:
				var dp := ct + Vector2(0.0, -h + S * 0.13)
				draw_colored_polygon(PackedVector2Array([dp + Vector2(0, -S * 0.07),
						dp + Vector2(S * 0.055, 0), dp + Vector2(0, S * 0.07),
						dp + Vector2(-S * 0.055, 0)]), Color("e8ecf0"))
			if stage >= 3:
				var gl := Color(1.0, 0.72, 0.3, 0.55 + 0.3 * sin(t * 4.0))
				draw_polyline(PackedVector2Array([ct + Vector2(-h + 4.0, S * 0.1),
						ct + Vector2(-S * 0.32, S * 0.2), ct + Vector2(-S * 0.36, S * 0.38)]),
						gl, S * 0.028)
				draw_polyline(PackedVector2Array([ct + Vector2(h - 4.0, -S * 0.06),
						ct + Vector2(S * 0.34, S * 0.08), ct + Vector2(S * 0.42, S * 0.24)]),
						gl, S * 0.028)
		"mint":
			if stage >= 2:  # sprout-leaf hat
				var lp := ct + Vector2(0.0, -h - S * 0.06)
				draw_line(lp + Vector2(0.0, S * 0.06), lp, Color("4a8a5a"), S * 0.03)
				for sg in [-1.0, 1.0]:
					_flat_circle(lp + Vector2(sg * S * 0.09, -S * 0.045), S * 0.09, 0.55,
							Color("6fbf9a"))
			if stage >= 3:
				Player.paint_sparkle(self, ct + Vector2(-S * 0.66, S * 0.2),
						S * 0.08, Color("bfe8d5"))
				Player.paint_sparkle(self, ct + Vector2(S * 0.68, -S * 0.3),
						S * 0.06, Color("e8fff4"))
		"pink":
			if stage >= 2:  # cherry blossom on the ear
				var fp := ct + Vector2(-S * 0.3, -h - S * 0.02)
				for i in range(5):
					draw_circle(fp + Vector2.from_angle(TAU * i / 5.0 - PI / 2.0) * S * 0.05,
							S * 0.045, Color("f2a8bc"))
				draw_circle(fp, S * 0.03, Color("f2d365"))
			if stage >= 3:
				for i in range(3):  # drifting petals
					var pt := ct + Vector2(sin(t * 1.3 + i * 2.1) * S * 0.6,
							fmod(t * 0.35 + i * 0.33, 1.0) * S * 1.1 - S * 0.55)
					_flat_circle(pt, S * 0.045, 0.6, Color(0.95, 0.66, 0.74, 0.8))
		"ghost":
			var bg := Color("221c26")  # wavy bottom silhouette bite-outs
			for i in range(3):
				draw_circle(ct + Vector2((i - 1) * S * 0.3, h + 1.0), S * 0.11, bg)
			if stage >= 2:
				for i in range(2):
					Player.paint_sparkle(self, ct + Vector2((i * 2 - 1) * S * 0.16,
							S * 0.3 + sin(t * 2.0 + i * 2.5) * S * 0.03), S * 0.05,
							Color(1, 1, 1, 0.5))
			if stage >= 3:
				draw_arc(ct, S * 0.72, 0.0, TAU, 32,
						Color(0.8, 0.88, 1.0, 0.2 + 0.1 * sin(t * 3.0)), S * 0.05)
		"gold":
			draw_arc(ct + Vector2(0.0, -h + S * 0.15), S * 0.055, 0.0, TAU, 12,
					Color("c9982a"), S * 0.022)
			if stage >= 2:
				draw_arc(ct + Vector2(0.0, h - S * 0.28), S * 0.34, 0.5, PI - 0.5, 12,
						Color("c9982a"), S * 0.035)
				draw_circle(ct + Vector2(0.0, h - S * 0.05), S * 0.045, Color("f2c94c"))
			if stage >= 3:  # travelling shine sweep
				var px := fmod(t * 0.5, 1.4) * S * 1.6 - S * 0.8
				draw_colored_polygon(PackedVector2Array([
					ct + Vector2(px - S * 0.1, -h + 3.0), ct + Vector2(px + S * 0.04, -h + 3.0),
					ct + Vector2(px - S * 0.16, h - 3.0), ct + Vector2(px - S * 0.3, h - 3.0)]),
					Color(1, 1, 1, 0.3))
		"milk":
			for sg in [-1.0, 1.0]:  # carton spout fold
				draw_colored_polygon(PackedVector2Array([
					ct + Vector2(sg * S * 0.16, -h + 2.0), ct + Vector2(0.0, -h - S * 0.1),
					ct + Vector2(0.0, -h + 2.0)]), Color("9ec3e8" if sg > 0 else "7ba8d4"))
			if stage >= 2:  # straw
				draw_line(ct + Vector2(S * 0.3, -h + 2.0), ct + Vector2(S * 0.44, -h - S * 0.18),
						Color("e08ea6"), S * 0.05)
				draw_line(ct + Vector2(S * 0.44, -h - S * 0.18),
						ct + Vector2(S * 0.52, -h - S * 0.16), Color("e08ea6"), S * 0.05)
			if stage >= 3:
				for i in range(3):  # milk-drop fountain
					var dp := ct + Vector2((i - 1) * S * 0.14,
							-h - S * 0.2 - sin(t * 3.0 + i) * S * 0.06)
					draw_circle(dp, S * 0.035, Color(1, 1, 1, 0.9))
		"tiger":
			var sc := Color("2c2420") if stage < 3 else Color("f2c94c")
			for sg in [-1.0, 1.0]:  # side stripes
				for i in range(2):
					var y := -S * 0.02 + i * S * 0.2
					draw_colored_polygon(PackedVector2Array([
						ct + Vector2(sg * (h - 3.0), y), ct + Vector2(sg * (h - 3.0), y + S * 0.1),
						ct + Vector2(sg * S * 0.26, y + S * 0.05)]), sc)
			if stage >= 2:  # 王 forehead mark
				for i in range(3):
					var w := S * (0.2 if i != 1 else 0.13)
					draw_line(ct + Vector2(-w / 2.0, -h + S * 0.06 + i * S * 0.055),
							ct + Vector2(w / 2.0, -h + S * 0.06 + i * S * 0.055), sc, S * 0.028)
				draw_line(ct + Vector2(0.0, -h + S * 0.06), ct + Vector2(0.0, -h + S * 0.17),
						sc, S * 0.028)
			if stage >= 3:
				draw_arc(ct, S * 0.76, 0.0, TAU, 32, Color(1.0, 0.78, 0.3, 0.16), S * 0.06)
		"cow":
			var spot := Color("3a3430")
			if stage >= 3:  # spots become a glowing constellation
				for p in [Vector2(-0.34, -0.3), Vector2(0.3, -0.34), Vector2(0.36, 0.3)]:
					Player.paint_sparkle(self, ct + p * S, S * 0.07, Color("f2d365"))
				draw_line(ct + Vector2(-0.34, -0.3) * S, ct + Vector2(0.3, -0.34) * S,
						Color(0.95, 0.83, 0.4, 0.4), S * 0.015)
				draw_line(ct + Vector2(0.3, -0.34) * S, ct + Vector2(0.36, 0.3) * S,
						Color(0.95, 0.83, 0.4, 0.4), S * 0.015)
			else:
				_flat_circle(ct + Vector2(-S * 0.32, -S * 0.28), S * 0.13, 0.8, spot)
				_flat_circle(ct + Vector2(S * 0.34, S * 0.26), S * 0.11, 0.85, spot)
			if stage >= 2:  # swaying neck bell
				var sway := sin(t * 3.0) * 0.2
				var bp := ct + Vector2(sin(sway) * S * 0.06, h + S * 0.02)
				draw_line(ct + Vector2(0.0, h - S * 0.06), bp, Color("8a6a4a"), S * 0.025)
				draw_circle(bp, S * 0.06, Color("f2c94c"))
				draw_circle(bp + Vector2(0.0, S * 0.03), S * 0.018, Color("8a6a1a"))
		"siam":
			draw_rect(Rect2(ct + Vector2(-h + 4.0, h - S * 0.12),
					Vector2(S - 8.0, S * 0.08)), Color("6b4a34"))  # dark paws band
			if stage >= 3:  # forehead gem
				var gp := ct + Vector2(0.0, -h + S * 0.13)
				draw_colored_polygon(PackedVector2Array([gp + Vector2(0, -S * 0.06),
						gp + Vector2(S * 0.05, 0), gp + Vector2(0, S * 0.06),
						gp + Vector2(-S * 0.05, 0)]), Color("7a5ad0"))
				Player.paint_sparkle(self, gp + Vector2(S * 0.02, -S * 0.02), S * 0.03,
						Color(1, 1, 1, 0.9))
		"robo":
			for p in [Vector2(-0.36, -0.36), Vector2(0.36, -0.36),
					Vector2(-0.36, 0.36), Vector2(0.36, 0.36)]:  # rivets
				draw_circle(ct + p * S, S * 0.025, Color("6a707c"))
			for sg in [-1.0, 1.0]:  # square LED eyes over the round ones
				var ep := ct + Vector2(sg * S * 0.19 + look, -S * 0.06)
				draw_rect(Rect2(ep - Vector2.ONE * S * 0.07, Vector2.ONE * S * 0.14),
						Color("2c3038"))
				if stage >= 3:
					Player.paint_heart(self, ep + Vector2(0.0, -S * 0.008), S * 0.045,
							Color("58d8e8"))
				else:
					draw_rect(Rect2(ep - Vector2.ONE * S * 0.045, Vector2.ONE * S * 0.09),
							Color("58d8e8"))
			if stage >= 2:  # antenna with blinking tip
				draw_line(ct + Vector2(0.0, -h + 2.0), ct + Vector2(0.0, -h - S * 0.16),
						Color("8a909c"), S * 0.03)
				draw_circle(ct + Vector2(0.0, -h - S * 0.19), S * 0.04,
						Color(1.0, 0.3, 0.3, 0.55 + 0.45 * sin(t * 6.0)))
			if stage >= 3:  # chest gauge
				draw_rect(Rect2(ct + Vector2(-S * 0.11, S * 0.3), Vector2(S * 0.22, S * 0.07)),
						Color("2c3038"))
				draw_rect(Rect2(ct + Vector2(-S * 0.1, S * 0.31),
						Vector2(S * 0.2 * (0.6 + 0.4 * sin(t * 2.0)), S * 0.05)), Color("58e87c"))
		"slime":
			_flat_circle(ct + Vector2(-S * 0.26, -S * 0.3), S * 0.1, 0.7, Color(1, 1, 1, 0.35))
			if stage >= 2:
				for i in range(2):  # rising bubbles
					var bp := ct + Vector2((i * 2 - 1) * S * 0.18,
							S * 0.3 - fmod(t * 0.3 + i * 0.5, 1.0) * S * 0.5)
					draw_arc(bp, S * 0.045, 0.0, TAU, 10, Color(1, 1, 1, 0.5), S * 0.015)
			if stage >= 3:
				draw_arc(ct + Vector2(0.0, S * 0.1), S * 0.6, 0.3, PI - 0.3, 16,
						Color(0.5, 0.9, 0.45, 0.35), S * 0.04)
		"star":
			var pts := [Vector2(-0.34, -0.32), Vector2(0.3, -0.36), Vector2(-0.38, 0.22),
					Vector2(0.38, 0.14), Vector2(0.1, 0.36), Vector2(-0.15, -0.38)]
			for i in range(pts.size()):
				var tw := 1.0 + (0.35 * sin(t * 3.0 + i * 1.7) if stage >= 2 else 0.0)
				draw_circle(ct + pts[i] * S, S * 0.022 * tw, Color(1, 1, 1, 0.9))
			if stage >= 2:  # shooting star
				var sp := ct + Vector2(S * 0.42, -S * 0.42)
				draw_line(sp, sp + Vector2(-S * 0.14, S * 0.05), Color(1, 1, 1, 0.6), S * 0.02)
				Player.paint_sparkle(self, sp, S * 0.05, Color(1, 1, 1, 0.95))
			if stage >= 3:  # galaxy swirl
				draw_arc(ct, S * 0.3, t * 0.8, t * 0.8 + PI * 1.2, 16,
						Color(0.55, 0.45, 0.95, 0.4), S * 0.06)
				draw_arc(ct, S * 0.18, t * 0.8 + PI, t * 0.8 + PI * 2.1, 12,
						Color(0.8, 0.6, 1.0, 0.35), S * 0.05)
		"lava":
			var gl := Color("ff7830")
			gl.a = 0.75 + (0.25 * sin(t * 4.0) if stage >= 2 else 0.0)
			draw_polyline(PackedVector2Array([ct + Vector2(-h + 3.0, -S * 0.1),
					ct + Vector2(-S * 0.3, 0.0), ct + Vector2(-S * 0.36, S * 0.2)]),
					gl, S * 0.035)
			draw_polyline(PackedVector2Array([ct + Vector2(h - 3.0, S * 0.05),
					ct + Vector2(S * 0.32, S * 0.18), ct + Vector2(S * 0.38, S * 0.36)]),
					gl, S * 0.035)
			draw_polyline(PackedVector2Array([ct + Vector2(S * 0.1, h - 3.0),
					ct + Vector2(0.0, S * 0.3)]), gl, S * 0.03)
			if stage >= 2:  # smoke wisp
				_flat_circle(ct + Vector2(S * 0.3, -h - S * 0.1 - fmod(t * 0.2, 0.4) * S),
						S * 0.05, 0.8, Color(0.6, 0.6, 0.6, 0.3))
			if stage >= 3:  # flame crown
				for i in [-1, 0, 1]:
					var fh := S * (0.16 + 0.05 * sin(t * 7.0 + i * 2.0))
					draw_colored_polygon(PackedVector2Array([
						ct + Vector2(i * S * 0.14 - S * 0.05, -h - S * 0.02),
						ct + Vector2(i * S * 0.14 + S * 0.05, -h - S * 0.02),
						ct + Vector2(i * S * 0.14, -h - fh)]),
						Color("ffb040") if i == 0 else Color("ff7830"))
		"ice":
			for sg in [-1.0, 1.0]:  # frost crystals on the cheeks' outer edge
				var fp := ct + Vector2(sg * S * 0.36, -S * 0.3)
				for k in range(3):
					var a := PI / 2.0 + k * TAU / 3.0
					draw_line(fp - Vector2.from_angle(a) * S * 0.05,
							fp + Vector2.from_angle(a) * S * 0.05, Color(1, 1, 1, 0.8), S * 0.015)
			if stage >= 2:  # icicle earring + breath puff
				draw_colored_polygon(PackedVector2Array([ct + Vector2(S * 0.3, -h + S * 0.28),
						ct + Vector2(S * 0.36, -h + S * 0.28),
						ct + Vector2(S * 0.33, -h + S * 0.44)]), Color("d8f0fc"))
				if animate and fmod(t, 3.0) < 0.8:
					_flat_circle(ct + Vector2(S * 0.5 + fmod(t, 3.0) * S * 0.1, S * 0.1),
							S * 0.06, 0.7, Color(1, 1, 1, 0.4 - fmod(t, 3.0) * 0.4))
			if stage >= 3:  # crystal facets
				draw_colored_polygon(PackedVector2Array([ct + Vector2(-h + 3.0, -h + S * 0.3),
						ct + Vector2(-S * 0.2, -h + 3.0), ct + Vector2(-h + 3.0, -h + 3.0)]),
						Color(1, 1, 1, 0.3))
				draw_colored_polygon(PackedVector2Array([ct + Vector2(h - 3.0, S * 0.2),
						ct + Vector2(S * 0.24, h - 3.0), ct + Vector2(h - 3.0, h - 3.0)]),
						Color(1, 1, 1, 0.22))
				Player.paint_sparkle(self, ct + Vector2(-S * 0.3, S * 0.32), S * 0.05,
						Color(1, 1, 1, 0.9))
		"shadow":
			if stage >= 2:  # rippling purple rim
				var ra := 0.35 + 0.2 * sin(t * 3.0)
				draw_arc(ct, S * 0.62, -PI * 0.8 + sin(t * 1.5) * 0.4, PI * 0.3, 12,
						Color(0.55, 0.35, 0.85, ra), S * 0.035)
				draw_arc(ct, S * 0.62, PI * 0.3 + sin(t * 1.2) * 0.4, PI * 1.1, 12,
						Color(0.55, 0.35, 0.85, ra * 0.8), S * 0.035)
			if stage >= 3:  # smoke wisps pulling off the body
				for i in range(3):
					var wu := fmod(t * 0.4 + i * 0.37, 1.0)
					_flat_circle(ct + Vector2(-S * 0.34 - wu * S * 0.3,
							-S * 0.2 - wu * S * 0.35), S * (0.09 - wu * 0.06), 0.9,
							Color(0.16, 0.13, 0.22, 0.8 - wu * 0.8))
		"rainbow":
			if stage == 1:  # single band across the forehead
				for i in range(6):
					draw_rect(Rect2(ct + Vector2(-S * 0.3 + i * S * 0.1, -h + S * 0.06),
							Vector2(S * 0.1, S * 0.07)), RAINBOW[i])
			else:  # whole-body flowing gradient
				for i in range(6):
					var hue := RAINBOW[(i + int(t * 4.0)) % 6]
					draw_rect(Rect2(ct + Vector2(-h + 4.0, -h + 4.0 + i * (S - 8.0) / 6.0),
							Vector2(S - 8.0, (S - 8.0) / 6.0)), Color(hue, 0.24))
			if stage >= 3:  # ribbon trail
				for i in range(6):
					draw_arc(ct + Vector2(-S * 0.75, S * 0.1), S * (0.3 + i * 0.035),
							PI * 0.75, PI * 1.45, 12, Color(RAINBOW[i], 0.75), S * 0.028)


## Squashed circle helper (ellipse-ish) — draws a circle scaled on y,
## composed on top of the current character pose transform.
func _flat_circle(pos: Vector2, r: float, ky: float, col: Color) -> void:
	draw_set_transform_matrix(_pose_xf * Transform2D(0.0, Vector2(1.0, ky), 0.0, pos))
	draw_circle(Vector2.ZERO, r, col)
	draw_set_transform_matrix(_pose_xf)
