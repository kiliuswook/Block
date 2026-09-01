extends Node
## [임시 · 임시 캐릭터와 함께 제거] 자리를 채운 임시 캐릭터 24종 점검.

const CustomCat := preload("res://core/scripts/custom_cat.gd")

var _ok := true


func _ready() -> void:
	GameState.save_enabled = false
	_check(GameState.CATS.size() == 31, "냥이 30종 + 커스텀 슬롯 1 = %d" % GameState.CATS.size())
	_check(CustomCat.all_chars().size() == 30, "캐릭터 정의 30종")
	for cat in GameState.CATS:
		var id := str(cat.id)
		var char_id := str(cat.get("char", ""))
		if not bool(cat.get("temp", false)):
			continue
		_check(CustomCat.all_chars().has(char_id), "%s 의 정의 %s" % [id, char_id])
		_check(tr(str(cat.name)) != str(cat.name), "%s 이름 번역" % id)
		for tier in range(0, CustomCat.TIER_MAX + 1):
			var skin := GameState.cat_skin(id, tier)
			_check(not (skin.get("mix", {}) as Dictionary).is_empty(),
					"%s t%d 파츠 믹스" % [id, tier])
			_check(not (skin.get("tints", {}) as Dictionary).is_empty(),
					"%s t%d 레이어 색" % [id, tier])
		_check(not GameState.cat_shadow_skin(id).is_empty(), "%s 잠금 실루엣" % id)
	# 임시 캐릭터가 "나만의 캐릭터"의 파츠 해금 출처로 새지 않아야 한다.
	for key: Variant in CustomCat.my_sources():
		for idx: Variant in CustomCat.my_sources()[key]:
			for src: Dictionary in (CustomCat.my_sources()[key][idx] as Array):
				_check(CustomCat.CHARS.has(str(src.char)),
						"파츠 출처가 디자인 냥이인가 (%s)" % src.char)
	print("ALL TESTS PASSED" if _ok else "FAILED")
	get_tree().quit(0 if _ok else 1)


func _check(cond: bool, label: String) -> void:
	if not cond:
		_ok = false
		print("  FAIL: ", label)
