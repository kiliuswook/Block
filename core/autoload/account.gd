extends Node
## 계정 레벨 — 판을 거듭하면 저절로 오르는 "얼마나 오래 놀았나" 축.
##
## 키캡(캐릭터 해금)·골드(소비)와 축이 겹치지 않게 **레벨은 오직 플레이로만** 오른다:
## 골드로 살 수도, 가챠로 건너뛸 수도 없다. 한 판이 끝날 때마다 그 판의 성적만큼
## 경험치가 들어오고(main.gd `_award_run_rewards()`), 레벨이 오르면 골드를 준다.
##
## 상태는 GameState(save.json)에 산다 — `xp`(누적 총 경험치)와 `level`(보상까지
## 지급이 끝난 레벨). 레벨 자체는 xp에서 계산되므로 `level`은 "어디까지 축하해
## 줬는가"의 표시일 뿐이고, 커브를 나중에 손대도 `sync()`가 밀린 만큼 따라잡는다.
##
## 분할 화면(2인)은 지갑도 기록도 없는 대전이라 경험치를 주지 않는다.

const LEVEL_MAX := 50

## 레벨 하나를 올리는 데 드는 경험치 = min(BASE + STEP*(레벨-1), CAP).
## 초반은 두어 판에 한 번 오르고, 24레벨부터 CAP으로 평평해진다 (만렙까지 약 57,000).
const XP_BASE := 120
const XP_STEP := 60
const XP_CAP := 1500

## 레벨업 보상 골드 = min(BASE + STEP*(레벨-1), CAP), 5레벨마다 2배.
const REWARD_BASE := 100
const REWARD_STEP := 20
const REWARD_CAP := 500
const REWARD_MILESTONE := 5

## 한 판의 경험치: 참가비 + 성적. 모드마다 점수 단위가 달라 나눗셈이 다르다.
const RUN_BASE := 10
const XP_PER_HEIGHT := 2  # 무한의 계단 1층
const CLASSIC_SCORE_PER_XP := 150  # 스테이지 모드 점수
const CLASSIC_XP_PER_LEVEL := 5
const SCORE_PER_XP := 200  # 그 외 모드
const XP_RECORD := 25  # 자기 최고 기록을 깼을 때
const RUN_XP_CAP := 400  # 한 판이 통째로 레벨을 끌어올리지는 않게

## 10레벨마다 바뀌는 칭호 (표시용 — 능력치와 무관).
const TIER_KEYS: Array[String] = ["MENU_TIER_1", "MENU_TIER_2", "MENU_TIER_3",
		"MENU_TIER_4", "MENU_TIER_5"]


func level() -> int:
	return level_at(GameState.xp)


## 누적 경험치가 몇 레벨인가. 레벨은 1부터.
func level_at(total_xp: int) -> int:
	var lv := 1
	var left := maxi(total_xp, 0)
	while lv < LEVEL_MAX:
		var need := xp_need(lv)
		if left < need:
			break
		left -= need
		lv += 1
	return lv


## `lv` → `lv + 1`에 필요한 경험치.
func xp_need(lv: int) -> int:
	return mini(XP_BASE + XP_STEP * (maxi(lv, 1) - 1), XP_CAP)


## 이번 레벨에서 모은 경험치 (만렙이면 0).
func xp_in_level() -> int:
	var lv := 1
	var left := maxi(GameState.xp, 0)
	while lv < LEVEL_MAX:
		var need := xp_need(lv)
		if left < need:
			return left
		left -= need
		lv += 1
	return 0


## 다음 레벨까지 필요한 경험치 (만렙이면 0).
func xp_to_next() -> int:
	return 0 if level() >= LEVEL_MAX else xp_need(level())


## 이번 레벨 진행도 0~1 — 타이틀 경험치 바가 쓴다. 만렙은 꽉 찬 상태.
func progress() -> float:
	var need := xp_to_next()
	return 1.0 if need <= 0 else clampf(float(xp_in_level()) / float(need), 0.0, 1.0)


func is_max() -> bool:
	return level() >= LEVEL_MAX


## 레벨업 보상 골드.
func level_reward(lv: int) -> int:
	var g := mini(REWARD_BASE + REWARD_STEP * (maxi(lv, 1) - 1), REWARD_CAP)
	return g * 2 if lv % REWARD_MILESTONE == 0 else g


## 지금 레벨의 칭호 번역 키.
func tier_key(lv := -1) -> String:
	var l := level() if lv < 0 else lv
	return TIER_KEYS[clampi((l - 1) / 10, 0, TIER_KEYS.size() - 1)]


## 이 판이 주는 경험치. 성적이 좋을수록 많지만, 참가비(RUN_BASE)가 있어서
## 금방 죽어도 0은 아니다 — "반복하면 오른다"가 이 축의 전부다.
func run_xp(mode: int, score: int, height: int, stage: int, record: bool) -> int:
	var xp := RUN_BASE
	if mode == GameState.MODE_ENDLESS:
		xp += maxi(height, 0) * XP_PER_HEIGHT
	elif mode == GameState.MODE_CLASSIC:
		xp += maxi(score, 0) / CLASSIC_SCORE_PER_XP + maxi(stage, 0) * CLASSIC_XP_PER_LEVEL
	else:
		xp += maxi(score, 0) / SCORE_PER_XP
	if record:
		xp += XP_RECORD
	return mini(xp, RUN_XP_CAP)


## 경험치를 넣고 오른 레벨만큼 보상을 준다.
## 돌려주는 것: {"xp": 넣은 양, "levels": [오른 레벨...], "gold": 보상 합계}
func add_xp(amount: int) -> Dictionary:
	if amount <= 0:
		return {"xp": 0, "levels": [], "gold": 0}
	GameState.xp += amount
	var got := sync()
	got["xp"] = amount
	return got


## 세이브의 `level`을 실제 경험치에 맞춰 따라잡히고, 그 사이 오른 레벨의 보상을
## 지급한다. 보상은 레벨당 한 번뿐이라 여러 번 불러도 안전하다.
func sync() -> Dictionary:
	var target := level()
	var levels: Array[int] = []
	var gold := 0
	while GameState.account_level < target:
		GameState.account_level += 1
		levels.append(GameState.account_level)
		gold += level_reward(GameState.account_level)
	if gold > 0:
		GameState.add_currency(gold)  # 안에서 저장한다
	else:
		GameState.save_game()
	if not levels.is_empty():
		Achv.check()
	return {"xp": 0, "levels": levels, "gold": gold}
