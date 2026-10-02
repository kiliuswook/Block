extends Node2D
## 히든 파츠 세트 미리보기 캡처 — 세트 하나 = 한 줄 (그 세트의 파츠를 전부 입힌
## 나만의 캐릭터 + 부위별로 하나씩만 입힌 모습).
## 실행: <godot> --path E:\Game\Block res://tests/hidden_parts_sheet.tscn
##  → .tmp_shots/hidden_parts_sheet.png

const CustomCat := preload("res://core/scripts/custom_cat.gd")
const OUT := "E:/Game/Block/.tmp_shots"
const WIN := Vector2i(1400, 780)


func _ready() -> void:
	get_window().size = WIN
	await get_tree().process_frame
	await get_tree().process_frame
	queue_redraw()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT)
	get_viewport().get_texture().get_image().save_png(OUT + "/hidden_parts_sheet.png")
	get_tree().quit()


## 세트 id → {부위 key: 옵션 index} — 카탈로그에서 "src"가 그 세트인 옵션을 모은다.
static func _sets() -> Dictionary:
	var out := {}
	for part in CustomCat.PARTS:
		if part.get("type") == "color":
			continue
		var opts: Array = part.opts
		for i in opts.size():
			var o: Dictionary = opts[i]
			if bool(o.get("hidden", false)):
				var sid := str(o.src)
				if not out.has(sid):
					out[sid] = {}
				out[sid][str(part.key)] = i
	return out


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIN)), Color("bfe6f5"))
	var sets := _sets()
	var ids: Array = sets.keys()
	ids.sort()
	for r in ids.size():
		var sid: String = ids[r]
		var sel: Dictionary = sets[sid]
		var y := 40.0 + r * 64.0
		draw_string(font, Vector2(16.0, y + 6.0), sid, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
				Color("2c2a33"))
		Player.paint_cat(self, Vector2(180.0, y), 56.0, 0.0, true, false,
				CustomCat.build_skin("custom", 0, sel))
		var c := 0
		for key: String in sel:
			var at := Vector2(330.0 + c * 200.0, y)
			Player.paint_cat(self, at, 50.0, 0.0, true, false,
					CustomCat.build_skin("custom", 0, {key: sel[key]}))
			var opt: Dictionary = (CustomCat.get_part(key).opts as Array)[sel[key]]
			draw_string(font, at + Vector2(60.0, 4.0), "%s: %s" % [key, str(opt.name)],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("2c2a33"))
			c += 1
