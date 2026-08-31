extends Node
## 결과 화면 보상 연출 회귀 테스트 —
## ① 골드가 유저 HUD로 날아가 숫자가 채워지고 ② 경험치 게이지가 차며 레벨업이 뜨고
## ③ 정산이 끝나면 HUD가 실제 세이브 값으로 돌아오는가. 클릭 스킵도 같이 본다.

const DEATH_POPUP := preload("res://core/scripts/death_popup.gd")
const USER_HUD := preload("res://core/scripts/user_hud.gd")

var _fails := 0


func _ready() -> void:
	# ⚠ 실기 세이브를 덮어쓰지 않도록 저장부터 끈다 (user:// 를 실기와 공유한다).
	GameState.save_enabled = false
	await _test_full_sequence()
	await _test_skip()
	await _test_no_reward()
	print("ALL TESTS PASSED" if _fails == 0 else "FAILED: %d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


## 연출을 끝까지 흘려 보낸다.
func _test_full_sequence() -> void:
	var pop := _make_popup()
	var hud: CanvasLayer = pop.hud
	var before := _reset_wallet()
	var reward := _pay(87, Account.xp_need(1) + 20)  # 한 레벨은 확실히 오르게
	pop.open("STATS", false, "gold", "", "xp", reward)
	await get_tree().process_frame
	_chk(hud.gold_shown() == before.gold, "연출 시작 전인데 HUD 골드가 벌써 올랐음")
	_chk(pop._phase == "gold", "골드 단계로 시작하지 않음: %s" % pop._phase)
	# 골드 단계: 코인이 다 날아가면 표시값이 최종 골드가 된다.
	await _wait(pop.OPEN_HOLD + pop.COIN_MAX * pop.COIN_STEP + pop.COIN_FLY + 0.4)
	_chk(hud.gold_shown() == before.gold + 87,
			"코인이 다 닿았는데 HUD 골드가 이 판의 보상만큼 안 오름: %d" % hud.gold_shown())
	# 경험치 단계: 게이지가 차고 레벨업 줄이 붙는다.
	await _wait(pop.PHASE_GAP + pop.XP_FILL + pop.PHASE_GAP + 0.3)
	_chk(pop._phase == "done", "연출이 안 끝남: %s" % pop._phase)
	_chk(pop._levelups >= 1, "레벨이 올랐는데 레벨업 연출이 없음")
	_chk(int(pop._xp_val) == GameState.xp, "게이지가 최종 경험치까지 안 참")
	_chk(hud.gold_shown() == GameState.gold and hud._xp_shown < 0,
			"정산이 끝났는데 HUD가 표시값에 붙들려 있음")
	pop.get_parent().queue_free()


## 화면 클릭 = 그 단계 건너뛰기. 두 번 누르면 정산이 끝난다.
func _test_skip() -> void:
	var pop := _make_popup()
	var hud: CanvasLayer = pop.hud
	_reset_wallet()
	var reward := _pay(120, Account.xp_need(1) + 5)
	pop.open("STATS", false, "gold", "", "xp", reward)
	await get_tree().process_frame
	pop.skip()
	_chk(hud.gold_shown() == int(reward.gold_from) + 120,
			"골드 스킵이 이 판의 보상만큼 안 채움: %d" % hud.gold_shown())
	_chk(pop._phase == "xp", "골드 스킵이 경험치 단계로 안 넘어감: %s" % pop._phase)
	pop.skip()
	_chk(pop._phase == "done", "경험치 스킵이 정산을 안 끝냄: %s" % pop._phase)
	_chk(int(pop._xp_val) == GameState.xp, "스킵 뒤 게이지가 최종값이 아님")
	_chk(hud._gold_shown < 0 and hud._xp_shown < 0, "스킵 뒤 HUD가 안 풀림")
	pop.get_parent().queue_free()


## 보상이 없는 판(또는 캡처·테스트의 옛 호출)은 연출 없이 줄만 띄운다.
func _test_no_reward() -> void:
	var pop := _make_popup()
	var hud: CanvasLayer = pop.hud
	_reset_wallet()
	pop.open("STATS", false, "", "", "")
	await get_tree().process_frame
	_chk(pop._phase == "done", "보상 없는 판인데 연출이 돌아감: %s" % pop._phase)
	_chk(hud._gold_shown < 0, "보상 없는 판인데 HUD가 붙들림")
	pop.get_parent().queue_free()


func _make_popup() -> Control:
	var layer := CanvasLayer.new()
	add_child(layer)
	var pop: Control = DEATH_POPUP.new()
	pop.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(pop)
	var hud: CanvasLayer = USER_HUD.new()
	add_child(hud)
	pop.hud = hud
	return pop


func _reset_wallet() -> Dictionary:
	GameState.gold = 1000
	GameState.xp = 0
	GameState.account_level = 1
	return {"gold": GameState.gold, "xp": GameState.xp}


## 실제 판이 끝났을 때처럼 보상을 먼저 지급하고, 연출에 넘길 값을 만든다.
## 골드 칸에는 **판이 번 골드**만 담는다 — 레벨업 보상은 경험치 단계가 얹는다.
func _pay(gold: int, xp: int) -> Dictionary:
	var gold_before := GameState.gold
	var xp_before := GameState.xp
	GameState.add_currency(gold)
	Account.add_xp(xp)
	return {
		"gold": gold, "gold_from": gold_before,
		"xp": GameState.xp - xp_before, "xp_from": xp_before,
	}


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _chk(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("  FAIL: ", msg)
