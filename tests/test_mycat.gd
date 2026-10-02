extends Node
## "나만의 캐릭터"(커스텀 슬롯) + 파츠 해금 규칙의 헤드리스 스모크 테스트.
## Run: godot --headless --path . res://tests/test_mycat.tscn
## 세이브는 읽기만 한다 (커스터마이징을 저장하지 않는다).

const CustomCat := preload("res://core/scripts/custom_cat.gd")
const CatSprite := preload("res://core/scripts/cat_sprite.gd")

var failures := 0


func _ready() -> void:
	# 실기 세이브를 그대로 읽으므로, 판정에 쓰는 상태는 먼저 비워 고정한다.
	GameState.save_enabled = false
	GameState.cat_custom.erase("mycat")
	GameState.parts_owned = {}
	# 커스텀 슬롯 자체
	_check(GameState.is_custom_cat("mycat"), "mycat is the custom slot")
	_check(not GameState.is_custom_cat("cream"), "design cats are not custom slots")
	_check(GameState.is_unlocked("mycat"), "mycat is available from the start")
	_check(GameState.keycap_cats().size() == GameState.CATS.size() - 1,
			"mycat is out of the keycap pool")
	_check(GameState.cat_id_for_char("char01") == "cream", "char01 maps to cream")
	_check(GameState.cat_id_for_char("custom") == "", "the blank body has no owner")

	# 출처표: 파츠는 전부 디자인 냥이에게서 온다
	var src := CustomCat.my_sources()
	_check(not src.is_empty(), "part sources are built")
	_check(_idx("eyes", "oval") in CustomCat.my_options("eyes"),
			"char01's eyes are in the catalog")
	_check(_idx("eyes", "nosuch") < 0, "unknown option ids are not in the catalog")
	# 히든 파츠는 디자인 냥이 출처 없이 카탈로그에 서고, 다른 파츠처럼 골드로 산다.
	_check(_idx("head", "egg") in CustomCat.my_options("head"),
			"hidden parts are in the catalog")
	_check(CustomCat.option_sources("head", _idx("head", "egg")) == [],
			"hidden parts have no source cat")
	_check(not GameState.part_free("head", _idx("head", "egg")),
			"hidden parts must be bought")
	_check(CustomCat.option_sources("head", _idx("head", "none")) == [],
			'"none" is always open')

	# 해금 판정 — 냥이의 파츠는 그 냥이를 획득하면 열리고, 파츠 전용만 산다
	GameState.keycaps = {}
	_check(GameState.part_free("eyes", _idx("eyes", "oval")),
			"the blank body's own parts are free")
	_check(GameState.part_free("head", _idx("head", "none")),
			'"none" needs no purchase')
	var iris := _idx("eyes", "iris")
	_check(not GameState.part_unlocked("eyes", iris),
			"a cat's part starts locked while no owner is recruited")
	_check(not GameState.part_buyable("eyes", iris), "a cat's part is not for sale")
	_check(GameState.part_price("eyes", iris) == 0, "so it has no price")
	GameState.gold = 10000
	_check(not GameState.buy_part("eyes", iris), "and buying it is refused")
	_check(GameState.gold == 10000, "the refused buy keeps the gold")
	var hint := GameState.part_unlock_hint("face", _idx("face", "sunglasses"))
	_check(str(hint.get("cat", "")) == "black", "the hint names the owner cat")
	# 주인 냥이를 데려오면(등급 1) 그 냥이의 파츠가 단계와 상관없이 전부 열린다.
	GameState.keycaps["black"] = _one_ring()
	_check(GameState.cat_grade("black") == 1, "black is recruited")
	_check(GameState.part_unlocked("eyes", iris), "its eyes open")
	_check(GameState.part_unlocked("face", _idx("face", "sunglasses")),
			"even its later-tier parts open on recruit")
	# 크림(무료 냥이)의 파츠는 처음부터 열려 있다.
	GameState.keycaps = {}
	var cream_open := 0
	for k: String in ["eyes", "ear_shape", "mouth"]:
		for i: int in CustomCat.my_options(k):
			var srcs: Variant = CustomCat.option_sources(k, i)
			for one: Dictionary in srcs:
				if str(one.char) == "char01":
					_check(GameState.part_unlocked(k, i), "cream part %s/%d is open" % [k, i])
					cream_open += 1
	_check(cream_open > 0, "cream owns some parts")
	# 파츠 전용(히든) 옵션은 재화로 산다.
	var egg := _idx("head", "egg")
	_check(GameState.part_buyable("head", egg), "a parts-only option is for sale")
	_check(not GameState.part_unlocked("head", egg), "and starts locked")
	var price := GameState.part_price("head", egg)
	_check(price > 0, "it has a price")
	GameState.gold = 0
	_check(not GameState.buy_part("head", egg), "no gold, no part")
	GameState.gold = 10000
	_check(GameState.buy_part("head", egg), "the part is bought")
	_check(GameState.part_unlocked("head", egg), "and usable right away")
	_check(GameState.gold == 10000 - price, "the gold is spent")
	_check(GameState.part_price("head", egg) == 0, "an owned part costs nothing")

	# 백지 몸통이 실제로 조립되는가
	var skin: Dictionary = GameState.cat_skin("mycat")
	_check(not skin.has("sprite"),
			"mycat is not one design cat's finished render")
	# 나만의 캐릭터는 디자인 냐이들의 시트 파츠 그림을 섞어 그린다.
	var mix: Dictionary = skin.get("mix", {})
	_check(not mix.is_empty(), "mycat is assembled from sheet part layers")
	_check(mix.has("Cat_Body_Outline") and mix.has("Cat_Eyes_Color"),
			"the body and eyes come from a real cat's layers")
	for layer: String in mix:
		_check(not CatSprite.find_layer(str(mix[layer]), layer).is_empty(),
				"layer %s exists on %s" % [layer, mix[layer]])
	_check(not (skin.get("tints", {}) as Dictionary).is_empty(),
			"the mix carries its layer tints")
	_check((skin.get("parts", {}) as Dictionary).has("body_col"),
			"mycat's blank body has parts")
	_check(CustomCat.char_parts("custom").get("ear") == "pointy",
			"the blank body falls back to BLANK_CHAR, not char01")

	# 신규 10종 — Higgsfield로 뽑은 파츠 레이어가 있어 "원본 냥이"로 불러오면
	# 자기 그림으로만 조립된다 (몸·눈·입·수염·무늬·소품 전부 자기 옵션).
	for n in range(7, 17):
		var cid := "char%02d" % n
		_check(CatSprite.is_layered(cid), "%s has part layers" % cid)
		var parts := CustomCat.char_parts(cid, 3)
		var sel := CustomCat.char_selection(cid, 3)
		for key: String in ["ear_shape", "eyes", "mouth", "whisker", "head", "hold",
				"chest", "back", "tail", "mark", "face", "pattern"]:
			var want := str(parts.get("ear" if key == "ear_shape" else key, "none"))
			if want == "none":
				continue
			_check(sel.has(key), "%s's %s (%s) is in the catalog" % [cid, key, want])
		var cmix := CustomCat.mix_of(parts)
		for layer: String in ["Cat_Body_Outline", "Cat_Body_SkinFill", "Cat_Feet_Outline",
				"Cat_Eyes_Color", "Cat_Mouse", "Cat_Tail_Outline"]:
			_check(str(cmix.get(layer, "")) == cid, "%s draws its own %s" % [cid, layer])
		var got := GameState.cat_id_for_char(cid)
		_check(got != "" and not GameState.is_custom_cat(got), "%s belongs to a design cat" % cid)

	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("%d TEST(S) FAILED" % failures)
	get_tree().quit(failures)


## A~Z 한 바퀴 (= 등급 1, 해금).
func _one_ring() -> Dictionary:
	var d := {}
	for i in 26:
		d[char(65 + i)] = 1
	return d


## 부위 옵션 id -> index.
func _idx(key: String, id: String) -> int:
	var part := CustomCat.get_part(key)
	var opts: Array = part.opts
	for i in opts.size():
		if str(opts[i].id) == id:
			return i
	return -1


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		failures += 1
		print("  FAIL: %s" % label)
