# Block (게임 타이틀: Cat-Tris)

Godot 4.6 (2D) 게임 프로젝트. 구덩이에 빠진 큐브 고양이가 테트리스 블록을 밟고 위로 탈출하는 게임.

## 실행

- Godot 실행 파일: `C:/Users/SangWook Lee/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe`
- 에디터 열기: `& "<godot>" --editor --path E:\Game\Block`
- 게임 실행: `& "<godot>" --path E:\Game\Block`
- godot-mcp 서버가 `.mcp.json`에 설정되어 있음 (E:/GODOT/godot-mcp)

## 배포 (GitHub Pages)

- 라이브 URL: PC https://kiliuswook.github.io/Block/ (`gh-pages` 루트) / 모바일 세로판 https://kiliuswook.github.io/Block/m/ (`gh-pages`의 `m/`)
- 절차: ① PC `--export-release "Web" build/web/index.html`, 모바일 `--export-release "WebMobile" build/web_m/index.html` ② `build/web/*` → gh-pages 루트, `build/web_m/*` → gh-pages `m/`에 복사(git worktree 사용) 후 커밋·푸시. 코어 수정 시 **두 빌드 모두** 재배포
- PC판 `index.html`에는 터치 기기 → `m/` 리다이렉트가 들어감 (Web 프리셋의 `html/head_include` — 익스포트 시 자동 포함)
- 커밋 전 `index.html`에 캐시 버스터 필수: `index.js` src와 GODOT_CONFIG의 `mainPack`(`index.pck?v=<타임스탬프>`)에 버전 쿼리를 붙일 것 — Pages가 10분 캐시(`max-age=600`)라 이걸 안 하면 배포 직후 브라우저에 이전 빌드가 보임

## 구조 (스팀/모바일 멀티 플랫폼)

> **컨텐츠·시스템·UI를 수정/추가할 때는 `/platform-split` 스킬(`.claude/skills/platform-split/SKILL.md`)의 분기 규칙·체크리스트를 따를 것.**

- `core/` — 두 플랫폼이 공유하는 게임 본체
  - `core/scenes/` — 씬 파일 (.tscn). 메인 씬: `core/scenes/main.tscn`
  - `core/scripts/` — 씬에 붙는 스크립트 (.gd)
  - `core/autoload/` — 싱글톤 (EventBus, GameState)
- `shared/assets/` — 공용 리소스 (이미지, 사운드, 폰트)
- `platform/` — 플랫폼 추상화: `platform.gd`(autoload `Platform`, 피처 태그로 구현체 선택) + `platform_base.gd`(no-op 기본 구현, `PlatformBase`)
- 시작 씬은 `core/scenes/boot.tscn` — 피처 태그(개발 시 `-- --steam`/`-- --mobile` 인자)로 플랫폼 타이틀에 라우팅: 스팀 `steam/ui/title_steam.tscn`, 모바일 `mobile/ui/title_mobile.tscn`, 그 외 `core/scenes/title.tscn`. 타이틀 복귀도 boot 경유(`main.gd`). 플랫폼 타이틀은 core 타이틀 씬을 상속(+스크립트 `extends "res://core/scripts/title.gd"`)
- 모바일은 **세로 화면 1080×1920** (`project.godot`의 `.mobile` 피처 오버라이드 + `handheld/orientation=1`), 대전·2인 분할 모드 없음, 터치 컨트롤 항상 표시. 게임 씬은 `mobile/ui/main_mobile.tscn`(main.tscn 상속, 세로 오프셋 오버라이드), 타이틀 스크립트가 `main_scene` 변수로 로드할 씬을 정함. 데스크톱에서 `-- --mobile` 인자로 세로 창 포함 에뮬레이션 가능
- `steam/` / `mobile/` — 플랫폼 전용 코드·UI·컨텐츠. **`core/`에서 이쪽을 `preload`/씬 하드 참조 금지** — 익스포트 필터로 반대 플랫폼 빌드에서 제외되므로, 반드시 `OS.has_feature("steam"/"mobile")` 가드 + `load()` 사용. 구현체에 `class_name` 금지
- `docs/` — 기획/설계 문서
- `tests/` — 테스트. 실행: `& "<godot>" --headless --path E:\Game\Block res://tests/test_board.tscn` (탈출 모드: `res://tests/test_escape.tscn`)

## 익스포트 프리셋 (export_presets.cfg)

- `Web` — GitHub Pages용, `steam/*`·`mobile/*` 제외 (no-op Platform)
- `Steam` — Windows Desktop, 커스텀 피처 태그 `steam`, `mobile/*` 제외, 출력 `build/steam/`
- `Mobile` — Android, 커스텀 피처 태그 `mobile`, `steam/*` 제외, 출력 `build/mobile/` (빌드하려면 Android SDK/익스포트 템플릿 설정 필요)

## 게임 코어

- 타이틀(`core/scenes/title.tscn`, boot이 로드) — 모드 선택 후 `GameState.mode`(+`GameState.split`)에 저장하고 `core/scenes/main.tscn` 로드
- 모드: 탈출 모드(좌우 벽 상단의 출구로 나가면 레벨업) / 무한의 계단 모드(카메라가 플레이어를 위아래로 추적, 아래에서 용암이 상승 — 닿으면 사망, 높이 기록) / 2P 대전 모드(`Mode.VERSUS`: P1 고양이 vs P2 블록 직접 조종, 3선승)
- 화면 분할 2인(`GameState.split`): 탈출/무한을 SubViewport 2개로 나눠 경쟁(라운드제 3선승). 보드 씬은 `core/scenes/board.tscn`, 분할 빌드는 `main.gd._build_split()`. 좌석 배치 = 키보드 배치: P1(왼쪽 화면)이 WASD+Q/E+Ctrl(`p2_*` 액션), P2(오른쪽 화면)가 방향키+, .(또는 Z/X)+Shift(기본 액션). 보드/플레이어의 `act_*` 변수로 액션 이름 주입. 분할 중 보드는 EventBus 대신 로컬 `finished(win)` 시그널 사용
  - `core/scripts/escape_board.gd` — 필드/블록 로직 (블록이 캐릭터 열 추적 → 5초 후 자유낙하 → 락, 줄 클리어, 깔림 판정, 탈출 판정)
  - `core/scripts/player.gd` — 캐릭터 물리 (이동, 더블탭 대시, 점프+공중 제어, 빠른 낙하, AABB 충돌)
- 클래식 테트리스 로직은 `core/scripts/board.gd`에 유지 (SRS 회전+월킥, 7-bag 등) — escape_board가 SHAPES/KICKS/COLORS 상수를 재사용
- UI 배선/재시작/일시정지: `core/scripts/main.gd`
- 렌더링은 텍스처 없이 `_draw()`로 직접 그림
- 아트 규칙(Cat-Tris): 빛은 항상 위에서(블록 윗면만 하이라이트), 가장 따뜻한 것 = 플레이어(크림 #f4e3c8), 가장 밝은 것 = 출구의 빛(#fff3d0). 무한의 계단은 높이 오를수록 배경이 밝아짐. 큐브 고양이 렌더는 `Player.paint_cat()` 정적 함수 — 타이틀 등 어디서든 재사용
- 캐릭터/재화: 스킨 9종·해금 조건·골드/보석 지갑은 `GameState`(CATS 상수, save.json 저장), 선택 UI는 타이틀(`core/scripts/title.gd`), 보상 지급은 `main.gd._award_run_rewards()` — 스킨 색은 `paint_cat()`의 `skin` 파라미터로 전달
- 씬 스크린샷 캡처: `& "<godot>" --path E:\Game\Block res://tests/visual_capture.tscn` → `.tmp_shots/`에 저장
- 새 `class_name` 추가 시 헤드리스 실행 전 `--import`로 전역 클래스 캐시 갱신 필요

## 컨벤션

- GDScript: 탭 들여쓰기, 타입 힌트 사용 (`var x: int`, `-> void`)
- 파일명: snake_case (`event_bus.gd`), 노드명: PascalCase
- 전역 이벤트는 EventBus 시그널로 통신, 전역 상태는 GameState에 보관
- 씬 간 직접 참조 대신 시그널 우선
