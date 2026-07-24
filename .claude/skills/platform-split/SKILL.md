---
name: platform-split
description: 스팀/모바일 버전 분기 규칙. 컨텐츠·시스템·UI를 수정/추가할 때 두 플랫폼 처리를 함께 하기 위한 체크리스트. 게임 기능 추가, UI 변경, 새 모드/컨텐츠 작업 시 반드시 참조.
---

# 스팀/모바일 플랫폼 분기 작업 규칙

Cat-Tris는 저장소·Godot 프로젝트 하나에서 스팀(가로)과 모바일(세로) 두 버전을 빌드한다.
**모든 게임플레이 수정은 두 플랫폼에서 동작을 확인해야 완료다.**

## 버전 정의

| | 스팀 (기준 구현) | 모바일 |
|---|---|---|
| 해상도 | 가로 1920×1080 | **세로 1080×1920** (`.mobile` 오버라이드) |
| 모드 | 탈출, 무한, 2P 대전, 2인 분할 | 탈출, 무한만 — **2P 계열 없음** |
| 입력 | 키보드/패드 (+Esc 종료) | 터치 컨트롤 항상 표시 |
| 타이틀 | `steam/ui/title_steam.tscn` | `mobile/ui/title_mobile.tscn` |
| 게임 씬 | `core/scenes/main.tscn` | `mobile/ui/main_mobile.tscn` (main.tscn 상속) |
| 프리셋 | `Steam` (Windows, 태그 `steam`) | `Mobile` (Android, 태그 `mobile`) |

웹(GitHub Pages)은 제3의 타깃: 가로 + no-op Platform. 스팀과 같은 레이아웃을 쓴다.

## 철칙: 참조 방향

```
steam/ ──▶ core/ ◀── mobile/          (허용: 상속·preload 자유)
core/ ──✗▶ steam/, mobile/            (금지: preload·씬 하드 배치·class_name 참조)
```

- 익스포트 필터가 반대 플랫폼 폴더를 빌드에서 제외하므로, core가 플랫폼 폴더를 정적 참조하면 **그 빌드는 파싱 단계에서 깨진다**.
- core에서 플랫폼별 리소스가 필요하면: `OS.has_feature("steam"/"mobile")` 가드 + `load()` 문자열 경로.
- `steam/`·`mobile/` 안의 스크립트에 `class_name` 금지 (전역 클래스로 등록되면 반대 빌드에서 참조가 깨짐).

## 수정 유형별 처리

### 1. 게임 로직/시스템 수정 (보드, 플레이어, 스탯, 경제 등)
- `core/`에서 수정. 두 플랫폼이 자동 공유하므로 분기 불필요.
- 단, **화면 좌표를 하드코딩하지 말 것** — 뷰포트 크기(`get_viewport_rect().size`) 기준으로 계산. 1920/1080 리터럴이 새로 들어가면 모바일(1080×1920)에서 깨진다.
- 2P(대전·분할) 전용 로직은 모바일에서 실행될 일이 없지만, 코드가 모바일 빌드에 포함되는 건 정상 (main.gd 공유).

### 2. HUD/인게임 UI 변경
- `core/scenes/main.tscn`에 노드 추가/변경 후, **`mobile/ui/main_mobile.tscn`에서 세로 배치 오버라이드를 함께 갱신**할 것. 상속 씬이므로 새 노드는 자동 등장하지만 위치는 가로 기준이라 세로에서 어긋난다.
- 세로 레이아웃 존: 보드 (220,200)~(860,1096) / 좌측 열 x 40~192 / 우측 열 x 880~1070 (탈출 HUD는 y 340부터 — 출구 벽과 겹침 방지) / 상단 중앙 y 0~150 / 터치 존 y 1450~1860.
- 스크립트가 `visible`을 제어하는 노드는 씬 오버라이드로 숨겨도 소용없다 (main.gd가 덮어씀) — 스크립트 분기 필요.

### 3. 타이틀/메뉴 UI 변경
- 공용 요소(캐릭터 선택, 상점, 재화)는 `core/scripts/title.gd` — 이미 해상도 인지형. `vw`/`vh`/`tile_y` 변수를 쓰고 1920/1080 리터럴 금지.
- 플랫폼 요소는 각 타이틀 스크립트에: `steam/ui/title_steam.gd`(종료 버튼, Esc), `mobile/ui/title_mobile.gd`(세로 재배치, 2P 숨김, `max_tiles_per_row`, `main_scene` 교체).
- core 타이틀에 노드를 추가하면 **두 플랫폼 타이틀 스크린샷을 모두 확인**할 것.

### 4. 새 모드/컨텐츠 추가
- 먼저 결정: 두 플랫폼 공통인가?
  - 공통 → `core/`에 추가 + 두 타이틀에 진입점. **모바일은 세로 화면·터치 조작으로 플레이 가능한지 먼저 검토** (키보드 2인 전제면 모바일 제외).
  - 스팀 전용(예: 도전과제 연계) → `steam/content/`, 모바일 전용(예: 광고 보상) → `mobile/content/`. 진입점도 해당 플랫폼 타이틀에만.
- 모드 선택 흐름: 타이틀 `_start()` → `GameState.mode` → `main_scene` 로드. 모바일 제외 모드는 `title_mobile.gd`의 숨김 목록에 추가.

### 5. 새 입력/조작 추가
- 액션을 `project.godot` [input]에 등록하고, **모바일용 터치 버튼을 함께 추가**: `main.tscn`의 `TouchControls`에 TouchButton 노드(가로 위치) + `main_mobile.tscn`에 세로 위치 오버라이드.
- 터치 버튼 최소 크기 ~220×140. 키보드 힌트 문구(`HelpLabel` 등)는 모바일에서 숨김 상태 유지.

### 6. 플랫폼 서비스 (업적·리더보드·클라우드·IAP·광고)
- `platform/platform_base.gd`에 no-op 메서드 추가 → `steam/steam_platform.gd`·`mobile/mobile_platform.gd`에서 오버라이드 → 게임 코드는 `Platform.xxx()`만 호출.
- 게임 코드에 GodotSteam/광고 SDK 등을 직접 import하지 말 것.

## 검증 체크리스트 (수정 완료 전 필수)

```powershell
# 1) 로직 테스트
& "<godot>" --headless --path E:\Game\Block res://tests/test_board.tscn
& "<godot>" --headless --path E:\Game\Block res://tests/test_escape.tscn
# 2) 양쪽 레이아웃 스크린샷 (가로 전체 + 세로 m_*.png 생성)
& "<godot>" --path E:\Game\Block res://tests/visual_capture.tscn
```
- `.tmp_shots/`에서 가로(title, escape, endless…)와 세로(m_title, m_escape, m_endless) **양쪽을 눈으로 확인**. 새 UI가 생겼으면 visual_capture.gd에 캡처 추가.
- 수동 확인이 필요하면: 스팀 = 그냥 실행, 모바일 = `& "<godot>" --path E:\Game\Block -- --mobile` (세로 창 에뮬레이션).
- 플랫폼 폴더에 리소스를 추가/이동했으면 Web 익스포트 로그로 필터 동작 확인: `--export-release "Web"` 후 로그에 `steam/`·`mobile/` 파일이 없어야 함.
- 새 `class_name`을 만들었으면 헤드리스 실행 전 `--import` 필수.

## 흔한 실수

- core 코드/씬에서 `preload("res://mobile/...")` → 스팀 빌드 파싱 실패. 반드시 피처 가드 + `load()`.
- `main.tscn`에 노드만 추가하고 `main_mobile.tscn` 오버라이드를 빼먹음 → 모바일에서 화면 밖/겹침.
- 새 UI에 1920/1080 좌표 하드코딩 → 세로에서 깨짐. 뷰포트 기준으로.
- autoload를 플랫폼 폴더에 두기 → 익스포트 필터로 제외되면 모든 빌드가 죽는다. autoload는 `core/`·`platform/`에만.
- 익스포트 필터 갱신 누락: 새 최상위 플랫폼 폴더를 만들면 `export_presets.cfg`의 exclude_filter 세 프리셋 모두 확인.
