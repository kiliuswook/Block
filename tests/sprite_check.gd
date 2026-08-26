extends Node2D
## 스프라이트 렌더러 점검 — 6종 × 4단계 + 레이어 리컬러 + 잠금 실루엣.

const CatSprite := preload("res://core/scripts/cat_sprite.gd")
const CustomCat := preload("res://core/scripts/custom_cat.gd")


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://.tmp_shots")
	img.save_png("res://.tmp_shots/sprite_check.png")
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("2a3340"))
	var chars := ["char01", "char02", "char03", "char04", "char05", "char06"]
	for r in chars.size():
		for t in 4:
			CatSprite.paint(self, Vector2(70 + r * 100, 80 + t * 110), 60.0,
					chars[r], t, true)
	# 잠금 실루엣.
	CatSprite.paint(self, Vector2(700, 80), 60.0, "char03", 3, false)
	# 레이어 리컬러 — 몸/귀·꼬리/눈/발바닥 색 교체.
	var tints := {
		"Cat_Body_SkinFill": Color("a8d4f0"), "Cat_Feet_SkinFill": Color("a8d4f0"),
		"Cat_Tail_SkinFill": Color("a8d4f0"),
		"Cat_Body_Pattern": Color("7a55b0"), "Cat_Tail_Pattern": Color("7a55b0"),
		"Cat_Eyes_Color": Color("4a6fb8"), "Cat_Feet_Pawpad": Color("f2c94c"),
	}
	for t in 4:
		CatSprite.paint(self, Vector2(820, 80 + t * 110), 60.0, "char01", t, true, tints)
	# 코드 렌더와 나란히 — 같은 크기·중심이 맞는지.
	for t in 4:
		Player.paint_cat(self, Vector2(950, 80 + t * 110), 60.0, 0.0, true, false,
				GameState.cat_skin("cream"))
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(660, 30), "잠금 / 리컬러 / 코드렌더", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 18, Color.WHITE)
