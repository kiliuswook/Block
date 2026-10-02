extends Control
## 무한의 계단 피버타임 게이지. 평소에는 다음 피버까지 얼마나 찼는지를(오르기·
## 블록 부수기·발끝 세이브·줄 클리어로만 찬다) 보여 주고, 발동 중에는 같은 바가
## 남은 시간만큼 줄어든다. 계기판 카드 위의 다른 줄과 같은 톤 — 회색 소제목 +
## 둥근 트랙(피그마 슬라이더와 같은 모양).

const UiKit := preload("res://core/scripts/ui_kit.gd")

const BAR_H := 16.0
const CAPTION_H := 24.0
const TRACK := Color("ededed")

var gauge := 0.0  # 0..1 — 다음 러시까지
var time_left := 0.0  # 발동 중 남은 시간 (초, 0 = 꺼짐)
var full_time := 1.0  # 발동 지속 시간 — 바의 기준
var _pulse := 0.0


func _ready() -> void:
	EventBus.fever_changed.connect(_on_changed)
	set_process(false)


func _on_changed(g: float, left: float) -> void:
	if left > 0.0:
		if time_left <= 0.0:
			full_time = maxf(left, 0.01)
		time_left = left
		gauge = 1.0
		set_process(true)
	else:
		time_left = 0.0
		gauge = clampf(g, 0.0, 1.0)
		set_process(false)
		_pulse = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	var on := time_left > 0.0
	var label := tr("HUD_FEVER") if on else tr("HUD_FEVER_GAUGE")
	var col := UiKit.GOLD if on else UiKit.LABEL
	if on:
		col.a = 0.65 + 0.35 * sin(_pulse * 9.0)
	UiKit.text(self, label.to_upper(), Vector2(0.0, CAPTION_H - 8.0), 16, col, true)
	var track := Rect2(0.0, CAPTION_H + 2.0, size.x, BAR_H)
	UiKit.round_rect(self, track, TRACK, int(BAR_H / 2.0))
	var fill := clampf(time_left / full_time, 0.0, 1.0) if on else gauge
	if fill > 0.0:
		var r := Rect2(track.position, Vector2(maxf(BAR_H, track.size.x * fill), track.size.y))
		UiKit.round_rect(self, r, UiKit.GOLD if on else UiKit.ORANGE, int(BAR_H / 2.0))
