# Block (게임 타이틀: Cat-Tris)

Godot 4.6 (2D) 게임 프로젝트. 구덩이에 빠진 큐브 고양이가 테트리스 블록을 밟고 위로 탈출하는 게임.

> ## ⛳ 현재 개발 방향: **PC(스팀) 우선** (2026-08-27~)
>
> **모바일 개발은 당분간 보류.** PC(가로 1920×1080, 키보드) 버전을 먼저 완성한다.
> - 새 기능·UI·컨텐츠는 **PC 기준으로만** 만든다. 모바일 세로 레이아웃(`mobile/ui/main_mobile.tscn` 오버라이드), 터치 버튼, `title_mobile.gd` 숨김 처리 등은 **하지 않는다**.
> - 배포도 **PC 빌드만** — 아래 배포 절차의 모바일 단계는 건너뛴다.
> - `mobile/` 폴더와 기존 모바일 코드·씬은 **지우지 않고 그대로 둔다** (나중에 재개).
> - 단, `core/`에 화면 크기를 하드코딩하지 않는 원칙은 계속 지킨다 — 재개 비용을 낮추기 위함.
> - 모바일 작업이 필요하면 사용자가 명시적으로 요청할 때만 ("모바일도", "모바일 빌드").

## 실행

- Godot 실행 파일: `C:/Users/SangWook Lee/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe`
- 에디터 열기: `& "<godot>" --editor --path E:\Game\Block`
- 게임 실행: `& "<godot>" --path E:\Game\Block`
- godot-mcp 서버가 `.mcp.json`에 설정되어 있음 (E:/GODOT/godot-mcp)

## 배포 (GitHub Pages)

> **PC 우선 기간(현재): "io 배포"/"배포해줘" 요청 시 PC 빌드만 빌드·배포한다.** `gh-pages`의 기존 `m/`(모바일 세로판)은 **손대지 않고 그대로 둔다** — 지난 배포본이 계속 서비스된다.
>
> <details><summary>모바일 재개 시 되돌릴 원래 규칙 (지금은 적용 안 함)</summary>
>
> "io 배포"/"배포해줘" 요청 시 항상 PC·모바일 두 빌드를 모두 빌드·배포한다. 한쪽만 배포하는 것은 사용자가 명시적으로 지정한 경우("PC만", "모바일만")뿐.
> </details>

- 라이브 URL: PC https://kiliuswook.github.io/Block/ (`gh-pages` 루트) / 모바일 세로판 https://kiliuswook.github.io/Block/m/ (`gh-pages`의 `m/` — **보류 중, 갱신하지 않음**)
- 절차 (순서대로 — PC 우선 기간에는 ⓜ 표시 단계를 건너뛴다):
  1. **익스포트**: `& "<godot>" --headless --path E:\Game\Block --export-release "Web" build/web/index.html` / ⓜ `--export-release "WebMobile" build/web_m/index.html`
  2. **캐시 버스터**: `index.html`에서 `index.js` src와 GODOT_CONFIG의 `mainPack`에 버전 쿼리(`?v=<타임스탬프>`)를 붙일 것 — Pages가 10분 캐시(`max-age=600`)라 이걸 안 하면 배포 직후 브라우저에 이전 빌드가 보임 (ⓜ 모바일 `index.html`도 동일)
  3. **gh-pages 복사**: git worktree로 `gh-pages` 체크아웃 → `build/web/*` → 루트에 복사. **루트의 `m/` 폴더는 절대 삭제·갱신하지 말 것** / ⓜ `build/web_m/*` → `m/` (기존 `m/`을 비우고 복사)
  4. **커밋·푸시** 후 worktree 정리, PC URL 안내 (ⓜ 두 URL 모두)
- PC판 `index.html`에는 터치 기기 → `m/` 리다이렉트가 들어감 (Web 프리셋의 `html/head_include` — 익스포트 시 자동 포함). 모바일 배포를 멈춰도 `m/`이 살아 있으므로 이 리다이렉트는 그대로 유효

## 구조 (스팀/모바일 멀티 플랫폼)

> **컨텐츠·시스템·UI를 수정/추가할 때는 `/platform-split` 스킬(`.claude/skills/platform-split/SKILL.md`)의 분기 규칙을 따를 것** — 단 PC 우선 기간이므로 그 스킬의 **모바일 대응 항목은 보류**(참조 방향 철칙·좌표 하드코딩 금지는 계속 유효).
>
> **사용자에게 보이는 텍스트를 추가/수정할 때는 `/i18n` 스킬(`.claude/skills/i18n/SKILL.md`)을 따를 것** — 스팀 출시 목표는 13개국어. 문자열 하드코딩 금지, `_draw()` 텍스트는 `tr()` 수동 적용.
>
> **랭킹·기록·업적·클라우드 세이브를 건드릴 때는 `/steam-backend` 스킬(`.claude/skills/steam-backend/SKILL.md`)을 따를 것** — 자체 서버 없이 Steamworks가 백엔드다. 비동기 직렬화 규칙·보드 이름 규칙·UGC 핸들 함정이 거기 정리돼 있다. **사용자가 파트너 사이트에서 해야 할 일**(앱 id, Auto-Cloud, 업적 등록, 빌드 업로드)은 `docs/steam_setup.md`에 체크리스트로 있다 — 스팀 계정 세팅 뒤 이어서 진행할 때 여기부터 볼 것.

- `core/` — 두 플랫폼이 공유하는 게임 본체
  - `core/scenes/` — 씬 파일 (.tscn). 메인 씬: `core/scenes/main.tscn`
  - `core/scripts/` — 씬에 붙는 스크립트 (.gd)
  - `core/autoload/` — 싱글톤 (EventBus, GameState, I18n, Sfx, Replays, Ranks). 랭킹 백엔드는 `ranks.gd`의 `backend()`가 **STEAM → HTTP → OFFLINE** 순으로 고른다: 스팀 빌드에서 초기화가 되면 Steamworks 리더보드, 아니면 `BOARD_URL`(jsonblob) HTTP 보드, 그것도 비면 목업 봇 오프라인 모드. 자세한 규칙은 `/steam-backend` 스킬
- `shared/assets/` — 공용 리소스 (이미지, 사운드, 폰트 — 기본 폰트는 `fonts/ui_font.tres`, 다국어 폴백 체인 포함)
- `shared/locale/` — 번역 CSV (`ui`/`content`/`flavor`). 손댄 뒤에는 `--script res://tools/locale_tool.gd` → `--import` 순서로 갱신
- `tools/` — 개발용 스크립트 (`locale_tool.gd`: 빈 로케일 열 정리 + `en_XA` 의사 로케일 생성)
- `platform/` — 플랫폼 추상화: `platform.gd`(autoload `Platform`, 피처 태그 또는 `--steam`/`--mobile` 인자로 구현체 선택 → `setup()` 호출) + `platform_base.gd`(no-op 기본 구현, `PlatformBase` — 업적·클라우드·리더보드 계약이 여기 다 적혀 있다)
- `addons/godotsteam/` — GodotSteam GDExtension 4.22 (Steamworks SDK 1.65). **win64 바이너리만** 남겨 뒀고(8.3MB), Web/WebMobile/Mobile 익스포트 프리셋에서는 제외된다. 스팀 앱 id는 `project.godot`의 `cattris/steam/app_id`(지금 480 = Valve 테스트 앱). 구현은 `steam/steam_platform.gd`, 점검은 `res://tests/steam_check.tscn`
- 시작 씬은 `core/scenes/boot.tscn` — 피처 태그로 플랫폼 타이틀에 라우팅. 개발 시 플랫폼 강제: ① 에디터에서 `tests/run_mobile.tscn`/`run_steam.tscn` 열고 **F6** (권장 — 세로 창·복귀까지 유지) ② 커맨드라인 `--mobile`/`--steam` 인자(`--` 구분자 유무 무관) ③ 모바일 씬(title_mobile/main_mobile) 직접 F6도 자동 보정. 강제 상태는 `boot.gd`의 `dev_platform` static이 세션 동안 유지: 스팀 `steam/ui/title_steam.tscn`, 모바일 `mobile/ui/title_mobile.tscn`, 그 외 `core/scenes/title.tscn`. 타이틀 복귀도 boot 경유(`main.gd`). 플랫폼 타이틀은 core 타이틀 씬을 상속(+스크립트 `extends "res://core/scripts/title.gd"`)
- 모바일은 **세로 화면 1080×1920** (`project.godot`의 `.mobile` 피처 오버라이드 + `handheld/orientation=1`), 대전·2인 분할 모드 없음, 터치 컨트롤 항상 표시. 게임 씬은 `mobile/ui/main_mobile.tscn`(main.tscn 상속, 세로 오프셋 오버라이드), 타이틀 스크립트가 `main_scene` 변수로 로드할 씬을 정함. 데스크톱에서 `-- --mobile` 인자로 세로 창 포함 에뮬레이션 가능
- `steam/` / `mobile/` — 플랫폼 전용 코드·UI·컨텐츠. **`core/`에서 이쪽을 `preload`/씬 하드 참조 금지** — 익스포트 필터로 반대 플랫폼 빌드에서 제외되므로, 반드시 `OS.has_feature("steam"/"mobile")` 가드 + `load()` 사용. 구현체에 `class_name` 금지
- `docs/` — 기획/설계 문서
- `tests/` — 테스트. 캐릭터 시트 캡처: `res://tests/cat_sheet.tscn` → `.tmp_shots/cat_sheet.png`. 실행: `& "<godot>" --headless --path E:\Game\Block res://tests/test_board.tscn` (탈출 모드: `res://tests/test_escape.tscn`)

## 익스포트 프리셋 (export_presets.cfg)

- `Web` — GitHub Pages용, `steam/*`·`mobile/*` 제외 (no-op Platform)
- `Steam` — Windows Desktop, 커스텀 피처 태그 `steam`, `mobile/*` 제외, 출력 `build/steam/`
- `Mobile` — Android, 커스텀 피처 태그 `mobile`, `steam/*` 제외, 출력 `build/mobile/` (빌드하려면 Android SDK/익스포트 템플릿 설정 필요)

## 게임 코어

- 타이틀(`core/scenes/title.tscn`, boot이 로드) — 모드 선택 후 `GameState.mode`(+`GameState.split`)에 저장하고 `core/scenes/main.tscn` 로드
- **PLAY 흐름**: 인원도 캐릭터도 **타이틀에서 미리 세팅**한다 — 플레이 입장 때는 아무것도 묻지 않는다. ① PLAY 버튼 바로 아래 `👤 1인 플레이` / `👥 2인 플레이` 토글 칩(`title.gd`의 `_players_chips`/`_set_players()`, 값은 `GameState.players` → save.json) ② 타이틀 `캐릭터` 카드(`_open_chars()`)가 그 인원만큼 자리 카드(1P·2P)를 띄우는 세팅 화면이고, 타일을 누르면 `_assign_pick()`이 `_commit_pick()`으로 **즉시** `GameState.selected_cat`/`selected_cat2`에 저장한다(확정 버튼 없이 `확인`은 그냥 닫기). 인원 토글을 바꾸면 열려 있는 캐릭터 화면의 자리 수도 그 자리에서 따라간다. 그래서 흐름은 `PLAY` → **모드 선택** → **바로 시작**(`_on_mode_picked()` → `_start(mode, _pick_count > 1)`). 모드 선택은 열 때마다 `_seats()`로 인원을 읽어(`_pick_count`) 제목에 `· 2인 플레이`를 붙이고, 그 인원을 못 받는 모드는 회색 + `1인 전용` 뱃지로 잠근다(`_refresh_mode_rows()`, 행 참조 `_mode_rows`). 모드별 최대 인원은 `MODE_PLAYERS` 상수(지금은 무한의 계단만 2인 — 스테이지 모드는 LINES 목표 UI가 분할 화면에 안 들어감). 모바일 타이틀은 `allow_2p = false`라 토글이 안 뜨고 항상 1인 + 1P 자리 하나다.
- **플레이 가능한 모드는 둘뿐**: **스테이지 모드**(`Mode.CLASSIC` — 구 "클래식 테트리스", 이름만 바뀌고 로직은 그대로) / **무한의 계단**(`Mode.ENDLESS`). 타이틀 `PLAY` → 모드 선택 오버레이에 이 둘만 노출되고, 단축키는 1·2
  - 스테이지 모드(`Mode.CLASSIC`): 밀폐 우물, 아타리 테트리스 B-type 구조 — LEVEL 하나 = 판(스테이지) 하나. 목표 줄(`Board.classic_quota()` — LV1 3줄에서 판마다 +1, 최대 10줄)을 지우면 셔터가 내려오며 지나가는 빈 줄마다 보너스 100×LEVEL을 지급(=낮게 쌓을수록 이득). 셔터는 **쌓인 블록 높이까지만** 내려와 그 자리에서 멈추고, 남은 블록을 부수며 다음 LEVEL 필드를 깐 뒤 다시 올라감 — 전 과정 자동, 안내 텍스트 없음. 낙하 속도는 두 판마다 한 단계씩(`classic_speed()` → `CLASSIC_FRAMES`) + 마라톤 크립(`_speed_creep()`: 두 모드 공통, 플레이 45초당 +1단계, 최대 +8 — 무한은 낙하만, 용암 속도는 높이 기준 유지), 바닥 방해 블록은 LV5부터(GB Type-B, `classic_garbage()`, 최대 6줄) 증가. 셔터 상태는 `escape_board.gd`의 `shutter_*`, LINES 목표는 타일 랙 UI `core/scripts/goal_meter.gd`. 랭킹/저장 키는 계속 `classic`
  - 무한의 계단(`Mode.ENDLESS`): 카메라가 플레이어를 위아래로 추적, 아래에서 용암이 상승 — 닿으면 사망, 높이 기록
  - **메뉴에서 내린 모드**(코드·리소스는 남아 있음, 되살리려면 타이틀에 버튼만 다시 붙이면 됨): 스토리(`Mode.STORY` + `story_stages.gd` 120스테이지), 2P 대전(`Mode.VERSUS`), 젤리 피크닉(`Mode.PICNIC`). `main.gd`/`escape_board.gd`의 분기와 `Ranks`의 `story`/`picnic` 보드 키도 그대로 둠
- 화면 분할 2인(`GameState.split`): 인원 선택에서 2인을 고르면 켜진다. 탈출 경주/무한을 SubViewport 2개로 나눠 경쟁(라운드제 3선승). 분할 중 스토리 스테이지 로직은 비활성(항상 문 열린 탈출 경주). 보드 씬은 `core/scenes/board.tscn`, 분할 빌드는 `main.gd._build_split()`. 좌석 배치 = 키보드 배치: P1(왼쪽 화면)이 WASD+Q/E+Ctrl(`p2_*` 액션), P2(오른쪽 화면)가 방향키+, .(또는 Z/X)+Shift(기본 액션). 보드/플레이어의 `act_*` 변수로 액션 이름 주입. 분할 중 보드는 EventBus 대신 로컬 `finished(win)` 시그널 사용
  - `core/scripts/escape_board.gd` — 필드/블록 로직 (블록이 캐릭터 열 추적 → 5초 후 자유낙하 → 락, 줄 클리어, 깔림 판정, 탈출 판정)
  - `core/scripts/player.gd` — 캐릭터 물리 (이동, 더블탭 대시, 점프+공중 제어, 빠른 낙하, AABB 충돌)
- 테트리스 규칙 로직은 `core/scripts/board.gd`에 유지 (SRS 회전+월킥, 7-bag 등) — escape_board가 SHAPES/KICKS/COLORS 상수를 재사용
- UI 배선/재시작/일시정지: `core/scripts/main.gd`
- 렌더링은 텍스처 없이 `_draw()`로 직접 그림
- 사운드도 에셋 파일 없이 전부 코드 합성: `core/autoload/sfx.gd`(autoload `Sfx`)가 시작 시 SFX를, 첫 재생 시 BGM 루프("title"/"game")를 렌더. `Sfx.play("이름")`/`Sfx.play_bgm()` 호출. 버스는 Master/BGM/SFX(런타임 생성), 볼륨은 `GameState.vol_*`(save.json)에 저장, UI는 `core/scripts/settings_panel.gd`(타이틀 설정 카드 + 인게임 일시정지 메뉴 겸용)
- 아트 규칙(Cat-Tris): 빛은 항상 위에서(블록 윗면만 하이라이트), 가장 따뜻한 것 = 플레이어(크림 #f4e3c8), 가장 밝은 것 = 출구의 빛(#fff3d0). 무한의 계단은 높이 오를수록 배경이 밝아짐. 큐브 고양이 렌더는 **파츠 레이어 방식**(`core/scripts/cat_art.gd`, class_name 없음 — preload로 참조)이고, 호출은 어디서나 `Player.paint_cat(ci, center, size, look, alive, mouth_open, skin)` 정적 함수(내부에서 `CatArt.paint()`로 위임). `skin["parts"]` 딕셔너리 하나가 외형 전체를 결정하며, 레이어 순서는 컨셉 시트를 따른다: 등 소품 → 꼬리 → 귀 → 몸통(색/무늬/외곽선) → 귀 패치 → 배·가슴·목 소품 → 앞발 → 볼 → 수염 → 입 → 코 → 눈 → 이마 장식 → 얼굴 소품 → 머리 소품. 잉크 외곽선(#2c2a33)·둥근 몸통·젤리 발바닥이 기본 골격
- **캐릭터 그림은 컨셉 시트 원본을 그대로 쓴다** (`리소스/CATTRIS_Char_Sheet.png` — 마젠타 크로마키 시트, 6종 × 파츠 레이어가 전부 채워진 최신본. `리소스/1.png`은 char01만 채워져 있던 이전 시트). `python tools/extract_cat_sheet.py`가 시트에서 에셋을 뽑는다: `shared/assets/cats/char0N_tT.png`(6종 × 파츠 해금 4단계 완성 렌더, 278×293 공통 캔버스), `gray/char0N_tT.png`(잠금 실루엣·사망용 회청색 램프), `parts/char0N/*.png`(**6종 전부** 파츠 레이어 — 틴트 대상은 단색 마스크) + `layout.json`, 그리고 게임이 읽는 배치표 `core/scripts/cat_layouts.gd`(자동 생성, 직접 고치지 말 것). 시트의 파츠 셀은 파츠를 셀 한가운데 그려 둔 것이라 배치 좌표가 없어서, `tools/cat_layout.py`가 완성 렌더를 정답지 삼아 **FFT 상관으로 각 레이어 자리를 찾아낸다**(색이 평평한가 + 실루엣 바깥 링이 다른 색인가 → 그 다음 "지금 스택이 렌더와 어긋나는 자리"를 메우는 방향으로 정련). 판(t0~t3)마다 따로 정합해 레이어별로 가장 잘 드러난 판의 자리를 채택하고(char02는 t2부터 선글라스가 눈을 가린다), 기본 틴트·해금 단계도 완성 렌더와 대조해 뽑는다. 돌리는 데 10분쯤 걸리고, 끝에 캐릭터별 "어긋난 px"을 찍는다 — 대부분 안티에일리어싱 경계라 2~6k면 정상. 렌더러는 `core/scripts/cat_sprite.gd`(class_name 없음 — preload). `Player.paint_cat()` → `CatArt.paint()`가 `skin["sprite"]`(캐릭터 id)를 보면 스프라이트를 먼저 그리고, 못 그릴 때만 코드 렌더로 떨어진다. **부위 색을 바꿀 때만** 레이어를 겹쳐 그리고(`_paint_layers`), 아니면 완성 렌더 한 장을 쓴다. 소품(액세서리)·사망 X눈은 스프라이트 위에 코드로 얹는다. **밉맵 필수** — `.import`의 `mipmaps/generate=true`(278px 원본을 68px 타일로 줄여 그림. 새 파츠 png를 뽑은 뒤에는 `--import` → `mipmaps/generate` 확인). 키캡 아트도 이 그림을 재활용한다 — `CatSprite.FACE`(완성 렌더에서 얼굴만 오려낸 영역) + `CatSprite.face_texture()`를 `EscapeBoard.paint_keycap(ci, rect, letter, pulse, glow, cat_id)`가 캡 위에 얹고, 캡 바탕·귀 색은 그 냥이의 `body`/`ear`를 따른다 (cat_id를 비우면 예전 크림색 기본 키캡)
- **UI 컨셉·키트 (`core/scripts/ui_kit.gd`, class_name 없음 — `preload`로 참조)**: 아트 컨셉은 밝은 하늘색 배경 + 발바닥 무늬, 두꺼운 잉크 외곽선(#2c2a33, 4px), 둥근 모서리, 아래로 두께감(베벨)이 있는 통통한 버튼. 새 UI를 만들 때 스타일박스를 직접 짜지 말고 키트를 쓸 것:
  - 팔레트 상수 `SKY/INK/WHITE/ORANGE/GOLD/CYAN/PURPLE/RED/PINK/MUTED` (+ 각 `*_DEEP` = 베벨 색)
  - 버튼: `btn_primary`(오렌지 주 버튼) / `btn_card(accent)`(흰 카드 + 강조 베벨) / `btn_ghost`(닫기 등) / `btn_chip(active)`(탭·토글) / `style_button(face, deep, text, size, radius)`
  - 패널: `panel_box(bg, radius, pad)` — 흰 카드 배경. 오버레이 딤은 `Color(0.09, 0.13, 0.18, 0.55)`
  - 배경: `paint_backdrop(ci, size)` (하늘 + 발바닥), `paw()`, `ellipse()`
  - 블록 타이포: `block()` / `block_text()` / `block_text_width()` — 3×5 블록 폰트(`GLYPHS`), 타이틀 로고가 이걸로 그려짐
  - `apply_theme(canvas_layer_or_control)`로 기본 Label/Button/LineEdit 톤을 깐다. **단 `cat_customizer`·`replay_viewer`는 의도적으로 어두운 무대 연출이라 테마 제외**(`theme = null`)
- 타이틀 구조(컨셉 반영): 로고·배경·타이틀 고양이는 `title.gd._draw()`가 직접 그림. 메뉴는 `PLAY` + 카드 4장(캐릭터/뽑기/랭킹/설정) + 키캡 알약. 모드 선택과 캐릭터 선택은 각각 `_build_mode_select()` / `_build_character_row()`가 만드는 **오버레이**(`_make_overlay()` 공용 껍데기, `"body"` 메타에 내용 배치). 레이아웃은 `_compute_layout()`/`_menu_rect()`가 화면 비율로 계산해 가로·세로 화면을 한 코드로 처리 — 모바일 타이틀은 `allow_2p = false`·`max_tiles_per_row`만 지정. 오버레이는 열 때 `_raise()`로 메뉴 위로 올린다
- 설정 화면(`core/scripts/settings_panel.gd`) — UX 기획서 기준 **전체 화면 페이지**다(팝업 아님). 하늘색 헤더(지갑 · 제목 · `뒤로`) + 흰 본문, 본문은 세 페이지가 갈아 끼워진다: **기본**(해상도 / 언어 / 전체·BGM·SFX 음량 / 컨트롤러 진동 / `컨트롤러`·`키보드` 진입 / 게임 초기화) · **컨트롤러**(패드 버튼 재설정, 이동=LS+D-pad 고정) · **키보드**(`싱글` / `1P vs 2P` 탭, 좌석별 키 재설정 + 기본값 복구). `open(on_title)` 하나로 타이틀·일시정지를 겸하고, 해상도·언어·게임 초기화는 씬을 새로 여는 동작이라 **타이틀에서만** 노출된다(안 보이는 줄은 `_layout_main()`이 접어 준다). 칩을 누르면 입력 대기 → 다음 키/패드 입력을 잡고, 같은 화면 안에서 이미 쓰는 키면 거절한다(ESC = 취소).
- 조작 바인딩은 `core/scripts/key_binds.gd`(class_name 없음 — preload)가 소유한다. 행 하나 = `{액션, 슬롯, 라벨키}`이고 슬롯은 **그 액션에 달린 키 이벤트 중 몇 번째**인가다(한 액션이 두 좌석을 겸한다 — 예: `rotate_cw` = X(싱글) + `.`(2P)). 저장은 `GameState.keybinds`/`padbinds`(save.json), 기본값은 첫 `apply_all()` 때 InputMap 원본에서 읽어 캐시하므로 **프로젝트 기본 키는 `project.godot`의 입력 맵이 유일한 출처**다. 패드는 코드에서 기본값을 붙인다(`PAD_DEFAULTS`/`PAD_FIXED`). 진동 세기는 `GameState.vibration`(0~3), 실제 울림은 `GameState.rumble()`. 창 해상도는 `GameState.resolution` + `apply_resolution()`(데스크톱 전용)
- 골드 획득(전 모드, 분할·대전 제외 — 지갑 하나 원칙): ① 블록 속 금맥 `ore`(스폰 시 `ORE_CHANCE`로 한 칸에 박힘 — 줄 클리어·2회 타격 파괴·셔터·젤리 피크닉 구조 폭발 등 그 칸이 사라질 때 `_bank_ore()`로 지급) ② 낙하 블록 위에 얹힌 금덩이 `rider`(**회전하면 떨어져** 주울 수 있음, 안 떨어뜨리면 락/분리될 때 스택 위로 굴러떨어짐) ③ 피버 중 골드 비(엔드리스, `FEVER_RAIN_INTERVAL`). 떨어진 금덩이는 `nuggets`(중력 낙하 → 착지 → 고양이가 닿으면 획득, `NUGGET_LIFE` 후 소멸). 관련 상수는 `escape_board.gd`의 `ORE_*`/`RIDER_*`/`NUGGET_*`
- **키캡 수집 = 캐릭터 해금·등급업의 유일한 축** (캐릭터별 A~Z): 키캡은 냥이마다 따로 모은다 — 저장은 `GameState.keycaps = {cat id: {"A": 개수}}`(save.json, 구버전 평면 저장은 로드 때 첫 캐릭터 몫으로 이관). 한 냥이의 A~Z를 **한 바퀴 채울 때마다 등급 +1**(`cat_grade()`, 0=잠김 ~ `KEYCAP_GRADE_MAX`=4): 첫 바퀴가 해금, 이후 세 바퀴가 파츠 단계 1~3. **첫 캐릭터(`unlock.type == "free"` = 크림)만 첫 바퀴를 공짜로 갖고 시작**하고, 나머지 5종은 전부 `{"type": "keycap"}`이라 모아야 합류한다 — 골드/높이/플레이수 해금과 캐릭터 구매(try_buy)는 없어졌다. 주요 API: `cat_keycaps` / `keycap_count(cat, letter)` / `has_keycap` / `keycap_ring`(이번 바퀴 진행 0~26) / `keycaps_to_next` / `keycap_sets` / `cat_grade` / `cat_tier`(= 등급-1). **획득은 뽑기뿐** — 인게임 드랍 없음. `GameState.draw_keycaps(n, pick)`이 골드를 받고 뽑는다(`KEYCAP_GACHA_PRICE`/`_BULK`/`_BULK_PRICE`, `KEYCAP_FRESH_CHANCE`만큼 이번 바퀴 빈 글자 우선 = 나머지는 중복). 뽑기는 **두 종류**이고 단위는 **1개 / 10개**다: **랜덤 뽑기**(`pick` 비움 — 아직 만렙이 아닌 냥이 전체에서 균등 랜덤)와 **선택 뽑기**(`GameState.gacha_pick`에 담은 `KEYCAP_PICK_SIZE`=5마리만 나오고 값은 `KEYCAP_PICK_MARKUP`=1.5배). 뽑기 풀은 `gacha_pool(pick)`, 값은 `keycap_price(n, pick)`. 선택한 냥이는 save.json의 `gacha_pick`에 남는다. 전원 만렙까지 약 625장 ≈ 1.6만 골드. UI는 전부 `title.gd`: 타이틀 카드의 **`뽑기`(구 상점) = 캡슐 가챠 오버레이 하나뿐**(`_build_gacha`/`_open_gacha`/`_on_gacha`, `MENU_GACHA`). 연출은 장난감 캡슐 뽑기 기계 — 왼쪽에 돔·손잡이·배출구를 `_draw_machine()`이 그리고(돔 안 캡슐 색 = 이번 풀의 냥이 색), 뽑으면 아래 트레이(`_draw_gacha_tray()`)로 캡슐이 하나씩 굴러떨어져 뚜껑이 열리며 키캡이 나온다(타이밍 상수 `CAPSULE_STEP`/`_FALL`/`_HOLD`/`_OPEN`, 진행은 `_process()`의 `_pull_t`). 냥이 칩은 두 모드에서 다 보이고(랜덤에서는 풀 미리보기, 누르면 선택 뽑기로 전환) 스크롤된다 — 액세서리·부스터 판매 섹션은 제거했다. 액세서리·부스터를 **어디서도 살 수 없다** — 사망 팝업(`death_popup.gd`)의 부스터 칩도 뺐고 `open()`에서 `show_boosts` 인자가 사라졌다. `GameState.ACCESSORIES`/`BOOSTS`·`try_buy_acc`·`toggle_boost`·`take_boosts` 코드는 되살릴 수 있게 남겨 뒀다), 캐릭터 타일의 `▦ n/26` + 등급 칩(`_draw_grade_pips`), 캐릭터 팝업의 진행 바(`_draw_keycap_progress`) + `▦ 키캡` 버튼, 캐릭터 탭이 달린 키캡 도감 오버레이(`_open_keycap_dex(cat_id)`)
- 캐릭터 파츠 시스템: 모든 고양이는 "파츠 묶음"일 뿐이다. 디자인 캐릭터 **6종**(`char01`~`char06` — 컨셉 시트 `리소스/15.png`·레이어 시트 `리소스/CATTRIS_Char_Sheet.png`)의 기본 파츠와 해금 단계는 `core/scripts/custom_cat.gd`의 `CHARS`에 있고, CATS 항목의 `"char"` 키가 그 중 하나를 가리킨다(`GameState.cat_skin()`이 `CustomCat.build_skin(char, tier, sel)`로 조립). **해금 단계**: 그 캐릭터의 키캡 A~Z를 한 바퀴 완성할 때마다 1st → 2nd → 3rd 파츠가 붙는다(`GameState.cat_grade()` - 1 = `cat_tier()`, 3rd는 대체로 꼬리). 잠긴 냥이 실루엣은 `GameState.cat_shadow_skin()`
- 캐릭터별 커스터마이징: 저장은 캐릭터·자리마다 따로 — `GameState.cat_custom[custom_key(cat_id, player)] = {부위 key: 옵션 index}`(save.json, 2P는 `"<cat_id>|2"`). 커스텀 API·`cat_skin()`·`custom_sel()` 전부 마지막 인자가 `player`(기본 1). 자리별 선택 냥이는 `selected_cat`/`selected_cat2`(`cat_for(player)`), 인게임에서는 `Player.player_slot`이 그 자리를 가리킨다(분할 화면 왼쪽=1P). 액세서리는 지갑이 하나라 1P 몫으로만 붙는다. **사용자가 손댄 부위만** 담기고 나머지는 그 캐릭터의 디자인 파츠가 그대로 남는다(`CustomCat.apply_sel()`, 빈 sel = 완전 기본). **스프라이트로 그리는 냥이는 파츠 레이어에 색을 입히는 것만 가능**하다 — 가능한 부위는 `CustomCat.SPRITE_TINTS`(시트의 `recolor` 레이어 전부 — 몸/무늬·귀·꼬리/눈/발바닥/볼/수염/입/코 색), `sprite_safe()`가 참이면 `sprite_tints()`로 레이어에 틴트를 얹고, 모양까지 바꾸면 코드 렌더(`CatArt`)로 넘어간다. **꾸미기는 "나만의 캐릭터"(`mycat`) 슬롯 전용**이다 — 디자인 냥이 6종은 컨셉 시트 원본 그대로 쓰고 커스터마이징하지 않는다. 꾸미기 버튼(캐릭터 팝업·픽 슬롯 카드, `title.gd`)은 `GameState.is_custom_cat()`일 때만 뜨고, `cat_customizer.open()`도 그 외 캐릭터면 바로 되돌아간다. **부위 카탈로그는 컨셉 시트의 레이어 슬롯과 1:1이다** — 시트에 없는 슬롯은 만들지 않고, 시트에 그림이 없는 모양·색은 옵션으로 넣지 않는다(21개 부위, 시트 레이어 순서대로 나열: `back`(Prop_Back)·`tail`·`body`·`ear_shape`·`ear`·`pattern`·`pattern_col`(Cat_Body_Pattern)·`hold`(Cat_Prop_Belly)·`chest`(Cat_Prop_Chest)·`pad_col`·`cheek_col`·`whisker`·`whisker_col`·`mouth`·`mouth_col`·`nose_col`·`eyes`·`eye_col`·`mark`(Deco_Forehead)·`face`(Prop_Face)·`head`(Prop_Head). 희귀도 `r`·플레이버 `d`). 팔레트도 시트가 실제로 쓰는 색만 담는다 — **캐릭터를 추가할 때는 그 냐이의 레이어 색·파츠를 카탈로그에 한 줄씩 붙이는 것으로 커스터마이징 선택지가 함께 늘어난다**(목표 30마리). 카탈로그는 `custom_cat.gd`의 `PARTS`이고, 커스터마이저는 이를 **부위(`CustomCat.GROUPS`) 단위로 묶어** 보여 준다 — 그룹 하나가 칩 하나고(지금 냐이를 그 부위만 확대해 그린 클로즈업 아이콘, `GROUPS`의 `at`·`zoom`이 그 자리와 배율), 칩을 고르면 **그 부위의 모양과 색이 한 패널에 같이 나온다**(`_rebuild_panel()` → `_section()`, 모양 탭→색 탭으로 들어가는 단계가 없다). 프리뷰 냐이 위에는 선택한 부위 자리에 링 마커가 뜼다. 칩·옵션은 해당 캐릭터에 실제로 적용되는 부위만(`_build_tabs()`). "공장 초기화"는 그 캐릭터의 디자인 기본으로 되돌린다. 꾸미기 UI는 "냥이 크리에이터 3000"(`core/scripts/cat_customizer.gd`, `open(cat_id, player)` — 나만의 캐릭터 팝업/슬롯 카드의 🎨 꾸미기 버튼)
- **나만의 캐릭터(커스텀 슬롯)**: 캐릭터 선택 맨 끝에 `GameState.CATS`의 `mycat`(`"custom": true`, `"char": "custom"` = `CustomCat.BLANK_CHAR` 백지 몸통)이 하나 더 선다. 처음부터 열려 있고 **키캡을 모으지 않는다** — 가챠 풀·키캡 도감·등급 칩·도감 버튼에서 빠지고(`GameState.keycap_cats()`, `is_custom_cat()`), 타일·팝업에는 대신 파츠 해금 수(`my_parts_progress()` → `🎨 n / m`)가 뜬다. 꾸미기에 쓸 수 있는 파츠는 **해금한 디자인 냥이가 실제로 입고 있는 파츠뿐**이다: `CustomCat.my_sources()`가 `CHARS`(기본 파츠 + 해금 단계)를 훑어 옵션마다 출처 `{char, tier}`를 만들고(출처가 없는 "없음"은 상시 개방), `GameState.part_unlocked(key, idx)`가 `cat_grade(그 냥이) >= 1 + tier`로 판정한다(`part_unlock_hint()`는 잠금 안내 문구용). 커스터마이저는 이 슬롯일 때 `my_options()`에 있는 옵션만 늘어놓고, 잠긴 것은 회색 실루엣 + 자물쇠로 그리되, **눌러서 입혀 볼 수는 있다** — 잠긴 옵션을 누르면 `_preview_sel`에만 담겨 미리보기에 반영되고(타일은 시안 테두리 + 제 색, 무대에 "미리보기 중" 배너, 플레이버에 해금 조건) **`GameState`에는 저장되지 않는다** — 같은 옵션을 다시 누르거나 열린 옵션·초기화·무작위·프리셋을 고르면 걷힌다. 프리셋("원본 냥이") 탭도 잠긴 냥이는 못 불러오고, 열린 냥이도 그 냥이가 키운 단계까지만 가져온다. 즉 **냥이를 합류시키고 등급을 올리는 것이 곧 커스터마이징 재료 해금**이다. **그림도 그대로 빌려 쓴다** — 나만의 캐릭터는 코드 렌더가 아니라 디자인 냥이들의 **시트 파츠 png를 직접 겹쳐** 그린다: 스타일 옵션마다 `"src"`(어느 냥이의 그림인가)가 박혀 있고, `CustomCat.LAYER_SLOTS`가 부위 → 시트 레이어를 재고, `mix_of()`가 `{레이어: 캐릭터 id}`를·`mix_tints()`가 레이어 색을 만들어 `skin["mix"]`/`skin["tints"]`로 실으면 `CatSprite.paint_mix()`가 시트 레이어 번호 순서대로 배치표 좌표 그대로 겹친다(6종이 같은 278×293 캠버스라 자동 정렬된다). 부위로 갈라지지 않는 레이어(발·볼·코)는 몸 실루엣을 빌린 냥이를 따라간다. 사망·잠금 실루엣은 같은 레이어를 회청색 램프로 눌러 그린다(`CatSprite._ashen()`). 그릴 그림이 없는 조합이면 코드 렌더(`CatArt`)로 폴백한다. 테스트: `res://tests/test_mycat.tscn`
- 캐릭터/재화: 캐릭터 6종·해금 조건(첫 냥이 무료, 나머지는 캐릭터별 키캡 A~Z 한 바퀴)·**골드 단일 지갑**은 `GameState`(CATS 상수, save.json 저장), 선택 UI는 타이틀(`core/scripts/title.gd`), 보상 지급은 `main.gd._award_run_rewards()` — 스킨 색은 `paint_cat()`의 `skin` 파라미터로 전달
- **보석(◆)·부활은 제거됐다** (2026-08-29). 재화는 골드 하나뿐 — `GameState.gems`/`spend_gems`/`SKIP_COST`, `add_currency`의 두 번째 인자, 주간 랭킹 보석 보상, 스토리 보스 보석 보상이 전부 없어졌다(`add_currency(gold)`, `EventBus.story_reward(gold)`, `Ranks.weekly_reward(gold)`, `Ranks.WEEKLY_REWARDS = [500, 300, 200]`). 사망 팝업(`death_popup.gd`)은 이제 **다시하기 / 타이틀로** 둘뿐이고 `open(stats, new_record, earned, title_text)` 시그니처다 — 이어하기 버튼·가격 안내·스토리 스킵권이 사라졌고, 보드 쪽 `revive_player()`와 부활 전용 상수·`revive` 효과음·관련 테스트도 함께 지웠다(스택 폭발 `_blast_all_cells`는 피크닉 구조에서 계속 쓰므로 `BLAST_FX_*`로 이름만 바꿔 남겼다). 구 세이브의 `gems` 필드는 로드 때 무시된다. 설계 문서 `docs/economy.md`는 폐기된 보석 설계를 담고 있다
- 타이틀 흐름(인원 토글·캐릭터 세팅 → 모드 → 바로 시작) 회귀 테스트: `& "<godot>" --headless --path E:\Game\Block res://tests/test_flow.tscn` → 마지막 줄 `PASS`
- 씬 스크린샷 캡처: `& "<godot>" --path E:\Game\Block res://tests/visual_capture.tscn` → `.tmp_shots/`에 저장
- 캐릭터 스프라이트 점검(6종 × 4단계 + 잠금 실루엣 + 레이어 리컬러 + 코드 렌더 대조): `& "<godot>" --path E:\Game\Block res://tests/sprite_check.tscn` → `.tmp_shots/sprite_check.png`
- 새 `class_name` 추가 시 헤드리스 실행 전 `--import`로 전역 클래스 캐시 갱신 필요

## 컨벤션

- GDScript: 탭 들여쓰기, 타입 힌트 사용 (`var x: int`, `-> void`)
- 파일명: snake_case (`event_bus.gd`), 노드명: PascalCase
- 전역 이벤트는 EventBus 시그널로 통신, 전역 상태는 GameState에 보관
- 씬 간 직접 참조 대신 시그널 우선
