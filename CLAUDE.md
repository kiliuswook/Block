# Block (게임 타이틀: Cat-Tris)

Godot 4.6 (2D) 게임 프로젝트. 구덩이에 빠진 큐브 고양이가 테트리스 블록을 밟고 위로 탈출하는 게임.

## 실행

- Godot 실행 파일: `C:/Users/SangWook Lee/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe`
- 에디터 열기: `& "<godot>" --editor --path E:\Game\Block`
- 게임 실행: `& "<godot>" --path E:\Game\Block`
- godot-mcp 서버가 `.mcp.json`에 설정되어 있음 (E:/GODOT/godot-mcp)

## 배포 (GitHub Pages)

> **"io 배포"/"배포해줘" 요청 시 항상 PC·모바일 두 빌드를 모두 빌드·배포한다.** 한쪽만 배포하는 것은 사용자가 명시적으로 지정한 경우("PC만", "모바일만")뿐.

- 라이브 URL: PC https://kiliuswook.github.io/Block/ (`gh-pages` 루트) / 모바일 세로판 https://kiliuswook.github.io/Block/m/ (`gh-pages`의 `m/`)
- 절차 (순서대로):
  1. **익스포트 (둘 다)**: `& "<godot>" --headless --path E:\Game\Block --export-release "Web" build/web/index.html` 그리고 `--export-release "WebMobile" build/web_m/index.html`
  2. **캐시 버스터 (둘 다)**: 각 `index.html`에서 `index.js` src와 GODOT_CONFIG의 `mainPack`에 버전 쿼리(`?v=<타임스탬프>`)를 붙일 것 — Pages가 10분 캐시(`max-age=600`)라 이걸 안 하면 배포 직후 브라우저에 이전 빌드가 보임
  3. **gh-pages 복사**: git worktree로 `gh-pages` 체크아웃 → `build/web/*` → 루트, `build/web_m/*` → `m/`에 복사 (기존 `m/`은 비우고 복사, 루트의 `m/` 폴더는 삭제 금지)
  4. **커밋·푸시** 후 worktree 정리, 두 URL 모두 안내
- PC판 `index.html`에는 터치 기기 → `m/` 리다이렉트가 들어감 (Web 프리셋의 `html/head_include` — 익스포트 시 자동 포함)

## 구조 (스팀/모바일 멀티 플랫폼)

> **컨텐츠·시스템·UI를 수정/추가할 때는 `/platform-split` 스킬(`.claude/skills/platform-split/SKILL.md`)의 분기 규칙·체크리스트를 따를 것.**
>
> **사용자에게 보이는 텍스트를 추가/수정할 때는 `/i18n` 스킬(`.claude/skills/i18n/SKILL.md`)을 따를 것** — 스팀 출시 목표는 13개국어. 문자열 하드코딩 금지, `_draw()` 텍스트는 `tr()` 수동 적용.

- `core/` — 두 플랫폼이 공유하는 게임 본체
  - `core/scenes/` — 씬 파일 (.tscn). 메인 씬: `core/scenes/main.tscn`
  - `core/scripts/` — 씬에 붙는 스크립트 (.gd)
  - `core/autoload/` — 싱글톤 (EventBus, GameState, I18n, Sfx, Replays, Ranks — 랭킹은 `ranks.gd`의 `BOARD_URL` 비면 목업 봇 오프라인 모드)
- `shared/assets/` — 공용 리소스 (이미지, 사운드, 폰트 — 기본 폰트는 `fonts/ui_font.tres`, 다국어 폴백 체인 포함)
- `shared/locale/` — 번역 CSV (`ui`/`content`/`flavor`). 손댄 뒤에는 `--script res://tools/locale_tool.gd` → `--import` 순서로 갱신
- `tools/` — 개발용 스크립트 (`locale_tool.gd`: 빈 로케일 열 정리 + `en_XA` 의사 로케일 생성)
- `platform/` — 플랫폼 추상화: `platform.gd`(autoload `Platform`, 피처 태그로 구현체 선택) + `platform_base.gd`(no-op 기본 구현, `PlatformBase`)
- 시작 씬은 `core/scenes/boot.tscn` — 피처 태그로 플랫폼 타이틀에 라우팅. 개발 시 플랫폼 강제: ① 에디터에서 `tests/run_mobile.tscn`/`run_steam.tscn` 열고 **F6** (권장 — 세로 창·복귀까지 유지) ② 커맨드라인 `--mobile`/`--steam` 인자(`--` 구분자 유무 무관) ③ 모바일 씬(title_mobile/main_mobile) 직접 F6도 자동 보정. 강제 상태는 `boot.gd`의 `dev_platform` static이 세션 동안 유지: 스팀 `steam/ui/title_steam.tscn`, 모바일 `mobile/ui/title_mobile.tscn`, 그 외 `core/scenes/title.tscn`. 타이틀 복귀도 boot 경유(`main.gd`). 플랫폼 타이틀은 core 타이틀 씬을 상속(+스크립트 `extends "res://core/scripts/title.gd"`)
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
- **플레이 가능한 모드는 둘뿐**: **스테이지 모드**(`Mode.CLASSIC` — 구 "클래식 테트리스", 이름만 바뀌고 로직은 그대로) / **무한의 계단**(`Mode.ENDLESS`). 타이틀 `PLAY` → 모드 선택 오버레이에 이 둘만 노출되고, 단축키는 1·2
  - 스테이지 모드(`Mode.CLASSIC`): 밀폐 우물, 아타리 테트리스 B-type 구조 — LEVEL 하나 = 판(스테이지) 하나. 목표 줄(`Board.classic_quota()` — LV1 3줄에서 판마다 +1, 최대 10줄)을 지우면 셔터가 내려오며 지나가는 빈 줄마다 보너스 100×LEVEL을 지급(=낮게 쌓을수록 이득). 셔터는 **쌓인 블록 높이까지만** 내려와 그 자리에서 멈추고, 남은 블록을 부수며 다음 LEVEL 필드를 깐 뒤 다시 올라감 — 전 과정 자동, 안내 텍스트 없음. 낙하 속도는 두 판마다 한 단계씩(`classic_speed()` → `CLASSIC_FRAMES`) + 마라톤 크립(`_speed_creep()`: 두 모드 공통, 플레이 45초당 +1단계, 최대 +8 — 무한은 낙하만, 용암 속도는 높이 기준 유지), 바닥 방해 블록은 LV5부터(GB Type-B, `classic_garbage()`, 최대 6줄) 증가. 셔터 상태는 `escape_board.gd`의 `shutter_*`, LINES 목표는 타일 랙 UI `core/scripts/goal_meter.gd`. 랭킹/저장 키는 계속 `classic`
  - 무한의 계단(`Mode.ENDLESS`): 카메라가 플레이어를 위아래로 추적, 아래에서 용암이 상승 — 닿으면 사망, 높이 기록
  - **메뉴에서 내린 모드**(코드·리소스는 남아 있음, 되살리려면 타이틀에 버튼만 다시 붙이면 됨): 스토리(`Mode.STORY` + `story_stages.gd` 120스테이지), 2P 대전(`Mode.VERSUS`), 젤리 피크닉(`Mode.PICNIC`), 화면 분할 2인(`GameState.split`). `main.gd`/`escape_board.gd`의 분기와 `Ranks`의 `story`/`picnic` 보드 키도 그대로 둠
- (메뉴에서 내림) 화면 분할 2인(`GameState.split`): 탈출 경주/무한을 SubViewport 2개로 나눠 경쟁(라운드제 3선승). 분할 중 스토리 스테이지 로직은 비활성(항상 문 열린 탈출 경주). 보드 씬은 `core/scenes/board.tscn`, 분할 빌드는 `main.gd._build_split()`. 좌석 배치 = 키보드 배치: P1(왼쪽 화면)이 WASD+Q/E+Ctrl(`p2_*` 액션), P2(오른쪽 화면)가 방향키+, .(또는 Z/X)+Shift(기본 액션). 보드/플레이어의 `act_*` 변수로 액션 이름 주입. 분할 중 보드는 EventBus 대신 로컬 `finished(win)` 시그널 사용
  - `core/scripts/escape_board.gd` — 필드/블록 로직 (블록이 캐릭터 열 추적 → 5초 후 자유낙하 → 락, 줄 클리어, 깔림 판정, 탈출 판정)
  - `core/scripts/player.gd` — 캐릭터 물리 (이동, 더블탭 대시, 점프+공중 제어, 빠른 낙하, AABB 충돌)
- 테트리스 규칙 로직은 `core/scripts/board.gd`에 유지 (SRS 회전+월킥, 7-bag 등) — escape_board가 SHAPES/KICKS/COLORS 상수를 재사용
- UI 배선/재시작/일시정지: `core/scripts/main.gd`
- 렌더링은 텍스처 없이 `_draw()`로 직접 그림
- 사운드도 에셋 파일 없이 전부 코드 합성: `core/autoload/sfx.gd`(autoload `Sfx`)가 시작 시 SFX를, 첫 재생 시 BGM 루프("title"/"game")를 렌더. `Sfx.play("이름")`/`Sfx.play_bgm()` 호출. 버스는 Master/BGM/SFX(런타임 생성), 볼륨은 `GameState.vol_*`(save.json)에 저장, UI는 `core/scripts/settings_panel.gd`(타이틀 ⚙ 버튼 + 인게임 일시정지 메뉴 겸용)
- 아트 규칙(Cat-Tris): 빛은 항상 위에서(블록 윗면만 하이라이트), 가장 따뜻한 것 = 플레이어(크림 #f4e3c8), 가장 밝은 것 = 출구의 빛(#fff3d0). 무한의 계단은 높이 오를수록 배경이 밝아짐. 큐브 고양이 렌더는 `Player.paint_cat()` 정적 함수 — 타이틀 등 어디서든 재사용
- **UI 컨셉·키트 (`core/scripts/ui_kit.gd`, class_name 없음 — `preload`로 참조)**: 아트 컨셉은 밝은 하늘색 배경 + 발바닥 무늬, 두꺼운 잉크 외곽선(#2c2a33, 4px), 둥근 모서리, 아래로 두께감(베벨)이 있는 통통한 버튼. 새 UI를 만들 때 스타일박스를 직접 짜지 말고 키트를 쓸 것:
  - 팔레트 상수 `SKY/INK/WHITE/ORANGE/GOLD/CYAN/PURPLE/RED/PINK/MUTED` (+ 각 `*_DEEP` = 베벨 색)
  - 버튼: `btn_primary`(오렌지 주 버튼) / `btn_card(accent)`(흰 카드 + 강조 베벨) / `btn_ghost`(닫기 등) / `btn_chip(active)`(탭·토글) / `style_button(face, deep, text, size, radius)`
  - 패널: `panel_box(bg, radius, pad)` — 흰 카드 배경. 오버레이 딤은 `Color(0.09, 0.13, 0.18, 0.55)`
  - 배경: `paint_backdrop(ci, size)` (하늘 + 발바닥), `paw()`, `ellipse()`
  - 블록 타이포: `block()` / `block_text()` / `block_text_width()` — 3×5 블록 폰트(`GLYPHS`), 타이틀 로고가 이걸로 그려짐
  - `apply_theme(canvas_layer_or_control)`로 기본 Label/Button/LineEdit 톤을 깐다. **단 `cat_customizer`·`replay_viewer`는 의도적으로 어두운 무대 연출이라 테마 제외**(`theme = null`)
- 타이틀 구조(컨셉 반영): 로고·배경·타이틀 고양이는 `title.gd._draw()`가 직접 그림. 메뉴는 `PLAY` + 카드 4장(캐릭터/상점/랭킹/설정) + 키캡 알약. 모드 선택과 캐릭터 선택은 각각 `_build_mode_select()` / `_build_character_row()`가 만드는 **오버레이**(`_make_overlay()` 공용 껍데기, `"body"` 메타에 내용 배치). 레이아웃은 `_compute_layout()`/`_menu_rect()`가 화면 비율로 계산해 가로·세로 화면을 한 코드로 처리 — 모바일 타이틀은 `show_2p = false`·`max_tiles_per_row`만 지정. 오버레이는 열 때 `_raise()`로 메뉴 위로 올린다
- 골드 획득(전 모드, 분할·대전 제외 — 지갑 하나 원칙): ① 블록 속 금맥 `ore`(스폰 시 `ORE_CHANCE`로 한 칸에 박힘 — 줄 클리어·2회 타격 파괴·셔터·부활 폭발 등 그 칸이 사라질 때 `_bank_ore()`로 지급) ② 낙하 블록 위에 얹힌 금덩이 `rider`(**회전하면 떨어져** 주울 수 있음, 안 떨어뜨리면 락/분리될 때 스택 위로 굴러떨어짐) ③ 피버 중 골드 비(엔드리스, `FEVER_RAIN_INTERVAL`). 떨어진 금덩이는 `nuggets`(중력 낙하 → 착지 → 고양이가 닿으면 획득, `NUGGET_LIFE` 후 소멸). 관련 상수는 `escape_board.gd`의 `ORE_*`/`RIDER_*`/`NUGGET_*`
- 알파벳 키캡 수집: 플레이 중 배치된 블록 하나가 주기적으로 고양이 키캡(A~Z)으로 변하고, 그 줄을 지우면 획득 (`escape_board.gd`의 `KEYCAP_*` 상수 — **현재 테스트용 고빈도(6초/60%), 릴리스 전 낮출 것**). 중복 수집 가능, 저장은 `GameState.keycaps`(save.json). 타이틀 메뉴의 "▦ 키캡 도감" 버튼 → 키보드 도감 오버레이(`title.gd`). 키캡 렌더는 `EscapeBoard.paint_keycap()` 정적 함수(도감과 공유)
- 나만의 냥(커스텀 캐릭터): CATS의 `custom` 슬롯(무료·밸런스 스탯). 부위 카탈로그(15개 부위 ~150 옵션, 희귀도 `r`·플레이버 `d`)·팔레트는 `core/scripts/custom_cat.gd`(class_name 없음, preload로 참조), 선택값은 `GameState.custom_cat`(save.json). 렌더는 `paint_cat`의 `skin["custom"]` 분기. 꾸미기 UI는 "냥이 크리에이터 3000"(`core/scripts/cat_customizer.gd`, 타이틀 캐릭터 팝업의 🎨 꾸미기 버튼) — AAA 흉내 B급 감성의 풀스크린 오버레이(스포트라이트 무대·유전자 스캔·싱크로율 게이지)
- 캐릭터/재화: 스킨 9종·해금 조건(골드/보석/무한 높이/스토리 스테이지/플레이 수)·골드/보석 지갑은 `GameState`(CATS 상수, save.json 저장), 선택 UI는 타이틀(`core/scripts/title.gd`), 보상 지급은 `main.gd._award_run_rewards()` — 스킨 색은 `paint_cat()`의 `skin` 파라미터로 전달
- 씬 스크린샷 캡처: `& "<godot>" --path E:\Game\Block res://tests/visual_capture.tscn` → `.tmp_shots/`에 저장
- 새 `class_name` 추가 시 헤드리스 실행 전 `--import`로 전역 클래스 캐시 갱신 필요

## 컨벤션

- GDScript: 탭 들여쓰기, 타입 힌트 사용 (`var x: int`, `-> void`)
- 파일명: snake_case (`event_bus.gd`), 노드명: PascalCase
- 전역 이벤트는 EventBus 시그널로 통신, 전역 상태는 GameState에 보관
- 씬 간 직접 참조 대신 시그널 우선
