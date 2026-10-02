extends Node2D
## 신규 디자인 냥이 10종(char07~char16) 점검 — 게임 경로(GameState.cat_skin →
## Player.paint_cat)로 4단계 + 잠금 실루엣 + 사망 + 키캡 얼굴을 그리고,
## 스프라이트가 전부 있는지 확인한다. 기준으로 크림(char01)을 맨 윗줄에 둔다.
## 결과: .tmp_shots/new_cats_check.png, 로그 끝줄 ALL TESTS PASSED

const CatSprite := preload("res://core/scripts/cat_sprite.gd")

const IDS := ["cream", "baker", "pirate", "space", "ninja", "painter", "strawberry",
		"prince", "summer", "rainy", "cow"]
const ROW := 96.0
const S := 56.0

var _fails := 0


func _ready() -> void:
	for id: String in IDS:
		var char_id := str(GameState.get_cat(id).get("char", ""))
		_check(GameState.has_cat(id), "%s is a cat" % id)
		for t in 4:
			_check(CatSprite.has(char_id), "%s has t%d sprite" % [id, t])
		_check(GameState.cat_skin(id).has("sprite"), "%s draws as a sprite" % id)
	_check(not GameState.has_cat("tmp07"), "temp cats are gone")
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://.tmp_shots")
	img.save_png("res://.tmp_shots/new_cats_check.png")
	print("ALL TESTS PASSED" if _fails == 0 else "%d FAILED" % _fails)
	get_tree().quit()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print(("  PASS: " if ok else "  FAIL: ") + what)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("95dfff"))
	for r in IDS.size():
		var id: String = IDS[r]
		var y := 70.0 + r * ROW
		for t in 4:
			Player.paint_cat(self, Vector2(70 + t * 100, y), S, 0.0, true, false,
					GameState.cat_skin(id, t))
		Player.paint_cat(self, Vector2(500, y), S, 0.0, true, false,
				GameState.cat_shadow_skin(id))
		Player.paint_cat(self, Vector2(600, y), S, 0.0, false, false, GameState.cat_skin(id))
		EscapeBoard.paint_keycap(self, Rect2(660, y - 34, 64, 64), "A", 0.5, false, id)
		draw_string(ThemeDB.fallback_font, Vector2(740, y + 6), tr(str(GameState.get_cat(id).name)),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("2c1b17"))
