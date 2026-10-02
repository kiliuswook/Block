extends Node2D
## 신규 냥이 10종 파츠 레이어 점검 — 줄마다 [완성 렌더 t0 | 레이어 믹스 t0 | 완성 렌더 t3 |
## 레이어 믹스 t3 | 사망(믹스)]. 믹스는 나만의 캐릭터가 "원본 냥이"로 불러왔을 때 실제로
## 조립되는 모습(CustomCat.mix_of → CatSprite.paint_mix)이다 — 완성 렌더와 같아 보여야 한다.
## 결과: .tmp_shots/gen_layers_check.png

const CustomCat := preload("res://core/scripts/custom_cat.gd")
const CatSprite := preload("res://core/scripts/cat_sprite.gd")
const ROW := 124.0
const S := 78.0


func _ready() -> void:
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://.tmp_shots")
	img.save_png("res://.tmp_shots/gen_layers_check.png")
	print("saved .tmp_shots/gen_layers_check.png")
	get_tree().quit()


func _mix(cid: String, tier: int) -> Dictionary:
	var parts := CustomCat.char_parts(cid, tier)
	return {"parts": parts, "mix": CustomCat.mix_of(parts), "tints": CustomCat.mix_tints(parts)}


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("95dfff"))
	for r in 10:
		var cid := "char%02d" % (r + 7)
		var x0 := 80.0 + (r % 2) * 640.0
		var y := 90.0 + int(r / 2) * ROW * 1.25
		Player.paint_cat(self, Vector2(x0, y), S, 0.0, true, false, {"sprite": cid, "tier": 0})
		Player.paint_cat(self, Vector2(x0 + 110, y), S, 0.0, true, false, _mix(cid, 0))
		Player.paint_cat(self, Vector2(x0 + 250, y), S, 0.0, true, false, {"sprite": cid, "tier": 3})
		Player.paint_cat(self, Vector2(x0 + 360, y), S, 0.0, true, false, _mix(cid, 3))
		Player.paint_cat(self, Vector2(x0 + 480, y), S, 0.0, false, false, _mix(cid, 3))
