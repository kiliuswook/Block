extends Node2D
## 캐릭터 컨셉 시트 재현 캡처 — 디자인 캐릭터 × 파츠 해금 단계(디폴트/1st/2nd/3rd).
## 실행: <godot> --path E:\Game\Block res://tests/cat_sheet.tscn → .tmp_shots/cat_sheet.png

const CustomCat := preload("res://core/scripts/custom_cat.gd")
const OUT := "E:/Game/Block/.tmp_shots"
const WIN := Vector2i(1780, 980)
const CELL := 128.0  # 매트릭스 한 칸
const BLOCK_ROWS := 4  # 한 블록에 캐릭터 4마리


func _ready() -> void:
	get_window().size = WIN
	await get_tree().process_frame
	await get_tree().process_frame
	queue_redraw()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT)
	get_viewport().get_texture().get_image().save_png(OUT + "/cat_sheet.png")
	get_tree().quit()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIN)), Color("bfe6f5"))
	var ids: Array = CustomCat.CHARS.keys()
	# 위쪽: 3rd 파츠까지 해금된 모습 크게.
	for i in mini(6, ids.size()):
		var at := Vector2(160.0 + i * 270.0, 220.0)
		Player.paint_cat(self, at, 190.0, 0.0, true, false,
				{"parts": CustomCat.char_parts(str(ids[i]), 3)})
		draw_string(font, at + Vector2(-40.0, 190.0), str(ids[i]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("2c2a33"))
	# 아래쪽: 전체 캐릭터 × 해금 단계 매트릭스 (4마리씩 블록으로 나눠 가로 배치).
	var titles := ["Default", "1st", "2nd", "3rd"]
	var top := 440.0
	for r in ids.size():
		var block := r / BLOCK_ROWS
		var row := r % BLOCK_ROWS
		var ox := 90.0 + block * (CELL * 4.0 + 110.0)
		var oy := top + row * CELL
		draw_string(font, Vector2(ox - 78.0, oy + CELL * 0.55), str(ids[r]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("2c2a33"))
		if row == 0:
			for c in 4:
				draw_string(font, Vector2(ox + CELL * c + 24.0, top - 14.0), titles[c],
						HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("2c2a33"))
		for c in 4:
			Player.paint_cat(self, Vector2(ox + CELL * (c + 0.5), oy + CELL * 0.5),
					72.0, 0.0, true, false,
					{"parts": CustomCat.char_parts(str(ids[r]), c)})
