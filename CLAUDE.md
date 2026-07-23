# Block (게임 타이틀: Cat-Tris)

Godot 4.6 (2D) 게임 프로젝트. 구덩이에 빠진 큐브 고양이가 테트리스 블록을 밟고 위로 탈출하는 게임.

## 실행

- Godot 실행 파일: `C:/Users/SangWook Lee/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe`
- 에디터 열기: `& "<godot>" --editor --path E:\Game\Block`
- 게임 실행: `& "<godot>" --path E:\Game\Block`
- godot-mcp 서버가 `.mcp.json`에 설정되어 있음 (E:/GODOT/godot-mcp)

## 배포 (GitHub Pages)

- 라이브 URL: https://kiliuswook.github.io/Block/ (`gh-pages` 브랜치 루트를 서빙)
- 절차: ① `& "<godot>" --headless --path E:\Game\Block --export-release "Web" build/web/index.html` ② `build/web/*`을 `gh-pages` 브랜치에 복사(git worktree 사용) 후 커밋·푸시
- 커밋 전 `index.html`에 캐시 버스터 필수: `index.js` src와 GODOT_CONFIG의 `mainPack`(`index.pck?v=<타임스탬프>`)에 버전 쿼리를 붙일 것 — Pages가 10분 캐시(`max-age=600`)라 이걸 안 하면 배포 직후 브라우저에 이전 빌드가 보임

## 구조

- `scenes/` — 씬 파일 (.tscn). 메인 씬: `scenes/main.tscn`
- `scripts/` — 씬에 붙는 스크립트 (.gd)
- `autoload/` — 싱글톤 (EventBus, GameState)
- `assets/` — 이미지, 사운드, 폰트 등 리소스
- `docs/` — 기획/설계 문서
- `tests/` — 테스트. 실행: `& "<godot>" --headless --path E:\Game\Block res://tests/test_board.tscn` (탈출 모드: `res://tests/test_escape.tscn`)

## 게임 코어

- 시작 씬은 타이틀(`scenes/title.tscn`) — 모드 선택 후 `GameState.mode`(+`GameState.split`)에 저장하고 `scenes/main.tscn` 로드
- 모드: 탈출 모드(좌우 벽 상단의 출구로 나가면 레벨업) / 무한의 계단 모드(카메라가 플레이어를 위아래로 추적, 아래에서 용암이 상승 — 닿으면 사망, 높이 기록) / 2P 대전 모드(`Mode.VERSUS`: P1 고양이 vs P2 블록 직접 조종, 3선승)
- 화면 분할 2인(`GameState.split`): 탈출/무한을 SubViewport 2개로 나눠 경쟁(라운드제 3선승). 보드 씬은 `scenes/board.tscn`, 분할 빌드는 `main.gd._build_split()`. 좌석 배치 = 키보드 배치: P1(왼쪽 화면)이 WASD+Q/E+Ctrl(`p2_*` 액션), P2(오른쪽 화면)가 방향키+, .(또는 Z/X)+Shift(기본 액션). 보드/플레이어의 `act_*` 변수로 액션 이름 주입. 분할 중 보드는 EventBus 대신 로컬 `finished(win)` 시그널 사용
  - `scripts/escape_board.gd` — 필드/블록 로직 (블록이 캐릭터 열 추적 → 5초 후 자유낙하 → 락, 줄 클리어, 깔림 판정, 탈출 판정)
  - `scripts/player.gd` — 캐릭터 물리 (이동, 더블탭 대시, 점프+공중 제어, 빠른 낙하, AABB 충돌)
- 클래식 테트리스 로직은 `scripts/board.gd`에 유지 (SRS 회전+월킥, 7-bag 등) — escape_board가 SHAPES/KICKS/COLORS 상수를 재사용
- UI 배선/재시작/일시정지: `scripts/main.gd`
- 렌더링은 텍스처 없이 `_draw()`로 직접 그림
- 아트 규칙(Cat-Tris): 빛은 항상 위에서(블록 윗면만 하이라이트), 가장 따뜻한 것 = 플레이어(크림 #f4e3c8), 가장 밝은 것 = 출구의 빛(#fff3d0). 무한의 계단은 높이 오를수록 배경이 밝아짐. 큐브 고양이 렌더는 `Player.paint_cat()` 정적 함수 — 타이틀 등 어디서든 재사용
- 캐릭터/재화: 스킨 9종·해금 조건·골드/보석 지갑은 `GameState`(CATS 상수, save.json 저장), 선택 UI는 타이틀(`scripts/title.gd`), 보상 지급은 `main.gd._award_run_rewards()` — 스킨 색은 `paint_cat()`의 `skin` 파라미터로 전달
- 씬 스크린샷 캡처: `& "<godot>" --path E:\Game\Block res://tests/visual_capture.tscn` → `.tmp_shots/`에 저장
- 새 `class_name` 추가 시 헤드리스 실행 전 `--import`로 전역 클래스 캐시 갱신 필요

## 컨벤션

- GDScript: 탭 들여쓰기, 타입 힌트 사용 (`var x: int`, `-> void`)
- 파일명: snake_case (`event_bus.gd`), 노드명: PascalCase
- 전역 이벤트는 EventBus 시그널로 통신, 전역 상태는 GameState에 보관
- 씬 간 직접 참조 대신 시그널 우선
