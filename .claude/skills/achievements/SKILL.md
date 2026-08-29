---
name: achievements
description: 업적(Steam Achievements) 작업 규칙 — Achv autoload 구조, 업적 추가·판정 절차, 세이브 필드 규칙, 파트너 사이트 등록, 개발 완료 시점 최종 검토와 스팀 적용 체크리스트. 업적을 추가·수정·검토하거나 스팀 앱 id를 받아 실제 업적을 붙일 때 참조.
---

# 업적 작업 규칙

Cat-Tris의 업적은 **스팀 업적이 전부다.** 게임 안에 업적 목록 UI는 **없고, 만들지 않는다.**

## 🔑 제일 먼저 알아야 할 것

| | |
|---|---|
| 정의·판정 | `core/autoload/achievements.gd` (autoload **`Achv`**) |
| 해금 기록 | `GameState.achv` (save.json의 `achv` 배열) |
| 스팀 전달 | `Platform.unlock_achievement(id)` → `setAchievement` + `storeStats` |
| 등록 목록 | `docs/steam_setup.md` ③ — 파트너 사이트에 넣을 API Name 표 |
| 회귀 테스트 | `res://tests/test_achievements.tscn` |
| 관련 스킬 | 스팀 연결 전반은 `/steam-backend`, 참조 방향 철칙은 `/platform-split` |

**철칙**: `Achv`는 `Platform.unlock_achievement()`만 부른다. `steam/`을 직접 참조하지 않으므로
웹·모바일 빌드에서도 그대로 돌고, 스팀이 아니면 조용히 no-op이다.

## UI를 만들지 않는 이유

스팀이 표시를 전부 대신한다 — 해금 토스트, Shift+Tab → 업적 목록, 진행률, 전세계 달성률.
**이름·설명·아이콘·13개국어 번역이 파트너 사이트에 있으므로 게임 쪽 `/i18n` 작업이 0이다.**
게임 안에 목록을 만들면 업적 15개 × (이름+설명) = 30개 문자열을 13개 국어로 번역해야 한다.

- 그래서 `Achv.DEFS`에는 **id와 조건 메모만** 둔다. 표시 문자열을 코드에 넣지 말 것.
- 모바일을 재개하면 그때 `DEFS` 위에 자체 목록 화면을 얹는다 (Play Games/Game Center).
  그 시점에야 표시 문자열이 필요해지고, 그때 `/i18n`을 따른다.

## 판정은 두 갈래 — 상태형을 기본으로

### 상태형 (기본)
세이브 값만 보면 알 수 있는 것. `Achv.check()` 안에 `unlock_if(조건, ID)` 한 줄로 넣는다.

```gdscript
unlock_if(GameState.best_height >= 50, HEIGHT_50)
```

**소급 적용된다** — 나중에 업적을 추가해도 이미 조건을 만족한 세이브는 다음 `check()`에서
해금된다. 그래서 **가능하면 무조건 상태형으로 만든다.** `check()` 호출 지점:

| 지점 | 파일 |
|---|---|
| 타이틀 진입 | `title.gd._ready()` |
| 판 종료 | `main.gd._on_game_over()` |
| 가챠 | `game_state.gd.draw_keycaps()` |
| 스테이지 LEVEL 갱신 | `main.gd._on_classic_level_started()` |

### 사건형 (최후 수단)
그 순간에만 알 수 있어서 세이브에 흔적이 남지 않는 것. 해당 지점에서 `Achv.unlock(ID)`를
직접 부르고, `DEFS`에 `"ev": true`를 붙인다. 지금은 3개뿐이다 —
`FIRST_ESCAPE`(무한 판 종료), `REPLAY_WATCH`(랭킹 리플레이 재생), `CUSTOM_CAT`(꾸미기 저장).

> **사건형을 늘리기 전에 한 번 더 생각할 것.** 그 조건을 세이브 카운터 한 줄로 바꿀 수
> 있으면 상태형이 낫다 — 소급 적용되고, 판정 지점이 흩어지지 않고, 테스트가 쉽다.

## 업적 하나 추가하는 절차

1. `achievements.gd`에 `const NEW_ID := "NEW_ID"` 추가 (API Name = 상수 이름과 동일하게)
2. `DEFS`에 `{"id": NEW_ID, "cond": "한 줄 조건 설명"}` 추가 (사건형이면 `"ev": true`)
3. 판정을 붙인다 — 상태형이면 `check()`에 `unlock_if()` 한 줄, 사건형이면 그 지점에서 `unlock()`
4. 새 카운터가 필요하면 **`game_state.gd` 네 곳을 모두** 고친다 (아래 참조)
5. `docs/steam_setup.md` ③ 표에 한 줄 추가 — 표시 이름(안)과 조건까지
6. `res://tests/test_achievements.tscn` 통과 확인
7. 사용자에게 **"파트너 사이트에 이 API Name을 추가해야 한다"**고 알린다 —
   등록되지 않은 id는 해금해도 **조용히 무시된다**(에러도 안 난다)

### 카운터 필드를 추가할 때 (네 곳)
`var 선언` → `reset_all()` → `save_game()` 딕셔너리 → `load_game()`.
하나라도 빠지면 재시작 때 값이 날아간다. 지금 있는 업적 전용 카운터:
`gold_earned`(누적 획득 골드) / `gacha_drawn`(누적 뽑기 장수) / `classic_level_best`(도달 최고 LEVEL).

**스팀 Stat은 쓰지 않는다** — 세이브가 Auto-Cloud로 동기화되므로 PC를 옮겨도 이어진다.
Stat을 도입하면 파트너 사이트에 별도 등록·관리가 붙는데 얻는 게 없다.

## 규칙 몇 가지

- **분할 화면(`GameState.split`)은 판정에서 제외한다** — 2P는 지갑도 기록도 없다.
- **`reset_all()`("게임 초기화")은 `achv`를 지우지 않는다.** 스팀 업적은 클라이언트가
  되돌릴 수 없으므로 지워 봐야 다음 `check()`에서 다시 붙을 뿐이다. 카운터는 0으로 돌아간다.
- `unlock()`은 이미 딴 업적을 걸러 낸다. 매 프레임 불러도 되지만, 그러라는 뜻은 아니다.
- 나만의 캐릭터(`mycat`)는 키캡을 모으지 않는다 — 캐릭터를 세는 판정은 반드시
  `GameState.keycap_cats()`(디자인 냥이만)를 쓴다.

## ⚠️ 테스트가 실기 세이브를 덮어쓴다

헤드리스 테스트도 실기와 **같은 `user://`**를 쓴다. `Achv.unlock()`은 `GameState.save_game()`을
부르므로, GameState 값을 갈아 끼우는 테스트는 **첫 줄에서 저장을 꺼야 한다**:

```gdscript
GameState.save_enabled = false
```

(2026-08-29에 이걸 안 해서 실기 세이브를 날린 적이 있다. 기록은 `user://replay_*.dat`에서
역산해 복구했지만 — 리플레이는 신기록일 때만 저장되므로 원래 값을 알 수 있다 —
키캡 수집 현황은 복구하지 못했다.)

## 개발 완료 시점 최종 검토 체크리스트

출시 전에 한 번 정주행하며 볼 것:

- [ ] **난이도 곡선** — 첫 30분 안에 3~5개는 열려야 한다. 지금 `FIRST_ESCAPE`·`KEYCAP_FIRST`가
      그 역할이고, 반대편 끝(`CAT_MAX_GRADE` = 전원 만렙 ≈ 625장 ≈ 1.6만 골드)이 너무 멀지 않은지
- [ ] **도달 불가 업적이 없는지** — 메뉴에서 내린 모드(스토리·대전·젤리 피크닉)에 걸린 조건이
      섞여 있으면 영영 못 딴다. 지금 목록은 스테이지 모드·무한의 계단·키캡·꾸미기만 쓴다
- [ ] **밸런스 변경과의 정합** — 점수·골드·키캡 수치를 손봤으면 `CLASSIC_100K`·`GOLD_10K`·
      `GACHA_100` 문턱을 다시 계산할 것
- [ ] **소급 적용 확인** — 오래된 세이브로 타이틀에 들어가 `check()`가 제대로 여는지
- [ ] **개수** — 15개는 스팀 기준 적은 편이다. 늘릴 거면 **출시 전에** 늘린다
      (출시 후 추가는 가능하지만 이미 산 사람의 달성률 통계가 어그러진다)
- [ ] 아이콘 30장(해금·잠금 × 15) 준비 — 각 256×256 png
- [ ] `docs/steam_setup.md` ③ 표와 `Achv.DEFS`의 id가 **완전히 일치**하는지

## 스팀 앱 id를 받은 뒤 (실제 적용)

1. `project.godot`의 `cattris/steam/app_id` 교체 (`/steam-backend` 참조) — 업적 쪽 코드는 안 고친다
2. 사용자가 파트너 사이트 → **Stats & Achievements** → Achievements 에 표의 API Name을 등록
   → **Publish** 해야 실제로 반영된다 (등록만 하고 게시를 안 하면 안 열린다)
3. 실기 검증: 스팀 클라이언트를 켜고
   ```powershell
   & "<godot>" --path E:\Game\Block -- --steam
   ```
   조건을 만족시켜 **오버레이 토스트가 뜨는지** 확인. 토스트 조건: 오버레이가 켜져 있고
   (`Steam 설정 → 게임 중`), `storeStats()`까지 불렸을 것 — `unlock_achievement()`가 둘 다 한다.
4. **다시 테스트하려면 해금을 되돌려야 한다.** 두 군데를 다 지워야 한다:
   - 스팀 쪽: `clearAchievement(id)` / `resetAllStats(true)` — 임시 스크립트로 호출
   - 로컬 쪽: `save.json`의 `achv` 배열 (안 지우면 `unlock()`이 걸러 낸다)
5. 앱 480(테스트 앱)으로는 **업적 검증이 안 된다** — 남의 앱이라 우리 id가 등록돼 있지 않다.
   리더보드와 달리 업적은 진짜 앱 id가 있어야 확인할 수 있다.
