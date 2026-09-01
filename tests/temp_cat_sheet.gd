extends Node2D
## [임시 · 임시 캐릭터와 함께 제거] 냥이 30종 미리보기 캡처.
## 실행: <godot> --path E:\Game\Block res://tests/temp_cat_sheet.tscn
##  → .tmp_shots/temp_cat_sheet.png

const OUT := "E:/Game/Block/.tmp_shots"
const WIN := Vector2i(1600, 900)
const COLS := 8


func _ready() -> void:
	get_window().size = WIN
	await get_tree().process_frame
	await get_tree().process_frame
	queue_redraw()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT)
	get_viewport().get_texture().get_image().save_png(OUT + "/temp_cat_sheet.png")
	get_tree().quit()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIN)), Color("bfe6f5"))
	var i := 0
	for cat in GameState.CATS:
		var id := str(cat.id)
		var at := Vector2(110.0 + (i % COLS) * 190.0, 130.0 + (i / COLS) * 220.0)
		Player.paint_cat(self, at, 130.0, 0.0, true, false,
				GameState.cat_skin(id, 3))
		draw_string(font, at + Vector2(-60.0, 105.0), "%s / %s" % [id, cat.get("char", "")],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("2c2a33"))
		i += 1
