extends Node
## Global event bus. Declare signals here and connect from anywhere.
## Usage: EventBus.game_started.emit() / EventBus.game_started.connect(_on_game_started)

signal game_started
signal game_over
signal score_changed(new_score: int)
signal lines_changed(total_lines: int)
signal level_changed(new_level: int)
signal height_changed(new_height: int)
signal next_piece_changed(piece_type: String)
signal keycap_collected(cat_id: String, letter: String, count: int)  # 캐릭터별 키캡 적립
# Classic (arcade B-type): a level's board opens, its line goal ticks, and the
# shutter finishes paying out the empty-row bonus.
signal classic_level_started(level: int, quota: int, garbage: int)
signal classic_level_progress(cleared: int, quota: int)
signal classic_level_cleared(level: int, bonus: int)
# 무한의 계단 골드러시: 게이지가 찼거나(0..1) 발동이 돌고 있다(time_left > 0).
# 계기판 게이지가 이걸 읽는다 — 둘 중 하나만 의미가 있어서 한 시그널로 보낸다.
signal goldrush_changed(gauge: float, time_left: float)
# 골드 블록 한 칸이 터져 지갑에 들어갔다 (at = 보드 로컬 좌표) — HUD 연출용.
signal ore_collected(amount: int, at: Vector2)
