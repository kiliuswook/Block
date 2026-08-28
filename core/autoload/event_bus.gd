extends Node
## Global event bus. Declare signals here and connect from anywhere.
## Usage: EventBus.game_started.emit() / EventBus.game_started.connect(_on_game_started)

signal game_started
signal game_over
signal score_changed(new_score: int)
signal lines_changed(total_lines: int)
signal level_changed(new_level: int)
signal player_escaped(new_level: int)
signal height_changed(new_height: int)
signal next_piece_changed(piece_type: String)
signal versus_round_over(winner: int)  # 1 = cat (P1), 2 = blocks (P2)
signal story_stage_started(stage_num: int)
signal story_progress_changed(text: String)
signal story_doors_opened
signal story_completed
signal story_reward(gold: int, gems: int)  # first-clear payout for a story stage
signal keycap_collected(cat_id: String, letter: String, count: int)  # 캐릭터별 키캡 적립
# Classic (arcade B-type): a level's board opens, its line goal ticks, and the
# shutter finishes paying out the empty-row bonus.
signal classic_level_started(level: int, quota: int, garbage: int)
signal classic_level_progress(cleared: int, quota: int)
signal classic_level_cleared(level: int, bonus: int)
