---
name: steam-backend
description: 스팀(Steamworks) 백엔드 작업 규칙 — GodotSteam 설치·초기화, 리더보드(전체/주간), 리플레이 UGC 첨부, 업적, 클라우드 세이브, 앱 id 교체와 출시 체크리스트. 랭킹·기록·업적·클라우드 저장을 건드리거나 스팀 빌드를 만들 때 참조.
---

# 스팀 백엔드 작업 규칙

Cat-Tris는 **자체 서버가 없다.** 온라인 기능은 전부 Steamworks가 대신한다 —
리더보드, 리플레이 저장, 업적, 클라우드 세이브. 서버비 0원, 운영 대상 0개.

## 🔑 제일 먼저 알아야 할 것

| | |
|---|---|
| 확장 | GodotSteam GDExtension **4.22** (Steamworks SDK 1.65, Godot 4.4+) |
| 설치 위치 | `addons/godotsteam/` — **win64 바이너리만** 남겨 뒀다 (8.3MB) |
| 앱 id | `project.godot`의 `cattris/steam/app_id` — 지금 **480**(Valve 테스트 앱 "Spacewar") |
| 구현체 | `steam/steam_platform.gd` (`PlatformBase` 상속) |
| 계약 | `platform/platform_base.gd` — 게임 쪽은 이 메서드들만 안다 |
| 라우팅 | `core/autoload/ranks.gd`의 `backend()` → STEAM / HTTP / OFFLINE |
| 점검 | `res://tests/steam_check.tscn` |

**철칙은 그대로다**: `core/`에서 `steam/`을 `preload`·씬 하드 참조하지 말 것.
`Platform.*` 위임 메서드로만 부른다. (`/platform-split` 스킬 참조)

## 백엔드 3단 폴백

`Ranks.backend()`가 매번 판단하고, UI는 이 결정을 몰라도 된다.

```
STEAM   스팀 빌드(또는 --steam) + 스팀 클라이언트 살아 있음 + 초기화 성공
   ↓ 실패하면
HTTP    BOARD_URL이 채워져 있음 (jsonblob — 웹 빌드용 프로토타입 백엔드)
   ↓ 비어 있으면
OFFLINE 봇 크루(MOCK_NAMES) + 내 로컬 기록만
```

스팀 클라이언트를 꺼 놓고 게임을 켜도 죽지 않는다 — 조용히 HTTP로 내려간다.
**jsonblob은 릴리스에 쓰면 안 된다** (주소만 알면 누구나 덮어쓰기 가능, 만료가
마지막 접근 +1일). 스팀 빌드는 STEAM 경로만 타므로 문제되지 않는다.

## 리더보드

### 보드 이름 규칙 — `Ranks.board_name()`

```
전체 기록   "endless", "classic"
이번 주     "endless_w2955"   (w + 주 번호, 월요일 00:00 KST에 넘어감)
```

스팀에는 **자동 리셋이 없다.** 그래서 주간 보드는 "새 주 = 새 이름의 보드"로
처리하고, `findOrCreateLeaderboard`가 그 자리에서 만든다(클라이언트 생성 허용).
지난주 보드는 지워지지 않고 남아 있어서 **주간 시상**(`_claim_rewards_steam()`)이
지난주 보드 상위 3명을 그대로 읽는다.

> ⚠️ **보드가 계속 쌓인다.** 살아 있는 모드 2개 × 주 1개 = 연 104개.
> 몇 년 굴릴 거라면 Steamworks Web API `ISteamLeaderboards/ResetLeaderboard`
> (퍼블리셔 키 필요)로 오래된 보드를 정리하는 스크립트를 주 1회 돌린다.
> 서버가 아니라 내 PC의 cron/작업 스케줄러면 충분하다.

### 죽은 모드에 보드를 만들지 말 것

`Ranks.LIVE_MODES = ["endless", "classic"]`. 내려둔 story/picnic은 여기 없어서
스팀에 보드가 생기지 않는다. **모드를 다시 살리면 이 배열에 추가할 것** —
안 그러면 그 모드 기록이 조용히 어디에도 안 올라간다.

### 엔트리에 뭘 실을 수 있나

스팀 엔트리는 `점수(int32) + details(int32 × 최대 64) + UGC 첨부 하나`가 전부다.
**문자열을 못 싣는다.** 그래서:

- 캐릭터 → `details[0]`에 `Ranks.cat_index()`(CATS 배열의 자리 번호). 받는 쪽은
  `Ranks.cat_from_index()`. **CATS 순서를 바꾸면 기존 보드 엔트리의 캐릭터가
  전부 어긋난다** — 새 캐릭터는 배열 끝에 추가할 것.
- 이름 → 스팀 페르소나 이름을 쓴다. 게임 내 닉네임은 스팀 보드에 안 나간다
  (그래서 `rename_and_resubmit()`이 스팀에서는 그냥 넘어간다).
- `details_max`는 `setup()`에서 `set_leaderboard_details_max(4)`로 고정.
  늘리면 **읽는 쪽도 같은 값이어야 한다** — 안 맞으면 details가 깨져서 온다.

### 점수는 항상 keep_best

`uploadLeaderboardScore(score, true, ...)` — 낮은 점수를 올려도 스팀이 무시한다.
그래서 시작할 때 로컬 최고 기록을 그냥 다 밀어 넣어도(`submit_all()`) 안전하다.

### 내 기록은 지울 수 없다

스팀 리더보드는 **클라이언트가 자기 엔트리를 삭제하는 API가 없다.**
`설정 > 게임 초기화`는 스팀에서 로컬만 지우고 보드는 건드리지 않는다
(`Ranks.wipe_mine()`이 STEAM이면 즉시 반환, `can_wipe_scores()` = false).
지우려면 Web API `DeleteLeaderboard`/`ResetLeaderboard`로 보드째 밀어야 한다.

## 리플레이 = UGC 첨부

details로는 리플레이가 안 들어간다(256바이트). 스팀의 정답은 **Remote Storage에
파일로 올리고 그 핸들을 엔트리에 붙이는 것**:

```
Replays.pack(mode)  →  fileWrite()  →  fileShare()  →  attachLeaderboardUGC()
                                                            ↓ 남이 볼 때
                       Replays.unpack()  ←  파일 읽기  ←  ugcDownloadToLocation()
```

- 첨부는 **전체 기록 보드에만** 붙인다. 주간 보드는 매주 버려지니 붙일 이유가 없다.
- 첨부 3단계 중 하나라도 실패하면 **점수만 남고 리플레이는 없다** — 치명적이지
  않으니 조용히 넘어간다.
- ⚠️ 첨부가 없는 엔트리의 `ugc_handle`은 **0이 아니라 -1**로 온다
  (`k_UGCHandleInvalid`를 부호 있는 정수로 읽은 값). `_to_entries()`가 0으로
  눕혀 주고, 판정은 전부 `> 0`으로 한다. **`!= 0`으로 쓰면 전부 "리플레이 있음"이
  된다.**

## 비동기 규칙 — 여기서 제일 많이 깨진다

GodotSteam의 콜백은 **Steam 싱글톤의 전역 시그널**로 온다. `leaderboard_find_result`
하나만 봐서는 어느 요청의 응답인지 알 수 없다. 그래서:

1. **리더보드 작업 전체를 `_busy` 하나로 직렬화한다** (`_lock()` / `_unlock()`).
   동시에 두 개를 던지면 응답이 뒤바뀐다. 새 작업을 추가할 때도 반드시 락 안에서.
2. **`await`은 하나만 기다린다** — 시그널과 타임아웃을 동시에 걸 수 없다.
   `_poll()`이 한 프레임씩 확인하며 `TIMEOUT`(10초)까지 기다리고, 넘으면
   연결을 끊고 `null`을 돌려준다(늦게 온 응답이 다음 요청을 오염시키지 않게).
3. 콜백 펌프는 `steamInitEx(app_id, true)`의 **embed_callbacks = true**가
   `SceneTree.process_frame`에 물어 준다. 따로 `run_callbacks()`를 돌리지 말 것.
4. `PlatformBase`는 `RefCounted`라 `get_tree()`가 없다 —
   `Engine.get_main_loop().process_frame` / `.create_timer()`를 쓴다.

플레이어 이름은 친구가 아니면 캐시에 없어서 `requestUserInformation()` 후
0.4초 기다렸다 읽는다. 그래도 비면 SteamID 꼬리로 대체 이름을 만든다.

## 업적 / 클라우드 세이브

- 업적: `Platform.unlock_achievement(id)` → `setAchievement` + `storeStats`.
  **id는 파트너 사이트에 등록한 API Name과 정확히 같아야 한다.** 아직 파트너
  사이트에 등록된 업적이 없어서 호출해도 아무 일도 안 일어난다.
  **업적을 추가·수정·검토할 때는 `/achievements` 스킬을 따를 것** — 정의·판정은
  `core/autoload/achievements.gd`(autoload `Achv`)가 소유하고, 여기(스팀 쪽)는
  받은 id를 그대로 넘기는 통로일 뿐이다.
- 클라우드 세이브: **파트너 사이트의 Auto-Cloud 설정이 정답이다** — `user://`
  폴더를 지정하면 코드 한 줄 없이 양방향 동기화된다.
  `sync_cloud_save()`는 save.json을 Remote Storage에 올리기만 하는 보조 수단이고
  **내려받지 않는다.** Auto-Cloud를 켜면 이 호출은 필요 없다.

## 개발 중 돌려 보기

```powershell
# 스팀 백엔드 점검 (초기화 → 보드 생성 → 제출 → 조회)
& "<godot>" --headless --path E:\Game\Block res://tests/steam_check.tscn -- --steam

# 게임을 스팀 구현체로 실행
& "<godot>" --path E:\Game\Block -- --steam
```

- `--steam` 인자는 `Platform` autoload가 직접 본다(`boot.gd`와 같은 규칙,
  `--` 구분자 유무 무관). autoload는 boot보다 먼저 돌기 때문에 필요한 장치다.
- **스팀 클라이언트가 켜져 있어야 한다.** 꺼져 있으면 초기화가 실패하고
  HTTP 백엔드로 내려간다(그것도 정상 동작이니 로그를 보고 판단할 것).
- 앱 480은 공용 테스트 앱이라 보드에 남이 만든 말도 안 되는 점수가 섞여 있다.
  정상이다.

## 앱 id를 받으면 (출시 준비)

> 파트너 사이트에서 **사용자가** 해야 하는 일은 `docs/steam_setup.md`에 체크리스트로
> 정리돼 있다. 사용자가 "스팀 계정 세팅했다"고 하면 그 문서부터 열고, 받은 값
> (앱 id / 업적 API Name / depot id)에 맞춰 아래를 진행한다.


1. `project.godot`의 `cattris/steam/app_id`를 실제 id로 바꾼다. **코드는 안 고친다.**
2. 파트너 사이트에서 리더보드를 미리 만들어 둘 필요는 없다 —
   `findOrCreateLeaderboard`가 첫 실행 때 만든다. 다만 **표시 이름·정렬을 손보려면**
   파트너 사이트에서 만드는 쪽이 낫다 (정렬 내림차순 / 표시 Numeric).
3. Steam Cloud: 파트너 사이트 → Cloud → Auto-Cloud에 `user://` 경로 등록.
4. 업적: 파트너 사이트에 등록·게시한 API Name이 `Achv.DEFS`의 id와 같아야 한다.
   검증 절차와 되돌리는 법은 `/achievements` 스킬에 있다.
5. 익스포트: `Steam` 프리셋(`build/steam/cattris.exe`). `.gdextension`의
   `[dependencies]`가 `steam_api64.dll`을 exe 옆에 같이 복사해 준다.
6. `addons/godotsteam/*`는 **Web/WebMobile/Mobile 프리셋에서 제외**돼 있다.
   새 프리셋을 만들면 같은 제외를 넣을 것 (웹 빌드에 8MB DLL이 딸려간다).

## 다른 플랫폼 바이너리가 필요해지면

용량 때문에 **win64만 남기고 지웠다**(linux/mac/android/win32 + `.gdextension`의
해당 줄). 리눅스·맥 빌드를 하게 되면:

1. [GodotSteam 릴리스](https://codeberg.org/godotsteam/godotsteam/releases)에서
   `godotsteam-<버전>-gdextension-plugin-4.4.zip`를 받아 `addons/`에 덮어쓴다.
2. `addons/godotsteam/godotsteam.gdextension`의 `[libraries]`·`[dependencies]`에
   그 플랫폼 줄을 되살린다 (zip 원본에 전부 들어 있다).

## 자체 백엔드가 필요해지는 시점

지금은 필요 없다. 아래 중 하나가 걸리면 그때 고민한다:

- **치트 방지** — 스팀 리더보드도 클라이언트가 점수를 쓴다. 툴로 아무 값이나
  올릴 수 있다. 리플레이가 붙어 있으니 **상위권 수동 검증**이 현실적인 1차 방어.
  서버 리플레이 검증까지 가려면 그때 백엔드.
- **주간 시상의 신뢰성** — 지금은 클라이언트가 지난주 순위를 읽고 스스로 지급한다.
  게임 내 재화라 큰 문제는 아니지만 조작 가능하다.
- **크로스 플랫폼 보드** — 스팀 리더보드는 스팀 클라이언트 안에서만 동작한다.
  웹/모바일과 보드를 합치려면 공용 백엔드가 필요하다.

## 건드릴 때 자주 하는 실수

| 하지 말 것 | 이유 |
|---|---|
| `core/`에서 `steam/`을 preload | 웹/모바일 빌드에서 제외돼 파싱이 깨진다 |
| `steam_platform.gd`에 `class_name` | 같은 이유 — 전역 클래스로 등록되면 안 된다 |
| 락 없이 스팀 리더보드 호출 추가 | 전역 시그널이라 응답이 뒤바뀐다 |
| `ugc_handle != 0`으로 첨부 판정 | 없을 때 -1이 온다 |
| CATS 배열 중간에 캐릭터 삽입 | 기존 보드 엔트리의 캐릭터가 전부 밀린다 |
| `Ranks.refresh()`를 스팀에서 기대 | 스팀은 보드를 하나씩 받는다 — `Ranks.view(mode, weekly)`를 쓸 것 |
| 새 모드를 `LIVE_MODES`에 안 넣음 | 그 모드 기록이 아무 데도 안 올라간다 |
