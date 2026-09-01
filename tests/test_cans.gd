extends Node
## 통조림 캔(두 번째 재화)의 헤드리스 스모크 테스트.
## Run: godot --headless --path . res://tests/test_cans.tscn
##
## 확인하는 규칙:
##  · 캔은 주간 랭킹 보상으로만 들어온다 (1위 10캔 ~ 100위 1캔, 그 밖 0).
##  · 유니크 냥이의 키캡은 캔 뽑기에서만 나온다 (골드 풀에는 없다).
##  · 유니크 파츠는 캔으로만 산다 (골드 지갑은 건드리지 않는다).
## 세이브는 읽기만 한다 (save_enabled = false).

const CustomCat := preload("res://core/scripts/custom_cat.gd")

var failures := 0


func _ready() -> void:
	GameState.save_enabled = false
	# --- 지갑 -----------------------------------------------------------------
	GameState.cans = 0
	GameState.cans_earned = 0
	GameState.add_cans(7)
	_check(GameState.cans == 7 and GameState.cans_earned == 7, "캔이 적립된다")
	_check(not GameState.spend_cans(8) and GameState.cans == 7,
			"모자라면 캔을 쓰지 못한다 (지갑은 그대로)")
	_check(GameState.spend_cans(3) and GameState.cans == 4, "캔을 쓴다")
	_check(GameState.cans_earned == 7, "쓴 것은 누적 획득에서 빠지지 않는다")

	# --- 주간 랭킹 보상 (캔의 유일한 출처) --------------------------------------
	_check(Ranks.weekly_cans(1) == 10, "1위는 10캔")
	_check(Ranks.weekly_cans(100) == 1, "100위는 1캔")
	_check(Ranks.weekly_cans(101) == 0, "100위 밖은 없다")
	var prev := 99
	for rank in range(1, 101):
		var v := Ranks.weekly_cans(rank)
		if v > prev:
			failures += 1
			print("  FAIL: 캔 보상이 순위와 함께 줄지 않는다 (%d위)" % rank)
			break
		prev = v
	if prev <= 99:
		_check(true, "캔 보상은 순위가 내려갈수록 줄기만 한다")
	_check(Ranks.weekly_gold(1) == Ranks.WEEKLY_REWARDS[0], "골드는 3위까지 그대로")
	_check(Ranks.weekly_gold(4) == 0, "골드는 4위부터 없다")

	# --- 유니크 냥이 ------------------------------------------------------------
	var uniques := GameState.unique_cats()
	_check(not uniques.is_empty(), "유니크 냥이가 정의돼 있다")
	var uid := str(uniques[0].id)
	_check(GameState.is_unique_cat(uid), "유니크 판정")
	_check(not GameState.is_unique_cat("cream"), "첫 냥이는 유니크가 아니다")
	var gold_pool := GameState.gacha_pool(GameState.GACHA_RANDOM)
	for cat in uniques:
		_check(not (str(cat.id) in gold_pool),
				"%s는 골드 뽑기 풀에 없다" % str(cat.id))
	GameState.gacha_can_pick = uid
	_check(GameState.gacha_pool(GameState.GACHA_CAN) == [uid],
			"캔 뽑기는 걸어 둔 유니크 냥이 하나만 낸다")
	GameState.gacha_can_pick = ""
	_check(GameState.gacha_pool(GameState.GACHA_CAN).is_empty(),
			"안 걸어 두면 캔 뽑기는 돌지 않는다")
	# 유니크 냥이는 골드 선택 뽑기에도 걸리지 않는다.
	GameState.gacha_pick = [uid]
	_check(GameState.gacha_pool(GameState.GACHA_PICK).is_empty(),
			"유니크 냥이는 골드 선택 뽑기 풀에 들어가지 않는다")
	GameState.gacha_pick = []

	# --- 뽑기 값 ---------------------------------------------------------------
	_check(GameState.keycap_price(1, GameState.GACHA_CAN)
			== GameState.KEYCAP_CAN_PRICE, "캔 뽑기 낱장 값")
	_check(GameState.keycap_price(GameState.KEYCAP_GACHA_BULK,
			GameState.GACHA_CAN) == GameState.KEYCAP_CAN_BULK_PRICE,
			"캔 10연차는 묶음값")
	_check(GameState.keycap_price(1, GameState.GACHA_PICK)
			> GameState.keycap_price(1, GameState.GACHA_RANDOM),
			"골드 선택 뽑기가 랜덤보다 비싸다")

	# --- 캔으로 뽑기 -------------------------------------------------------------
	var caps_before: Dictionary = GameState.keycaps.duplicate(true)
	GameState.keycaps = {}
	GameState.gacha_can_pick = uid
	GameState.cans = 3
	GameState.gold = 0
	var pull := GameState.draw_keycaps(2, GameState.GACHA_CAN)
	_check(pull.size() == 2, "캔으로 2장 뽑힌다 (골드가 0이어도)")
	_check(GameState.cans == 1, "캔만큼만 빠진다")
	var all_unique := true
	for hit: Dictionary in pull:
		all_unique = all_unique and str(hit.cat) == uid
	_check(all_unique, "캔 뽑기는 걸어 둔 유니크 냥이의 키캡만 낸다")
	GameState.cans = 0
	_check(GameState.draw_keycaps(1, GameState.GACHA_CAN).is_empty(),
			"캔이 없으면 캔 뽑기는 아무것도 내주지 않는다")
	GameState.keycaps = caps_before
	GameState.gacha_can_pick = ""

	# --- 유니크 파츠 ------------------------------------------------------------
	GameState.parts_owned = {}
	var star := _idx("eyes", "star")
	_check(star >= 0, "유니크 파츠 후보(별눈)가 카탈로그에 있다")
	_check(CustomCat.is_unique_option("eyes", star), "별눈은 유니크 파츠다")
	_check(GameState.part_can("eyes", star), "유니크 파츠 값의 단위는 캔이다")
	_check(not GameState.part_can("eyes", _idx("eyes", "iris")),
			"보통 파츠는 골드로 산다")
	var price := GameState.part_price("eyes", star)
	_check(price in GameState.PART_CAN_PRICES, "값은 캔 가격표에서 나온다")
	GameState.gold = 999999
	GameState.cans = 0
	_check(not GameState.can_afford_part("eyes", star),
			"골드가 아무리 많아도 유니크 파츠는 못 산다")
	_check(not GameState.buy_part("eyes", star), "구매가 거절된다")
	_check(GameState.gold == 999999, "거절된 구매는 골드를 건드리지 않는다")
	GameState.cans = price
	_check(GameState.buy_part("eyes", star), "캔으로 산다")
	_check(GameState.cans == 0 and GameState.gold == 999999,
			"캔만 빠지고 골드는 그대로")
	_check(GameState.part_unlocked("eyes", star), "산 파츠는 열린다")
	_check(GameState.part_price("eyes", star) == 0, "이미 산 파츠는 값이 0")

	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("%d TEST(S) FAILED" % failures)
	get_tree().quit(failures)


## 부위 옵션 id -> index.
func _idx(key: String, id: String) -> int:
	var opts: Array = CustomCat.get_part(key).get("opts", [])
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
