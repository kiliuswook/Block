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
