# 캣트리스 (Cat-Tris) 전체 기획서 (GDD)

| 항목 | 값 |
|---|---|
| 최종 수정일 | 2026-10-09 |
| 게임 버전 | 0.1.0 (`project.godot` `config/version`) |
| 기준 브랜치 / 커밋 | `main` / `e59c1c8` |
| 엔진 | Godot 4.6 (2D, `config/features` = 4.6 / Forward Plus, 모바일은 `gl_compatibility`) |

이 문서는 **지금 구현된 동작**을 적는다. 코드와 다르면 코드가 기준이고 이 문서가 틀린 것이다.
경로는 모두 `dev\` 기준이다. 세부 기획서는 [9절](#9-세부-기획서-목록), 기존 문서와 코드가 어긋나는 점은 [10절](#10-문서와-구현의-차이)에 있다.

---

## 1. 개요

| 항목 | 내용 |
|---|---|
| 한 줄 소개 | 구덩이에 빠진 큐브 고양이가 떨어지는 테트리스 블록을 밟고 위로 올라가는 게임 (`MENU_TAGLINE`: "구덩이에 빠진 큐브 고양이의 탈출극") |
| 장르 | 테트리스 규칙 + 플랫포머 액션 (블록은 고양이를 따라오다 떨어지고, 플레이어는 고양이를 조작한다) |
| 플랫폼 | Steam PC (Windows x86_64) / 모바일 세로 (Android arm64 APK) / 웹 (PC판 + 모바일 세로판) |
| 해상도 | PC·웹 1920×1080 가로, 모바일 1080×1920 세로. stretch `canvas_items`, 모바일 aspect `expand` (`project.godot` `[display]`) |
| 입력 | 키보드, 게임패드, 터치 |
| 타깃 유저 | 확인 못 함 (코드·문서에 명시 없음) |
| 인원 | 1인 (2인 플레이는 2026-08-31 제거) |

---

## 2. 핵심 루프

```
타이틀(좌석 냥이 세팅) → 모드 선택 → 한 판 플레이 → 결과창(골드·경험치 정산)
      ↑                                                        │
      └── 상점에서 골드로 키캡 뽑기 → 냥이 해금·등급업 → 꾸미기 ┘
                    주간 랭킹 보상(골드·캔) → 유니크 냥이 뽑기
```

- 한 판: 블록이 고양이 머리 위에서 따라다니다 떨어진다 → 쌓인 블록을 밟고 오른다 → 깔리거나(두 모드) 용암에 닿으면(무한) 끝.
- 판 밖: 골드 → 키캡 뽑기 → 캐릭터 해금·등급(파츠) → 나만의 캐릭터 꾸미기. 계정 레벨은 플레이로만 오른다.

### 게임 모드 (2종)

정의: `core/autoload/game_state.gd` `MODE_*`, `core/scripts/escape_board.gd` `enum Mode`. 모드 번호 0·2·4는 제거된 모드(스토리·2P 대전·젤리 피크닉) 자리로 비워 둠.

| | 스테이지 모드 | 무한의 계단 |
|---|---|---|
| 내부 값 / 랭킹 키 | `MODE_CLASSIC`=3 / `classic` | `MODE_ENDLESS`=1 / `endless` |
| 필드 | 10열×20줄 밀폐 우물, 화면 고정 | 같은 폭 우물, 카메라가 고양이를 따라 위로 |
| 목표 | LEVEL마다 목표 줄을 지워 다음 판으로. 점수 경쟁 | 최대한 높이 오르기. 층수 경쟁 |
| 패배 | 블록에 깔림, 스택이 우물 위로 넘침, 새 블록이 스택 안에 스폰 | 용암에 발이 닿음, 깔림, 락된 칸이 화면 위 끝에 닿음 |
| 고유 요소 | 레벨 클리어 셔터, 방해 블록 | 용암, 피버타임, 기록선, 10층 마일스톤 |
| 기록 | 최고 점수 `classic_best`, 최고 LEVEL `classic_level_best` | 최고 높이 `best_height` |

---

## 3. 인게임 시스템

### 3.1 블록 규칙

수치 위치: `core/scripts/escape_board.gd` 머리의 상수, 도형·회전표는 `core/scripts/board.gd`.

| 항목 | 값 |
|---|---|
| 우물 | `COLS`=10, `PIT_ROWS`=20, `CELL`=64px |
| 블록 | 테트로미노 7종 (I O T S Z J L), 7-bag 무작위, NEXT 1개 예고 |
| 회전 | SRS + 월킥 (`Board.KICKS_JLSTZ`/`KICKS_I`). **매달려 있는 동안(추적 중)에만** 가능, O는 회전 없음 |
| 추적 | 블록이 `TRACK_STEP`=0.07초마다 한 칸씩 고양이 열을 따라온다 |
| 놓기 | 추적 시간이 끝나거나 낙하 키를 누르면 분리되어 자유낙하(`loose`), **다음 블록이 즉시** 나온다. 단 **새 블록이 나온 뒤 `DROP_LOCK_TIME`=1.0초 동안은 낙하 키로 놓을 수 없다**(연타로 블록이 줄줄이 떨어지는 것 방지. 추적 시간이 1초보다 짧으면 그 시간까지만) |
| 빠른 낙하 | 낙하 키를 누르고 있으면 낙하 간격 ÷ `SOFT_DROP_FACTOR`=4 |
| 하드드롭 | 낙하 키를 `DROP_DOUBLE_TAP`=0.3초 안에 두 번 → 방금 놓은 블록을 바닥까지 (놓기 잠금 중에도 통한다) |
| 락 | 착지 후 `LOCK_GRACE`=0.7초 동안 밀 수 있고 그 뒤 격자에 박힌다 |
| 줄 클리어 | 스테이지: 줄 단위로 통째 내림 / 무한: 줄만 비우고 받침을 잃은 덩어리만 내려앉음(`_settle_grid()`) |
| 홀드 | 없음 (`hold_piece` 입력 액션은 정의만 있고 `escape_board.gd`가 읽지 않는다) |
| 깔림 | 블록과 겹치면 아래→좌우 순으로 밀려나고, 밀려날 곳이 없으면 사망 (`CRUSH_MARGIN`=6px 여유) |

### 3.2 고양이 조작

수치 위치: `core/scripts/player.gd`. 캐릭터 능력치(§4.4)가 배율로 곱해진다.

| 동작 | 값 |
|---|---|
| 몸 크기 | `SIZE`=50px (칸 64px) |
| 달리기 | `RUN_SPEED`=330 px/s × speed |
| 점프 | `JUMP_VEL`=-840 × jump, 코요테 `COYOTE`=0.1초, 입력 버퍼 `JUMP_BUFFER`=0.12초 |
| 중력 | `GRAVITY`=2300, 최대 낙하 `MAX_FALL`=1300. 낙하 키로 빠른 낙하 ×`FAST_FALL_FACTOR`=2.2 × weight |
| 풍선 점프 (테스트 중) | 공중에서 점프를 다시 누르면 몸이 부풀어 뜨고, 누를 때마다 위로 `float_flap_velocity`=-430 × jump. 부푼 동안 중력 `float_gravity`=900, 가만히 두면 `float_max_fall`=140 px/s로 가라앉음, 좌우 이동 ×`float_move_factor`=0.75. **최대 높이는 마지막으로 디딘 자리에서 `float_max_height_cells`=5칸**(320px, 일반 점프는 약 2.4칸). 착지·낙하 키·대시로 바람이 빠진다. 부푼 동안은 머리 박기로 블록을 못 부순다. 그림만 `float_puff_scale`=1.28배로 커지고 판정 크기는 그대로. 값은 전부 `player.gd`의 `@export`(인스펙터 "풍선 점프" 묶음) |
| 벽 | 벽 미끄럼 `WALL_SLIDE_SPEED`=160. 벽 점프는 제거됨 (2026-10-08, 풍선 점프로 대체) |
| 대시 | 같은 방향 두 번(`DOUBLE_TAP`=0.3초) 또는 대시 키. `DASH_SPEED`=850 × dash, 0.22초, 쿨다운 0.25초 ÷ dash |
| 대시 충돌 | 떨어지는/착지한 블록을 `push`칸 밀거나, 박힌 블록 한 칸을 친다. 튕겨남 `KNOCKBACK_SPEED`=420 ÷ weight |
| 블록 부수기 | 대시·머리 박기(바닥 점프로 위 블록, 풍선 점프 중에는 불가). 일반 블록은 **두 번**(1타 금 감 → 2타 파괴), 금 블록은 한 번, 피버 암반은 불가 |

**기본 키** (`project.godot` `[input]`, 재설정은 `core/scripts/key_binds.gd`)

| 액션 | 키보드 기본 | 패드 기본 |
|---|---|---|
| 좌우 이동 | ← → | LS / D-pad (고정) |
| 점프 (공중에서 다시 = 풍선 점프) | ↑, Space | A |
| 대시 | Shift (또는 좌우 두 번) | X |
| 낙하(놓기·가속·두 번=하드드롭) | ↓ | RT, D-pad ↓ |
| 회전 반시계 / 시계 | Z / X | LB / RB |
| 일시정지 | P | Start |
| 다시 시작 / 타이틀로 | R / Esc | (없음) |

`hard_drop`(Space)·`hold_piece`(C, Shift) 액션은 입력 맵에 남아 있으나 실제 보드는 쓰지 않는다.

**터치** (`core/scripts/touch_*.gd`, 세로 배치는 `mobile/ui/main_mobile.tscn`): 왼쪽 이동 패드(◀▶, 두 번 두드리면 대시), 오른쪽 점프(공중에서 다시 누르면 풍선 점프)·회전(시계)·낙하 버튼, ⏸ 버튼. 모바일 빌드는 항상, 그 외는 터치스크린이 있을 때만 표시.

### 3.3 점수

| 사건 | 스테이지 모드 | 무한의 계단 |
|---|---|---|
| 블록 락 | 10 × LEVEL | 10 (LEVEL이 1로 고정) |
| 줄 클리어 1/2/3/4줄 | 40 / 100 / 300 / 1200 × LEVEL (`Board.CLASSIC_SCORES`) | 100 / 300 / 500 / 800 (`LINE_SCORES`) |
| 블록 부수기 | 20 (`BREAK_SCORE`) | 20 |
| 새로 오른 층 | — | 10 / 층 (`HEIGHT_SCORE`) |
| 셔터 빈 줄 보너스 | 100 × LEVEL / 빈 줄 (`Board.CLASSIC_EMPTY_ROW_BONUS`) | — |

콤보 카운터(`combo`)는 연출과 피버 게이지에만 쓰이고 점수 배율은 없다.

### 3.4 난이도

**스테이지 모드** (`core/scripts/board.gd`)

| 항목 | 규칙 |
|---|---|
| 목표 줄 | `classic_quota(lv)` = min(3 + lv − 1, 10) → LV1 3줄, LV8부터 10줄 |
| 속도 단계 | `classic_speed(lv)` = 1 + (lv−1)/2 (두 LEVEL마다 +1, 최대 30단계) + 마라톤 크립 |
| 속도표 | `CLASSIC_FRAMES` = 48,43,38,33,28,23,18,13,8,6,5,5,5,4,4,4,3,3,3,2,…,1 (60fps 기준 줄당 프레임) |
| 추적 시간 | 5.0초 × frames/48, 1.0~5.0초로 제한 |
| 낙하 간격 | 0.26초 × frames/48, 0.03~0.26초로 제한 |
| 방해 블록 | LV5부터 1줄, LEVEL마다 +1, 최대 6줄 (`classic_garbage`). 줄마다 구멍 1~2칸 |
| 레벨 클리어 | 목표 달성 → 셔터가 스택 높이까지 내려오며 빈 줄 보너스 지급 → 남은 블록 파괴 → 다음 LEVEL 판을 깔고 다시 올라감 (전 과정 자동, 그동안 사망 없음) |
| 셔터 타이밍 | 내려올 때 줄당 0.075초, 멈춤 0.4초, 올라갈 때 줄당 0.028초 |

**무한의 계단** (`core/scripts/escape_board.gd`)

| 항목 | 규칙 |
|---|---|
| 난이도 값 | d = 1 + 최고 높이 / 8 |
| 추적 시간 | max(5.0 − (d + 크립 − 1) × 0.4, 2.0)초 |
| 낙하 간격 | max(0.26 − (d + 크립 − 1) × 0.02, 0.1)초 |
| 용암 속도 | min(8 + (d − 1) × 2, 45) px/s. 시작 위치는 바닥 아래 3칸 |
| 용암 따라붙기 | 고양이보다 980px(`LAVA_MAX_GAP`, 약 15칸) 넘게 뒤처지지 않는다 |
| 줄 클리어 보상 | 용암을 0/2/5/9/15칸 밀어냄 (`LAVA_PUSH`, 1~4줄) |
| 마일스톤 | 10층마다 배너, 50층 단위는 큰 배너 (`main.gd` `_show_milestone()`) |
| 기록선 | 자기 최고 높이에 금색 점선 |

**마라톤 크립 (두 모드 공통)**: 플레이 45초마다 속도 +1단계, 최대 +8 (`SPEED_CREEP_TIME`/`_MAX`). 무한은 낙하에만 적용되고 용암 속도에는 적용 안 됨.

### 3.5 피버타임 (무한의 계단 전용)

상수: `escape_board.gd` `FEVER_*`. 게이지 0~100, 시간으로는 차지 않는다.

| 게이지 수입 | 값 |
|---|---|
| 최고 높이 갱신 | +3 / 칸 |
| 일반 블록 부수기 | +3 |
| 금 블록 직접 깨기 | +6 |
| 발끝 세이브 (용암과 발 거리 2.2칸 이내) | +18 / 초 |
| 줄 클리어 1/2/3/4줄 | +8 / 20 / 36 / 60, 콤보 단계마다 +5 |

| 발동 효과 | 값 |
|---|---|
| 지속 | 3.4초. 블록·용암이 멈추고 고양이가 스택을 뚫고 솟구친다 (조작은 좌우만, 배율 1.35) |
| 상승 속도 | 0.5초에 걸쳐 560 px/s까지 가속 |
| 용암 | 발동 순간 6칸 밀어냄 |
| 코인 비 | 시작 시 14개 + 초당 16개, 하나당 골드 8, 상승 속도 +2% (최대 +35%) |
| 종료 | 발밑에 우물 폭 전체 암반을 깐다. 암반은 지워지지도 부서지지도 않는다 |
| 연쇄 방지 | 발동 중에는 게이지가 차지 않는다 |

### 3.6 골드 블록

| 항목 | 값 (`escape_board.gd` `ORE_*`) |
|---|---|
| 출현 | 떨어지는 블록마다 10% 확률로 네 칸 중 하나에 금 |
| 방해 블록 | 스테이지 모드 방해 줄마다 35% 확률로 금 한 칸 |
| 직접 깨기 / 줄 클리어 | 20 골드 |
| 셔터가 쓸어 감 | 10 골드 |
| 지급 | 즉시 지갑에 반영, 세이브는 판 종료·타이틀 복귀 때 한 번 |

### 3.7 인게임 화면

- 계기판: NEXT, 큰 숫자(스테이지=LEVEL, 무한=층수), TOP SCORE/BEST, SCORE, LINES(스테이지는 목표 타일 랙 `goal_meter.gd`), 피버 게이지(`fever_meter.gd`). 배치는 `main.gd` `_layout_stat_column()`(가로) / `_layout_stat_column_portrait()`(세로).
- 가로 좌하단 조작 안내 카드는 실제 키 바인딩으로 그린다.
- 일시정지: 딤 + [타이틀로][이어하기] (`settings_panel.gd` `open(false)`).
- 결과창(`death_popup.gd`): 통계 3열, 획득 골드, 경험치 게이지, [타이틀로][다시 도전]. 골드 → 경험치 순서로 연출하고 레벨이 오르면 레벨업 팝업.
- 타격감 연출(흔들림·히트스톱·먼지·파편·배너)과 진동은 `escape_board.gd` "타격감" 구획 상수에 있다.

---

## 4. 메타 시스템

### 4.1 재화·경제

정의: `core/autoload/game_state.gd`, 판 보상은 `core/scripts/main.gd` `_award_run_rewards()`.

| 재화 | 들어오는 곳 | 쓰는 곳 |
|---|---|---|
| 골드 | 판 정산, 골드 블록, 피버 코인, 레벨업 보상, 주간 랭킹 1~3위 | 키캡 뽑기(랜덤·선택), 파츠 전용 옵션 구매 |
| 통조림 캔 | **주간 랭킹 보상뿐** (100위까지) | 유니크 냥이 키캡 뽑기, 유니크(`"u"`) 파츠 전용 옵션 구매 |

| 골드 수입 | 값 |
|---|---|
| 무한의 계단 정산 | 높이 × 3 |
| 스테이지 모드 정산 | 점수 ÷ 40 |
| 하루 첫 보상 판 | 정산 골드 2배 (`claim_daily_bonus()`, 날짜는 기기 시계) |
| 골드 블록 / 피버 코인 | §3.6 / §3.5 |
| 레벨업 | §4.2 |
| 주간 랭킹 | §4.6 |

보석·부활·부스트·액세서리 상점은 제거됐다. 과거 설계 기록은 [economy.md](economy.md) (대부분 폐기, §10 참고).

### 4.2 계정 레벨

정의: `core/autoload/account.gd`. 플레이로만 오른다.

| 항목 | 값 |
|---|---|
| 만렙 | 50 (`LEVEL_MAX`) |
| 레벨업 필요 경험치 | min(120 + 60 × (lv − 1), 1500). 코드 주석 기준 만렙까지 약 57,000 |
| 한 판 경험치 | 참가 10 + 성적 + 기록 갱신 25, 한 판 상한 400 |
| 성적 (무한) | 높이 × 2 |
| 성적 (스테이지) | 점수 ÷ 150 + LEVEL × 5 |
| 레벨업 보상 | 골드 min(100 + 20 × (lv − 1), 500), 5레벨마다 2배 |
| 칭호 | 10레벨마다: 아깽이 / 골목대장 / 블록 타기 선수 / 탑 오르는 냥이 / 전설의 냥이 (`MENU_TIER_1~5`) |

### 4.3 캐릭터 해금·등급 (키캡 수집)

정의: `game_state.gd` `KEYCAP_*`, `cat_grade()`.

- 냥이마다 키캡 A~Z를 따로 모은다. **한 바퀴(26장)마다 등급 +1**, 등급 0(잠김)~4.
- 등급 1 = 해금(기본 모습), 등급 2~4 = 1st/2nd/3rd 파츠가 붙은 모습.
- 첫 캐릭터 크림만 첫 바퀴를 갖고 시작한다. 나머지는 키캡을 모아야 합류한다.
- 키캡은 **상점 뽑기로만** 얻는다 (인게임 드랍 없음). 중복은 나오지 않는다: 늘 이번 바퀴에 비어 있는 글자만 나온다.
- 필요 장수: 일반 냥이 104장(26×4), 크림 78장.

### 4.4 캐릭터 능력치

`game_state.gd` `CATS[].stats`. 배율 1.0 = 크림 기준. UI에는 표시하지 않고 `player.gd`만 읽는다. 표는 §5.1.

- speed 달리기 / jump 점프 / dash 대시 속도·쿨다운 / weight 빠른 낙하 가속·넉백 저항 / push 대시로 블록을 미는 칸 수

### 4.5 상점 (키캡 뽑기)

UI: `core/scripts/title.gd` `_build_gacha*`. 값: `game_state.gd` `keycap_price()`.

| 뽑기 | 재화 | 풀 | 1장 | 10장 |
|---|---|---|---|---|
| 랜덤 (`GACHA_RANDOM`) | 골드 | 유니크가 아니고 만렙이 아닌 냥이 전체, 균등 | 30 | 250 |
| 선택 (`GACHA_PICK`) | 골드 | 걸어 둔 5마리(`KEYCAP_PICK_SIZE`) | 45 (×1.5) | 375 |
| 캔 (`GACHA_CAN`) | 캔 | 걸어 둔 유니크 냥이 1종 | 1 | 9 |

- 한 번에 1~10장(`KEYCAP_GACHA_MAX`)을 스테퍼로 고른다. 풀에 남은 키캡보다 많이는 못 뽑고, 덜 나온 몫은 환불된다.
- 만렙 냥이는 풀에서 빠진다. 열마다 따로 품절된다.
- 등급이 오르면 결과 연출 뒤 해금 안내 팝업이 뜬다.
- 계산값: 골드 냥이 전원 만렙 = 13종 × 104 + 크림 78 = 1,430장 (10장 묶음가 기준 약 35,750 골드). 유니크 2종 만렙 = 208장 (10장 묶음가 기준 약 188캔).

### 4.6 랭킹·주간 보상

정의: `core/autoload/ranks.gd`.

| 항목 | 값 |
|---|---|
| 보드 | 모드 2종 × (누적 / 주간) |
| 주간 초기화 | 월요일 00:00 KST (`WEEK_ANCHOR`=313200, `WEEK_LEN`=604800) |
| 주간 골드 | 1~3위 500 / 300 / 200 (`WEEKLY_REWARDS`) |
| 주간 캔 | 1위 10, ~3위 8, ~5위 7, ~10위 6, ~20위 5, ~30위 4, ~50위 3, ~75위 2, ~100위 1 (`WEEKLY_CANS`) |
| 표시 | 상위 50 (`STEAM_FETCH`), HTTP 보드는 모드당 100 엔트리 유지 |
| 닉네임 | 최대 12자. 스팀은 페르소나 이름을 쓰고, 사용자가 직접 바꾸면 그 이름 유지 |

**백엔드 선택 순서** (`Ranks.backend()`)

| 순서 | 백엔드 | 조건 | 주간 시상 |
|---|---|---|---|
| 1 | STEAM | 스팀 빌드 + 스팀 초기화 성공 | 클라이언트가 지난주 보드에서 내 순위를 읽음 (랭킹 화면을 열 때) |
| 2 | SERVER (Supabase) | 스팀이 아니고 `cattris/cloud/url`·`anon_key`가 채워져 있음 | 서버 cron이 정산, 클라이언트는 청구만 |
| 3 | HTTP (jsonblob) | `Ranks.BOARD_URL`이 채워져 있음 | 클라이언트가 blob에서 읽음 |
| 4 | OFFLINE | 위가 모두 아님 | 없음. 봇 24명 + 내 기록 표시 |

현재 설정: 스팀 앱 id 480(Valve 테스트 앱), Supabase 설정 비어 있음 → 스팀이 아닌 빌드는 HTTP(jsonblob) 백엔드로 돈다.

### 4.7 리플레이

- 기록: 10Hz 상태 프레임 + 격자 변경 이벤트, 최대 6000프레임(약 10분) (`escape_board.gd` `REC_*`).
- 저장: 모드별 최고 기록 판만 `user://replay_<mode>.dat` (`core/autoload/replays.gd`).
- 공유: 누적 보드 엔트리에 첨부. 스팀은 UGC 파일, HTTP는 base64(상위 10명만 유지, 90,000자 상한), 서버는 60,000자 상한.
- 재생: 랭킹 화면에서 엔트리를 눌러 `core/scripts/replay_viewer.gd`로 본다 (재생/속도/진행 바).
- 한계: 리플레이에는 금 블록이 남지 않는다 (CLAUDE.md 기재).

### 4.8 업적 (18개)

정의·판정: `core/autoload/achievements.gd` (`Achv`). 해금 기록은 세이브의 `achv`. 표시 이름은 `shared/locale/ui.csv` `ACHV_<ID>_NAME`.

| id | 이름(한국어) | 조건 |
|---|---|---|
| FIRST_ESCAPE | 첫 발자국 | 무한의 계단 한 판 종료 (사건형) |
| HEIGHT_25 / 50 / 100 | 슬금슬금 / 하늘 절반 / 구름 위 냥이 | 무한 최고 높이 25 / 50 / 100층 |
| CLASSIC_LV5 / LV10 | 다섯 판째 / 열 번의 셔터 | 스테이지 모드 LEVEL 5 / 10 도달 |
| CLASSIC_100K | 십만 점 | 스테이지 모드 최고 점수 100,000 |
| KEYCAP_FIRST | 첫 키캡 | 키캡 1장 보유 |
| KEYCAP_RING | 에이 투 지 | 아무 냥이 A~Z 한 바퀴 |
| CAT_UNLOCK_ALL | 다 모였다 | 키캡을 모으는 냥이 전부(현재 16종) 해금 |
| CAT_MAX_GRADE | 만렙 냥이 | 아무 냥이 등급 4 |
| GACHA_100 | 캡슐 중독 | 뽑기 누적 100장 |
| GOLD_10K | 금맥 사냥꾼 | 누적 획득 골드 10,000 |
| CUSTOM_CAT | 나만의 냥이 | 꾸미기 저장 (사건형) |
| REPLAY_WATCH | 관중석 | 랭킹에서 남의 리플레이 재생 (사건형) |
| LEVEL_10 / 25 / 50 | 단골 / 고인물 / 캣트리스 마스터 | 계정 레벨 10 / 25 / 50 |

- 상태형은 `Achv.check()`가 세이브 값으로 소급 판정한다 (판 종료, 뽑기, 타이틀 진입, 레벨업, LEVEL 갱신).
- 표시: 스팀은 오버레이(게임 안 목록 없음), 모바일은 타이틀 메뉴의 `업적` 화면(`mobile/ui/achievements_panel.gd`), 웹은 목록 화면 없음(DEV 패널로만 확인).
- 스팀 등록 절차: [steam_setup.md](steam_setup.md) ③.

### 4.9 나만의 캐릭터 (꾸미기)

정의: `core/scripts/custom_cat.gd` (`PARTS`, `GROUPS`, `CHARS`), UI `core/scripts/cat_customizer.gd`.

| 항목 | 값 |
|---|---|
| 슬롯 | 1개로 시작, `+` 타일로 최대 3개 (`MYCAT_SLOT_MAX`). 여는 값은 무료 |
| 부위 | 21개 (`PARTS`), 화면에서는 15개 묶음(`GROUPS`)으로 표시 |
| 해금 규칙 | 냥이의 파츠 = 그 냥이를 해금(등급 1)하면 전부 열림, 팔지 않음 / 파츠 전용 옵션(히든 파츠) = 구매 / 백지 기본값·"없음" = 처음부터 열림 |
| 파츠 전용 가격 | 희귀도 r 0~3 → 골드 200 / 400 / 800 / 1500, 색 150 (`PART_PRICES`, `PART_COLOR_PRICE`) |
| 유니크(`"u"`) 가격 | 캔 5 / 8 / 15 / 25 (`PART_CAN_PRICES`). 현재 `"u"` 6개는 모두 냥이 파츠라 실제로 캔 값이 적용되는 옵션은 없다 |
| 저장 | 고르는 즉시 저장. `cat_custom[냥이 id]`, 산 파츠는 계정 단위 `parts_owned` |
| 능력치 | 크림과 같은 기준값 |

디자인 냥이는 꾸미기 대상이 아니다. 대표 캐릭터(`feature_cat`)는 유저 HUD 아바타에만 쓰이고, 플레이에 나가는 것은 좌석 냥이(`selected_cat`)다.

### 4.10 저장·계정·클라우드

| 항목 | 내용 |
|---|---|
| 로컬 세이브 | `user://save.json` 한 파일 (`GameState.save_dict()`): 기록, 지갑, 경험치, 키캡, 꾸미기, 설정, 키 바인딩, 업적 등 |
| 식별 | 첫 실행 때 `player_id`(무작위 8자리 16진수)와 기본 닉네임 `냥이-XXXX` 생성 |
| 게임 초기화 | 설정에서 진행도 전체 삭제. 음량·언어·닉네임·`player_id`·업적 기록은 유지 (`reset_all()`) |
| 스팀 | 클라우드 세이브는 파트너 사이트 Auto-Cloud 설정에 맡기는 구조. `steam_platform.gd` `sync_cloud_save()`(업로드 전용)는 있으나 게임 코드에서 부르는 곳을 찾지 못했다 |
| 모바일 서버 | `core/autoload/cloud.gd` (Supabase): 익명 로그인, 세이브 백업(저장 5초 뒤 업로드, `rev`가 큰 쪽이 최신), 리더보드, 주간 보상 청구. 토큰은 `user://cloud.json`. **설정이 비어 있어 현재 꺼져 있다** |
| 서버 스키마 | `server/supabase/schema.sql`: `scores`, `saves`, `rewards` 테이블, `settle_week`/`claim_rewards`/`week_cans` 함수, cron 2개(일요일 15:05·15:20 UTC) |
| 신뢰 모델 | 골드·키캡·레벨의 주인은 로컬 세이브. 서버는 랭킹·주간 정산·세이브 백업만 |

세팅 절차: [cloud_setup.md](cloud_setup.md), [steam_setup.md](steam_setup.md). 사용자 작업 목록: [my_tasks.md](my_tasks.md).

### 4.11 설정

`core/scripts/settings_panel.gd`. 타이틀에서는 전체 화면 페이지, 인게임에서는 일시정지 메뉴.

| 항목 | 값 |
|---|---|
| 해상도 (데스크톱만) | 1280×720, 1600×900, 1920×1080, 2560×1440, 3840×2160 |
| 언어 | §4.12 |
| 음량 | 전체 1.0 / BGM 0.8 / SFX 1.0 (기본값) |
| 진동 | 0~3 (기본 2). 패드 진동 + 모바일·웹 기기 진동 |
| 조작 | 키보드 8행·패드 6행 재설정, 기본값 복구 |
| 게임 초기화 | 타이틀에서만 |

### 4.12 다국어

| 항목 | 내용 |
|---|---|
| 번역 파일 | `shared/locale/ui.csv`(293행), `content.csv`(44행), `flavor.csv`(36행) |
| **실제 번역 열** | `en`, `ko`, `en_XA`(레이아웃 점검용 의사 로케일, 디버그 빌드에서만 선택 가능) |
| 언어 선택 목록 | `I18n.LOCALES` 13개: en, ko, zh_CN, ja, ru, es_MX, de, fr, pt_BR, tr, pl, it, zh_TW |
| 기본 | 시스템 언어 자동 감지, 없으면 영어 (`core/autoload/i18n.gd`) |
| 폰트 | Paperlogy 5굵기 + Noto Sans KR 폴백 (`shared/assets/fonts/`) |

en·ko 외 11개 언어는 선택 목록에는 있으나 CSV에 번역 열이 없다.

### 4.13 사운드

`core/autoload/sfx.gd`. 음원 파일 없이 전부 코드로 합성한다 (22,050Hz).

| 종류 | 목록 |
|---|---|
| 효과음 24종 | jump, puff(풍선 점프), dash, land, lock, rotate, harddrop, impact, clear, combo, crack, break, shove, gold, shutter, fever, milestone, record, death, pause, click, buy, error, escape |
| BGM 2종 | `title`, `game` (첫 재생 때 렌더) |
| 버스 | Master / BGM / SFX (런타임 생성) |

회사 로고 스플래시의 소리는 `addons/wonderwheel_splash/`가 따로 가진다.

---

## 5. 콘텐츠 목록

### 5.1 캐릭터 (디자인 냥이 16종 + 나만의 캐릭터)

데이터: `core/autoload/game_state.gd` `CATS`, 이름·소개 `shared/locale/content.csv`, 파츠 단계 `core/scripts/custom_cat.gd` `CHARS`, 그림 `shared/assets/cats/charNN_tT.png`.

| id | 이름 | 그림 | 해금 | 특성 | speed | jump | dash | weight | push | 1st → 2nd → 3rd 파츠 |
|---|---|---|---|---|---|---|---|---|---|---|
| cream | 크림 | char01 | 시작 지급 | 밸런스 | 1.00 | 1.00 | 1.00 | 1.00 | 2 | 머그컵 → 귤(머리) → 꼬리 |
| black | 까망 | char02 | 골드 키캡 | 질주본능 | 1.15 | 1.00 | 1.05 | 0.90 | 2 | 넥타이·배지 → 선글라스 → 꼬리 |
| cheese | 치즈 | char03 | 골드 키캡 | 헤비급 | 0.92 | 0.96 | 1.00 | 1.30 | 3 | 헤드셋 → 키보드 → 꼬리 |
| sleepy | 잠꾸러기 | char04 | 골드 키캡 | 꿈나라 | 0.95 | 1.08 | 0.95 | 0.95 | 2 | 수면 안대 → 랜턴 → 꼬리 |
| wizard | 마법사 | char05 | **캔 키캡 (유니크)** | 마법사 | 1.02 | 1.02 | 1.12 | 0.90 | 3 | 마법사 모자 → 수정 구슬 → 꼬리 |
| gray | 회색 | char06 | **캔 키캡 (유니크)** | 묵직점프 | 0.94 | 1.06 | 0.90 | 1.20 | 3 | 나비넥타이 → 책 → 꼬리 |
| baker | 제빵사 | char07 | 골드 키캡 | 밸런스 | 1.00 | 1.02 | 0.98 | 1.05 | 2 | 요리사 모자 → 컵케이크 → 꼬리 |
| pirate | 선장 | char08 | 골드 키캡 | 헤비급 | 0.95 | 0.96 | 1.05 | 1.25 | 3 | 해적 모자 → 보물 상자 → 꼬리 |
| space | 코스모 | char09 | 골드 키캡 | 꿈나라 | 0.98 | 1.10 | 0.95 | 0.90 | 2 | 별 더듬이 → 로켓 → 꼬리 |
| ninja | 그림자 | char10 | 골드 키캡 | 질주본능 | 1.15 | 1.02 | 1.10 | 0.85 | 2 | 머리띠 → 카타나(등) → 꼬리 |
| painter | 팔레트 | char11 | 골드 키캡 | 밸런스 | 1.02 | 1.00 | 1.02 | 1.00 | 2 | 베레모 → 팔레트 → 꼬리 |
| strawberry | 딸기 | char12 | 골드 키캡 | 꿈나라 | 0.96 | 1.08 | 0.96 | 0.92 | 2 | 딸기 비니 → 딸기우유 → 꼬리 |
| prince | 왕자 | char13 | 골드 키캡 | 묵직점프 | 0.94 | 1.05 | 0.92 | 1.18 | 3 | 왕관 → 망토 → 꼬리 |
| summer | 써니 | char14 | 골드 키캡 | 질주본능 | 1.12 | 0.98 | 1.05 | 0.95 | 2 | 꽃 레이 → 수박 → 꼬리 |
| rainy | 보슬 | char15 | 골드 키캡 | 마법사 | 1.00 | 1.04 | 1.10 | 0.90 | 3 | 레인햇 → 우산(등) → 꼬리 |
| cow | 음메 | char16 | 골드 키캡 | 헤비급 | 0.90 | 0.95 | 1.00 | 1.32 | 3 | 방울 목줄 → 벙거지 → 꼬리 |
| mycat (+mycat2, 3) | 나만의 캐릭터 | 파츠 조합 | 시작 지급 | 직접 만든 냥이 | 1.00 | 1.00 | 1.00 | 1.00 | 2 | 해당 없음 |

- 신규 10종(char07~16)의 컨셉·파츠 구성: [new_cats_10.md](new_cats_10.md). 능력치·특성은 그 문서에서 "가안"으로 표시돼 있다.
- 파츠 이름은 `custom_cat.gd`의 옵션 id를 옮긴 것이다.

### 5.2 꾸미기 파츠

데이터: `core/scripts/custom_cat.gd` `PARTS`. 옵션 수는 코드의 옵션 항목 수를 센 값이다 ("없음" 포함 여부는 확인 못 함).

| 부위 (key) | 종류 | 옵션 수 | 그중 히든 |
|---|---|---|---|
| 머리 소품 `head` | 모양 | 26 | 12 |
| 눈 `eyes` | 모양 | 25 | 9 |
| 입 `mouth` | 모양 | 23 | 9 |
| 배 소품 `hold` | 모양 | 22 | 9 |
| 꼬리 `tail` / 귀 모양 `ear_shape` / 무늬 `pattern` | 모양 | 13 / 13 / 13 | 0 |
| 수염 `whisker` | 모양 | 12 | 0 |
| 등 소품 `back` | 모양 | 7 | 3 |
| 가슴 소품 `chest` / 이마 장식 `mark` / 얼굴 소품 `face` | 모양 | 6 / 5 / 4 | 0 |
| 몸 색 `body` / 발바닥 `pad_col` / 귀 색 `ear` | 색 | 12 / 8 / 7 | — |
| 무늬 색 `pattern_col` / 입 색 `mouth_col` / 눈 색 `eye_col` | 색 | 4 / 4 / 2 | — |
| 볼 `cheek_col` / 수염 색 `whisker_col` / 코 `nose_col` | 색 | 1 / 1 / 1 | — |

- 히든 파츠: 4세트 계열 12종 (A 라면 / B 인형뽑기 / C 상자 / D 피자), 그림 `shared/assets/cats/parts/hidden_a01`~`hidden_d03`. 옵션별 희귀도·가격표는 세부 기획서 미작성.
- 유니크(`"u"`) 옵션 6개: 랜턴, 수정 구슬, 경찰 배지, 별눈, 선글라스, 마법사 모자.

### 5.3 스테이지

스테이지 모드의 LEVEL은 수작업 데이터가 아니라 규칙으로 생성된다 (§3.4). LEVEL 상한은 없다 (속도표는 30단계에서 고정, 방해 블록은 LV10부터 6줄 고정). 스토리 120스테이지는 2026-08-31 제거됐다.

### 5.4 기타

| 콘텐츠 | 개수 | 위치 |
|---|---|---|
| 업적 | 18 | §4.8 |
| 테트로미노 | 7 | `board.gd` `SHAPES`/`COLORS` |
| 오프라인 랭킹 봇 | 24명 | `ranks.gd` `MOCK_NAMES` |
| 계정 칭호 | 5 | §4.2 |

---

## 6. 화면 흐름

```
wonderwheel_boot.tscn   회사 로고 스플래시 (addons/wonderwheel_splash, 건너뛰기 가능)
   ↓
boot.tscn               플랫폼 타이틀로 라우팅 (피처 태그 steam/mobile, 개발용 --steam/--mobile)
   ↓
타이틀                  스플래시(로고 + Press to play) → 아무 입력 → 메뉴
   ├─ 플레이 → 모드 선택(카드 2장, 데모 플레이 미리보기) → 인게임
   ├─ 캐릭터 변경하기 → 캐릭터 페이지 (일반 냥이 / 나만의 냥이 탭, 키캡 도감, 꾸미기)
   ├─ 상점 가기 → 상점 페이지 (랜덤 / 선택 / 캔 뽑기) → 결과 팝업 → 해금 안내
   ├─ 랭킹 보기 → 랭킹 팝업 (주간·누적 × 모드) → 리플레이 뷰어
   ├─ 설정 하기 → 설정 페이지 (기본 / 컨트롤러 / 키보드)
   └─ Lv 카드 ⚙ → 닉네임 변경, 재화 [+] → 상점
인게임 (main.tscn / main_mobile.tscn)
   ├─ 일시정지 → [이어하기] / [타이틀로]
   └─ 사망 → 결과창 → [다시 도전] / [타이틀로]
타이틀 복귀는 boot.tscn을 거친다 (회사 로고는 다시 나오지 않는다)
```

씬·스크립트: `core/scenes/{wonderwheel_boot,boot,title,main}.tscn`, `core/scripts/{boot,title,main}.gd`.

### 플랫폼별 차이

| | Steam PC | 모바일 | 웹 (PC / 모바일판) |
|---|---|---|---|
| 타이틀 씬 | `steam/ui/title_steam.tscn` | `mobile/ui/title_mobile.tscn` | PC `core/scenes/title.tscn` / 모바일판 `title_mobile.tscn` |
| 게임 씬 | `core/scenes/main.tscn` | `mobile/ui/main_mobile.tscn` | 타이틀과 같은 쪽 |
| 화면 | 가로 1920×1080 | 세로 1080×1920, 터치 덱 | 프리셋에 따라 |
| 추가 UI | 종료 버튼, Esc 종료 | `업적` 메뉴 카드, 모드 버튼의 숫자 접두 제거 | PC판은 터치 기기를 `m/`으로 리다이렉트 |
| 랭킹 백엔드 | Steamworks 리더보드 | Supabase (설정 시) | jsonblob HTTP |
| 업적 표시 | 스팀 오버레이 | 게임 안 업적 화면 | 없음 |
| 플랫폼 구현 | `steam/steam_platform.gd` | `mobile/mobile_platform.gd` | `platform/platform_base.gd` (no-op) |
| 인게임 유저 HUD | 항상 표시(Lv 카드) | 플레이 중 숨김, 결과창에서 표시 | 화면 방향에 따라 |

규칙: `core/`는 `steam/`·`mobile/`을 직접 참조하지 않는다. 자세한 분기 규칙은 [../CLAUDE.md](../CLAUDE.md)와 `.claude/skills/platform-split`.

---

## 7. 빌드·배포

`export_presets.cfg` 프리셋 4개.

| 프리셋 | 플랫폼 | 피처 태그 | 출력 | 제외 |
|---|---|---|---|---|
| Web | Web | (없음) | `build/web/index.html` | `steam/*`, `mobile/*`, `addons/godotsteam/*`, `tests/*` |
| WebMobile | Web | `mobile` | `build/web_m/index.html` | `steam/*`, `addons/godotsteam/*`, `tests/*` |
| Steam | Windows Desktop x86_64 | `steam` | `build/steam/cattris.exe` | `mobile/*`, `tests/*` |
| Mobile | Android arm64-v8a | `mobile` | `build/mobile/cattris.apk` (패키지 `com.cattris.game`) | `steam/*`, `addons/godotsteam/*`, `tests/*` |

- 웹 배포는 GitHub Pages(`gh-pages` 루트 = PC판, `m/` = 모바일판). 절차는 [../CLAUDE.md](../CLAUDE.md) "배포" 절.
- 스팀 업로드(SteamPipe) 스크립트는 아직 없다 ([steam_setup.md](steam_setup.md) ④).
- iOS 프리셋은 없다.

---

## 8. 미구현·보류·알려진 한계

### 출시 전 되돌려야 하는 개발용 설정

| 항목 | 현재 값 | 위치 |
|---|---|---|
| 피버 시작 게이지 | `FEVER_DEBUG_START` = 90.0 (출시 값 0.0) | `core/scripts/escape_board.gd` |
| DEV 패널 (업적·리더보드·골드/캔 치트) | `ENABLED` = true | `core/scripts/dev_panel.gd`, `title.gd` |
| 스테이지 "다음 LEVEL (테스트)" 버튼, N 키 | 모든 빌드에서 동작 | `main.gd` `_build_skip_level_button()`, `escape_board.gd` `_unhandled_key_input()` |
| 스팀 앱 id | 480 (Valve 테스트 앱) | `project.godot` `cattris/steam/app_id` |
| 웹 랭킹 | jsonblob 공유 blob (프로토타입용, 누구나 쓰기 가능) | `ranks.gd` `BOARD_URL` |

### 미구현 (코드에 TODO·스텁)

| 항목 | 상태 | 위치 |
|---|---|---|
| 모바일 인앱 결제 | `supports_iap()` false, TODO | `mobile/mobile_platform.gd` |
| 모바일 광고 | `supports_ads()` false, TODO | 같은 파일 |
| 모바일 플랫폼 업적 (Play Games / Game Center) | TODO, 게임 안 기록만 | 같은 파일 |
| 구글/애플 로그인 (기기 이전) | TODO, 지금은 익명 계정뿐 | 같은 파일, [cloud_setup.md](cloud_setup.md) ⑤ |
| Supabase 서버 연결 | 코드 완료, 설정값 비어 꺼짐 | `project.godot` `cattris/cloud/*` |
| 번역 11개 언어 | 선택 목록만 있고 번역 열 없음 | `shared/locale/*.csv` |
| 스팀 클라우드 업로드 호출 | 함수는 있으나 호출부 없음 | `platform/platform.gd` `sync_cloud_save()` |
| 홀드, 전용 하드드롭 키 | 입력 액션만 정의 | `project.godot` `[input]` |
| iOS 빌드 | 프리셋 없음 | `export_presets.cfg` |

### 알려진 한계

- 리플레이에 금 블록이 기록되지 않는다.
- 스팀 리더보드는 클라이언트가 자기 기록을 지울 수 없어 게임 초기화 후에도 보드에 남는다.
- 스팀 주간 보드는 주마다 새 보드가 생겨 누적된다 (정리 스크립트 없음, [steam_setup.md](steam_setup.md)).
- 지갑이 로컬 세이브에 있어 값 변조를 서버가 검증하지 않는다 (A안 신뢰 모델).
- 오프라인 봇 보드의 캐릭터는 초기 6종만 쓴다 (`ranks.gd` `MOCK_CATS`).
- 모바일 세로 화면의 피그마 디자인이 없다. 세로 DEV 패널·꾸미기 패널 배치는 미검증 (CLAUDE.md 기재).
- 기획 결정 대기 항목 15건 이상: [figma_questions.md](figma_questions.md).

---

## 9. 세부 기획서 목록

### 있는 문서

| 문서 | 내용 | 상태 |
|---|---|---|
| [economy.md](economy.md) | 재화 경제 설계 (2026-07-24) | **대부분 폐기**. 골드 정산식만 유효 |
| [new_cats_10.md](new_cats_10.md) | 신규 냥이 10종 컨셉·파츠 구성 | 게임 적용됨 |
| [character_art_spec.md](character_art_spec.md) | 코드 렌더 방식 20종 로스터 설계 | **현재 구현과 다름** (과거 설계) |
| [character_art_gallery.md](character_art_gallery.md) | 위 20종의 인엔진 렌더 갤러리 | **현재 구현과 다름** (과거 설계) |
| [steam_setup.md](steam_setup.md) | 스팀 파트너 사이트 작업 체크리스트, 업적 등록표 | 유효 (일부 수치 어긋남, §10) |
| [cloud_setup.md](cloud_setup.md) | Supabase 세팅 체크리스트, 서버가 맡는 범위 | 유효 |
| [figma_questions.md](figma_questions.md) | 피그마 UI 적용 중 기획 확인 필요 항목 | 유효 (미결) |
| [ui_audit.md](ui_audit.md) | UI/UX 점검 결과(2026-10-09): 수정한 버그, 버그 후보, 일관성, UX·연출 제안 | 유효 (제안은 선택 대기) |
| [my_tasks.md](my_tasks.md) | 사용자가 외부 사이트에서 할 일 | 유효 |
| [../CLAUDE.md](../CLAUDE.md) | 개발 지침 겸 구현 설명 (모드·플랫폼 분리·UI 상세) | 유효 (일부 낡은 서술, §10) |

### 세부 기획서가 없는 시스템·콘텐츠 (미작성)

| 대상 | 제안 경로 | 상태 |
|---|---|---|
| 블록·조작 규칙 | `systems/board.md` | 미작성 |
| 스테이지 모드 (LEVEL·셔터·방해 블록) | `systems/mode_stage.md` | 미작성 |
| 무한의 계단 (용암·피버) | `systems/mode_endless.md` | 미작성 |
| 재화·경제 (현행: 골드 + 캔) | `systems/economy.md` | 미작성 (기존 economy.md는 폐기 설계) |
| 키캡 수집·상점 뽑기 | `systems/gacha.md` | 미작성 |
| 계정 레벨 | `systems/account_level.md` | 미작성 |
| 랭킹·주간 보상·리플레이 | `systems/ranking.md` | 미작성 |
| 업적 | `systems/achievements.md` | 미작성 (등록표만 steam_setup.md에 있음) |
| 저장·클라우드 | `systems/save.md` | 미작성 |
| 꾸미기(나만의 캐릭터) | `systems/customizer.md` | 미작성 |
| 설정·조작 바인딩 | `systems/settings.md` | 미작성 |
| 다국어 | `systems/localization.md` | 미작성 |
| 사운드 | `systems/audio.md` | 미작성 |
| UI·화면 흐름 | `systems/ui_flow.md` | 미작성 |
| 캐릭터 16종 (현행 로스터·능력치) | `content/characters.md` | 미작성 (10종만 new_cats_10.md) |
| 파츠 카탈로그·히든 파츠 가격 | `content/parts.md` | 미작성 |

---

## 10. 문서와 구현의 차이

코드가 기준이다. 아래는 2026-10-06 `e59c1c8` 기준으로 확인한 것.

### CLAUDE.md

| # | 문서 | 코드 |
|---|---|---|
| 1 | 시작 씬은 `core/scenes/boot.tscn` | `project.godot` `run/main_scene` = `core/scenes/wonderwheel_boot.tscn` (회사 로고 스플래시 → boot) |
| 2 | "익스포트 프리셋" 절에 Web / Steam / Mobile 3개 | `export_presets.cfg`에 `WebMobile` 포함 4개 (배포 절에는 언급됨) |
| 3 | "캐릭터 6종", "전원 만렙 약 625장 ≈ 1.6만 골드" (`game_state.gd` 주석도 같음) | 디자인 냥이 16종. 골드 냥이 전원 만렙은 계산상 1,430장 |
| 4 | `KEYCAP_FRESH_CHANCE`만큼 빈 글자 우선, 나머지는 중복 | 그 상수가 없다. 중복은 나오지 않는다 (`_roll_letter()`) |
| 5 | 캐릭터 격자 "한 줄 5칸" (한 곳), `CHAR_LEFT_RATIO_V` 0.58 | `CHAR_GRID_COLS` = 4, `CHAR_LEFT_RATIO_V` = 0.55 (`title.gd`) |
| 6 | "렌더링은 텍스처 없이 `_draw()`로 직접 그림" | 캐릭터 스프라이트·UI 그림은 PNG/SVG 텍스처를 쓴다 (`shared/assets/cats`, `shared/assets/ui`) |
| 7 | 스팀 출시 목표 13개국어 | 번역 열은 en·ko(+의사 로케일)뿐 |
| 8 | 피버 설명의 "별길"·"별" 표현이 일부 남음 | 코인 비로 대체됨. 코드 주석에도 "6초"·"골드러시" 같은 옛 표현이 남아 있다 (실제 3.4초) |
| 9 | 타이틀 메뉴 서술이 두 가지 (옛 "PLAY + 카드 4장 + 키캡 알약", 새 피그마 CTA 열) | 피그마 적용본이 현행 |

### docs

| # | 문서 | 코드 |
|---|---|---|
| 10 | steam_setup.md ③ "아래 15개" | 표와 코드 모두 18개 |
| 11 | steam_setup.md `CAT_UNLOCK_ALL` "디자인 냥이 6종 전부", 표시 이름 "여섯 마리 대가족" (`achievements.gd` `DEFS`의 `cond` 문구도 6종) | 판정은 키캡을 모으는 냥이 전부 = 16종 (유니크 2종 포함) |
| 12 | steam_setup.md ⑤ "게임은 이미 13개국어 대응이 끝나 있다" | #7과 같음 |
| 13 | economy.md 머리말 "재화는 골드 하나뿐" | 통조림 캔이 두 번째 재화로 있다 |
| 14 | economy.md 골드 광석 4G / 덩어리 8G, 피버 0.5초마다 3G | 금 블록 20G(셔터 10G), 피버 코인 8G × 초당 16개 |
| 15 | economy.md 부활 젤리·액세서리·출발 부스트·스킵권·스토리 보상 "전 항목 구현 완료" | 전부 제거됨. 유효한 것은 무한 높이×3, 스테이지 점수÷40, 하루 첫 판 2배 |
| 16 | character_art_spec.md / character_art_gallery.md: 코드 렌더 20종(삼색·민트·벚꽃·유령·황금 등) | 현행은 스프라이트 기반 16종이고 그 20종 로스터는 게임에 없다 |
| 17 | new_cats_10.md 머리말 "게임에 바로 들어가는 에셋이 아니다" | 같은 문서 아래쪽과 코드 기준으로 이미 게임에 들어가 있다 |
| 18 | `game_state.gd` 주석 "신규 10종은 파츠 레이어가 없다" | CLAUDE.md·`gen_layouts.gd` 기준 레이어 분리됨 (주석이 낡음) |
| 19 | my_tasks.md "figma_questions.md의 질문 13개" | 질문 15개 + 2차 대조 질문 6개 |
| 20 | figma_questions.md "하드드롭 키가 없다" | 전용 키는 없으나 낙하 키 두 번 누르기로 하드드롭이 된다 |

---

## 부록: 확인하지 못한 항목

- 타깃 유저층, 가격·수익 모델, 출시 일정: 코드·문서에 없음.
- 라이브 배포 URL과 배포된 빌드의 버전: CLAUDE.md 기재만 확인, 접속 확인 안 함.
- 테스트 통과 여부: Godot을 실행하지 않았다 (`tests/` 27개 씬).
- 꾸미기 옵션별 희귀도·가격, 옵션 수의 "없음" 포함 여부.
- 터치 버튼의 정확한 좌표·크기, 가로/세로 UI 치수: CLAUDE.md 서술만 참고.
- BGM 구성(길이·템포), 스팀 리플레이 UGC 처리 세부, 서버 SQL 함수 본문 세부.
- 회사 로고 스플래시의 연출 스타일: 씬에서 지정한 값이 없어 스크립트 기본값으로 추정되나 실행 확인 안 함.
