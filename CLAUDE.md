# Block

Godot 4.6 (2D) 게임 프로젝트.

## 실행

- Godot 실행 파일: `C:/Users/SangWook Lee/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe`
- 에디터 열기: `& "<godot>" --editor --path E:\Game\Block`
- 게임 실행: `& "<godot>" --path E:\Game\Block`
- godot-mcp 서버가 `.mcp.json`에 설정되어 있음 (E:/GODOT/godot-mcp)

## 구조

- `scenes/` — 씬 파일 (.tscn). 메인 씬: `scenes/main.tscn`
- `scripts/` — 씬에 붙는 스크립트 (.gd)
- `autoload/` — 싱글톤 (EventBus, GameState)
- `assets/` — 이미지, 사운드, 폰트 등 리소스
- `docs/` — 기획/설계 문서
- `tests/` — 테스트. 실행: `& "<godot>" --headless --path E:\Game\Block res://tests/test_board.tscn` (탈출 모드: `res://tests/test_escape.tscn`)

## 게임 코어

- 시작 씬은 타이틀(`scenes/title.tscn`) — 모드 선택 후 `GameState.mode`에 저장하고 `scenes/main.tscn` 로드
- 모드 2개: 탈출 모드(상단 탈출구로 나가면 레벨업) / 무한의 계단 모드(상승 전용 카메라, 화면 아래 추락 시 사망, 높이 기록)
  - `scripts/escape_board.gd` — 필드/블록 로직 (블록이 캐릭터 열 추적 → 5초 후 자유낙하 → 락, 줄 클리어, 깔림 판정, 탈출 판정)
  - `scripts/player.gd` — 캐릭터 물리 (이동, 더블탭 대시, 점프+공중 제어, 빠른 낙하, AABB 충돌)
- 클래식 테트리스 로직은 `scripts/board.gd`에 유지 (SRS 회전+월킥, 7-bag 등) — escape_board가 SHAPES/KICKS/COLORS 상수를 재사용
- UI 배선/재시작/일시정지: `scripts/main.gd`
- 렌더링은 텍스처 없이 `_draw()`로 직접 그림
- 새 `class_name` 추가 시 헤드리스 실행 전 `--import`로 전역 클래스 캐시 갱신 필요

## 컨벤션

- GDScript: 탭 들여쓰기, 타입 힌트 사용 (`var x: int`, `-> void`)
- 파일명: snake_case (`event_bus.gd`), 노드명: PascalCase
- 전역 이벤트는 EventBus 시그널로 통신, 전역 상태는 GameState에 보관
- 씬 간 직접 참조 대신 시그널 우선
