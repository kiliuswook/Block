extends Node
## 계정 레벨 회귀 테스트 — 커브·레벨업 보상·경험치 지급이 맞는지,
## 이미 축하한 레벨의 보상이 두 번 나가지 않는지 본다.

func _ready() -> void:
	# ⚠ 실기 세이브를 덮어쓰지 않도록 저장부터 끈다 (user:// 를 실기와 공유한다).
	GameState.save_enabled = false
	var fails := 0
	GameState.achv = []
	GameState.xp = 0
	GameState.account_level = 1
	GameState.gold = 0
	GameState.gold_earned = 0

	# 커브: 1레벨은 XP_BASE, 이후 XP_STEP씩, XP_CAP에서 평평해진다.
	fails += _chk(Account.level() == 1, "빈 세이브가 1레벨이 아님")
	fails += _chk(Account.xp_need(1) == Account.XP_BASE, "1레벨 요구치가 XP_BASE 가 아님")
	fails += _chk(Account.xp_need(2) == Account.XP_BASE + Account.XP_STEP,
			"2레벨 요구치가 한 계단 오르지 않음")
	fails += _chk(Account.xp_need(99) == Account.XP_CAP, "요구치가 XP_CAP 에서 안 멈춤")

	# 한 판 = 참가비 + 성적. 아무 성적이 없어도 0은 아니다.
	var zero := Account.run_xp(GameState.MODE_ENDLESS, 0, 0, 0, false)
	fails += _chk(zero == Account.RUN_BASE, "성적 0인 판이 참가비를 못 받음")
	var tall := Account.run_xp(GameState.MODE_ENDLESS, 0, 30, 0, false)
	fails += _chk(tall > zero, "높이 30층이 0층보다 경험치가 많지 않음")
	fails += _chk(Account.run_xp(GameState.MODE_ENDLESS, 0, 99999, 0, true)
			<= Account.RUN_XP_CAP, "한 판 경험치가 RUN_XP_CAP 를 넘음")
	fails += _chk(Account.run_xp(GameState.MODE_CLASSIC, 3000, 0, 4, true)
			> Account.run_xp(GameState.MODE_CLASSIC, 3000, 0, 4, false),
			"기록 갱신 보너스가 안 붙음")

	# 레벨업: 딱 한 계단 오르고 보상 골드가 들어온다.
	var got: Dictionary = Account.add_xp(Account.xp_need(1))
	fails += _chk(Account.level() == 2, "요구치를 채웠는데 2레벨이 아님")
	fails += _chk(got.levels == [2], "오른 레벨 목록이 [2] 가 아님: %s" % [got.levels])
	fails += _chk(got.gold == Account.level_reward(2), "레벨업 보상 골드가 다름")
	fails += _chk(GameState.gold == Account.level_reward(2), "보상이 지갑에 안 들어감")

	# 같은 레벨의 보상은 다시 나가지 않는다.
	var again: Dictionary = Account.sync()
	fails += _chk(again.gold == 0, "이미 축하한 레벨의 보상이 또 나감")

	# 진행도: 이번 레벨에서 모은 양 / 다음 레벨까지.
	Account.add_xp(Account.xp_need(2) / 2)
	fails += _chk(Account.xp_in_level() == Account.xp_need(2) / 2,
			"이번 레벨 누적 경험치가 안 맞음")
	fails += _chk(absf(Account.progress() - 0.5) < 0.02, "진행도가 절반이 아님")

	# 한 번에 여러 레벨을 넘겨도 계단마다 보상이 나간다.
	GameState.xp = 0
	GameState.account_level = 1
	GameState.gold = 0
	var jump: Dictionary = Account.add_xp(Account.xp_need(1) + Account.xp_need(2)
			+ Account.xp_need(3))
	fails += _chk(jump.levels == [2, 3, 4], "한 번에 오른 레벨이 [2,3,4] 가 아님: %s"
			% [jump.levels])
	fails += _chk(jump.gold == Account.level_reward(2) + Account.level_reward(3)
			+ Account.level_reward(4), "여러 레벨 보상 합계가 다름")

	# 만렙에서 멈춘다.
	GameState.xp = 99_999_999
	GameState.account_level = Account.LEVEL_MAX
	fails += _chk(Account.level() == Account.LEVEL_MAX, "만렙을 넘어감")
	fails += _chk(Account.is_max(), "만렙인데 is_max() 가 false")
	fails += _chk(Account.xp_to_next() == 0, "만렙인데 다음 레벨 요구치가 남음")
	fails += _chk(Account.progress() == 1.0, "만렙 진행도가 꽉 차지 않음")
	Achv.check()
	fails += _chk(Achv.has(Achv.LEVEL_50), "만렙인데 LEVEL_50 업적이 안 열림")

	print("ALL TESTS PASSED" if fails == 0 else "FAILED: %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _chk(ok: bool, msg: String) -> int:
	if ok:
		return 0
	print("  FAIL: ", msg)
	return 1
