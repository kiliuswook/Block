extends Node
## 업적 정의와 해금 판정.
##
## **게임 안에 업적 목록 UI는 없다.** 표시는 스팀 오버레이가 맡는다 — 이름·설명·
## 아이콘·번역이 전부 파트너 사이트에 있으므로 여기엔 id와 조건만 둔다.
## (모바일을 재개하면 그때 이 DEFS 위에 자체 목록 화면을 얹으면 된다.)
##
## 해금 기록은 GameState.achv(save.json)에 남는다. 스팀에 이미 올렸는지와 무관하게
## 여기서 한 번 걸러야 매 프레임 setAchievement가 날아가는 걸 막을 수 있고,
## 스팀이 아닌 빌드(웹)에서도 진행이 보존된다.
##
## 판정은 두 갈래다:
##  · **상태형** — 세이브 값만 보면 알 수 있는 것. `check()` 하나가 전부 훑는다
##    (판 종료·가챠·타이틀 진입 때 호출). 소급 적용되므로 나중에 업적을 추가해도
##    기존 세이브가 조건을 이미 만족하면 그 자리에서 해금된다.
##  · **사건형** — 그 순간에만 알 수 있는 것(리플레이 관전, 커스터마이징 저장).
##    해당 지점에서 `unlock()`을 직접 부른다.

## 파트너 사이트의 API Name과 **정확히 일치**해야 한다. 표시 이름/설명은 자유.
const FIRST_ESCAPE := "FIRST_ESCAPE"
const HEIGHT_25 := "HEIGHT_25"
const HEIGHT_50 := "HEIGHT_50"
const HEIGHT_100 := "HEIGHT_100"
const CLASSIC_LV5 := "CLASSIC_LV5"
const CLASSIC_LV10 := "CLASSIC_LV10"
const CLASSIC_100K := "CLASSIC_100K"
const KEYCAP_FIRST := "KEYCAP_FIRST"
const KEYCAP_RING := "KEYCAP_RING"
const CAT_UNLOCK_ALL := "CAT_UNLOCK_ALL"
const CAT_MAX_GRADE := "CAT_MAX_GRADE"
const GACHA_100 := "GACHA_100"
const GOLD_10K := "GOLD_10K"
const CUSTOM_CAT := "CUSTOM_CAT"
const REPLAY_WATCH := "REPLAY_WATCH"
const LEVEL_10 := "LEVEL_10"
const LEVEL_25 := "LEVEL_25"
const LEVEL_50 := "LEVEL_50"

## 등록해야 할 업적 전체 — 파트너 사이트 등록표와 1:1이다.
## `ev`가 참이면 사건형(= check()가 판정하지 않고 그 지점에서 unlock()을 부른다).
const DEFS: Array[Dictionary] = [
	{"id": FIRST_ESCAPE, "cond": "무한의 계단 첫 판 종료"},
	{"id": HEIGHT_25, "cond": "무한 25층"},
	{"id": HEIGHT_50, "cond": "무한 50층"},
	{"id": HEIGHT_100, "cond": "무한 100층"},
	{"id": CLASSIC_LV5, "cond": "스테이지 모드 LEVEL 5 도달"},
	{"id": CLASSIC_LV10, "cond": "스테이지 모드 LEVEL 10 도달"},
	{"id": CLASSIC_100K, "cond": "스테이지 모드 100,000점"},
	{"id": KEYCAP_FIRST, "cond": "키캡 1장 획득"},
	{"id": KEYCAP_RING, "cond": "아무 냥이나 A~Z 한 바퀴 완성"},
	{"id": CAT_UNLOCK_ALL, "cond": "디자인 냥이 6종 전부 해금"},
	{"id": CAT_MAX_GRADE, "cond": "아무 냥이나 등급 4 달성"},
	{"id": GACHA_100, "cond": "키캡 가챠 누적 100장"},
	{"id": GOLD_10K, "cond": "누적 골드 10,000 획득"},
	{"id": CUSTOM_CAT, "cond": "냥이 크리에이터로 커스터마이징 저장", "ev": true},
	{"id": REPLAY_WATCH, "cond": "랭킹에서 남의 리플레이 재생", "ev": true},
	{"id": LEVEL_10, "cond": "계정 레벨 10"},
	{"id": LEVEL_25, "cond": "계정 레벨 25"},
	{"id": LEVEL_50, "cond": "계정 레벨 50 (만렙)"},
]

const GACHA_GOAL := 100
const GOLD_GOAL := 10000


func has(id: String) -> bool:
	return id in GameState.achv


## 업적 하나를 해금한다. 이미 딴 것이면 아무 일도 없다.
func unlock(id: String) -> void:
	if has(id):
		return
	GameState.achv.append(id)
	GameState.save_game()
	Platform.unlock_achievement(id)


## 조건이 참일 때만 해금 — 상태형 판정의 공통 진입점.
func unlock_if(cond: bool, id: String) -> void:
	if cond:
		unlock(id)


## 세이브 상태로 판정되는 업적을 전부 훑는다. 소급 적용이므로 아무 때나
## 불러도 안전하고, 여러 번 불러도 이미 딴 것은 걸러진다.
func check() -> void:
	unlock_if(GameState.best_height >= 25, HEIGHT_25)
	unlock_if(GameState.best_height >= 50, HEIGHT_50)
	unlock_if(GameState.best_height >= 100, HEIGHT_100)
	unlock_if(GameState.classic_level_best >= 5, CLASSIC_LV5)
	unlock_if(GameState.classic_level_best >= 10, CLASSIC_LV10)
	unlock_if(GameState.classic_best >= 100000, CLASSIC_100K)
	unlock_if(GameState.gacha_drawn >= GACHA_GOAL, GACHA_100)
	unlock_if(GameState.gold_earned >= GOLD_GOAL, GOLD_10K)
	var lv := Account.level()
	unlock_if(lv >= 10, LEVEL_10)
	unlock_if(lv >= 25, LEVEL_25)
	unlock_if(lv >= Account.LEVEL_MAX, LEVEL_50)
	_check_cats()


## 키캡·등급으로 판정되는 것들. 나만의 캐릭터(mycat)는 키캡을 모으지 않으므로
## keycap_cats()로 디자인 냥이만 센다.
func _check_cats() -> void:
	var cats := GameState.keycap_cats()
	var unlocked := 0
	for cat: Dictionary in cats:
		var id := str(cat.id)
		if GameState.cat_grade(id) >= 1:
			unlocked += 1
		unlock_if(GameState.keycap_total(id) > 0, KEYCAP_FIRST)
		unlock_if(GameState.keycap_sets(id) >= 1, KEYCAP_RING)
		unlock_if(GameState.cat_grade(id) >= GameState.KEYCAP_GRADE_MAX, CAT_MAX_GRADE)
	unlock_if(not cats.is_empty() and unlocked == cats.size(), CAT_UNLOCK_ALL)
