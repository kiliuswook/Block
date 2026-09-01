extends Node2D
## [임시 · 임시 파츠와 함께 제거] 임시 파츠 카탈로그 미리보기 캡처.
## 실행: <godot> --path E:\Game\Block res://tests/temp_parts_sheet.tscn
##  → .tmp_shots/temp_parts_1.png / _2.png

const CustomCat := preload("res://core/scripts/custom_cat.gd")
const TempParts := preload("res://core/scripts/temp_parts.gd")
const OUT := "E:/Game/Block/.tmp_shots"
const WIN := Vector2i(1600, 900)
const COLS := 7

var _page := 0
var _rows: Array = []


func _ready() -> void:
	get_window().size = WIN
	# 부위 하나 = 한 줄 (기본 모습 + 임시 옵션들).
	for slot: String in TempParts.STYLES:
		_rows.append(slot)
	for page in 2:
		_page = page
		await get_tree().process_frame
		await get_tree().process_frame
		queue_redraw()
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(OUT)
		get_viewport().get_texture().get_image().save_png(
				OUT + "/temp_parts_%d.png" % (page + 1))
	get_tree().quit()


func _idx(key: String, id: String) -> int:
	var part := CustomCat.get_part(key)
	for i in (part.opts as Array).size():
		if str((part.opts as Array)[i].id) == id:
			return i
	return 0


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIN)), Color("bfe6f5"))
	var per := 7
	var rows: Array = _rows.slice(_page * per, (_page + 1) * per)
	for r in rows.size():
		var slot: String = rows[r]
		var y := 90.0 + r * 118.0
		draw_string(font, Vector2(16.0, y - 44.0), slot,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("2c2a33"))
		var opts: Array = TempParts.STYLES[slot]
		for c in opts.size():
			var id := str((opts[c] as Dictionary).id)
			var sel := {slot: _idx(slot, id)}
			var skin := CustomCat.build_skin("custom", 0, sel)
			var at := Vector2(150.0 + c * 200.0, y)
			Player.paint_cat(self, at, 84.0, 0.0, true, false, skin)
			draw_string(font, at + Vector2(-70.0, 62.0),
					"%s / %s" % [id, str((opts[c] as Dictionary).name)],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("2c2a33"))
